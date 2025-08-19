const std = @import("std");
const HtmlTrimmer = @import("html_trimmer.zig").HtmlTrimmer;

const version = "0.1.0";

const Args = struct {
    input_file: ?[]const u8 = null,
    output_file: ?[]const u8 = null,
    stdin: bool = false,
    stdout: bool = false,
    help: bool = false,
    version: bool = false,
    verbose: bool = false,
};

const TrimContext = struct {
    allocator: std.mem.Allocator,
    stdout: std.fs.File.Writer,
    stderr: std.fs.File.Writer,

    pub fn log(self: TrimContext, comptime fmt: []const u8, args: anytype) !void {
        try self.stderr.print("[trim_html] " ++ fmt, args);
    }

    pub fn info(self: TrimContext, comptime fmt: []const u8, args: anytype) !void {
        try self.stdout.print(fmt, args);
    }

    pub fn err(self: TrimContext, comptime fmt: []const u8, args: anytype) !void {
        try self.stderr.print(fmt, args);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    const ctx = TrimContext{
        .allocator = gpa.allocator(),
        .stdout = std.io.getStdOut().writer(),
        .stderr = std.io.getStdErr().writer(),
    };

    const args = try parseArgs(ctx);
    defer if (args.input_file) |f| ctx.allocator.free(f);
    defer if (args.output_file) |f| ctx.allocator.free(f);

    if (args.help) {
        printHelp(ctx);
        return;
    }

    if (args.version) {
        // try std.io.getStdOut().writer.print("trim_html version {s}\n", .{version});
        try ctx.info("trim_html version {s}\n", .{version});
        return;
    }

    // Determine input source
    var input_content: []u8 = undefined;
    // defer allocator.free(input_content);
    defer ctx.allocator.free(input_content);

    if (args.stdin or args.input_file == null) {
        // Read from stdin
        const stdin = std.io.getStdIn();
        input_content = try stdin.reader().readAllAlloc(ctx.allocator, 10 * 1024 * 1024); // 10MB max
        if (args.verbose) {
            // try std.io.getStdErr().writer().print("Read {} bytes from stdin", .{input_content.len});
            try ctx.err("Read {} bytes from stdin", .{input_content.len});
        }
    } else if (args.input_file) |input_file_path| {
        // Read from file
        const file = try std.fs.cwd().openFile(input_file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        // input_content = try allocator.alloc(u8, file_size);
        input_content = try ctx.allocator.alloc(u8, file_size);
        _ = try file.read(input_content);

        if (args.verbose) {
            // try std.io.getStdErr().writer().print("Read {} bytes from {s}\n", .{ input_content.len, input_file_path});
            try ctx.err("Read {} bytes from {s}\n", .{ input_content.len, input_file_path });
        }
    }

    // Process the HTML
    const trimmer = HtmlTrimmer.init(ctx.allocator);
    const trimmed = try trimmer.trim(input_content);
    // defer allocator.free(trimmed);
    defer ctx.allocator.free(trimmed);

    if (args.verbose) {
        const saved_chars = input_content.len - trimmed.len;
        const percentage = if (input_content.len > 0)
            @as(f64, @floatFromInt(saved_chars)) * 100.0 / @as(f64, @floatFromInt(input_content.len))
        else
            0.0;

        // try std.io.getStdErr().writer.print(
        //     "Trimmed {} bytes to {} bytes (saved {} bytes, {d:.1}%)\n",
        //     .{input_content.len, trimmed.len, saved_chars, percentage}
        // );
        try ctx.err("Trimmed {} bytes to {} bytes (saved {} bytes, {d:.1}%)\n", .{ input_content.len, trimmed.len, saved_chars, percentage });
    }

    // Ouptut the result
    if (args.stdout or args.output_file == null) {
        // Write to stdout
        // try std.io.getStdOut().writeAll(trimmed);
        try ctx.stdout.writeAll(trimmed);
    } else if (args.output_file) |output_file_path| {
        // Write to file
        const file = try std.fs.cwd().createFile(output_file_path, .{});
        defer file.close();

        try file.writeAll(trimmed);

        if (args.verbose) {
            // try std.io.getStdErr().writer().print("Wrote {} bytes to {s}\n", .{ trimmed.len, output_file_path});
            try ctx.err("Wrote {} bytes to {s}\n", .{ trimmed.len, output_file_path });
        }
    }
}

fn parseArgs(ctx: TrimContext) !Args {
    var args = Args{};
    var arg_iter = try std.process.argsWithAllocator(ctx.allocator);
    defer arg_iter.deinit();

    // Skip program name
    _ = arg_iter.skip();

    while (arg_iter.next()) |arg| {
        if (isFlag(arg, "-h", "--help")) {
            args.help = true;
        } else if (isFlag(arg, "-v", "--version")) {
            args.version = true;
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            args.verbose = true;
        } else if (std.mem.eql(u8, arg, "--stdin")) {
            args.stdin = true;
        } else if (std.mem.eql(u8, arg, "--stdout")) {
            args.stdout = true;
        }
        // Handle options with values
        else if (isFlag(arg, "-i", "--input")) {
            args.input_file = try getRequiredValue(ctx, &arg_iter, arg);
        } else if (isFlag(arg, "-o", "--output")) {
            args.output_file = try getRequiredValue(ctx, &arg_iter, arg);
        } else {
            try ctx.err("Error: unknown option '{s}'\n", .{arg});
            std.process.exit(1);
        }
    }

    return args;
}

fn isFlag(arg: []const u8, short_form_flag: []const u8, long_form_flag: []const u8) bool {
    return std.mem.eql(u8, arg, short_form_flag) or std.mem.eql(u8, arg, long_form_flag);
}

fn getRequiredValue(ctx: TrimContext, arg_iter: *std.process.ArgIterator, flag: []const u8) ![]u8 {
    if (arg_iter.next()) |value| {
        return try ctx.allocator.dupe(u8, value);
    } else {
        // try std.io.getStdErr().writer().print("Error: {s} requires a value\n", .{flag});
        try ctx.err("Error: {s} requires a value\n", .{flag});
        std.process.exit(1);
    }
}

fn printHelp(ctx: TrimContext) void {
    const help_text =
        \\trim_html - Remove unnecessary spaces from HTML content
        \\
        \\Usage: trim_html [OPTIONS] [INPUT_FILE]
        \\
        \\Options:
        \\  -h, --help        Show this help message
        \\  -v, --version     Show version information
        \\  -i, --input FILE  Input HTML file (default: stdin)
        \\  -o, --output FILE Output file (default: stdout)
        \\  --stdin           Force reading from stdin
        \\  --stdout          Force writing to stdout
        \\  --verbose         Show processing statistics
        \\
        \\Examples:
        \\  # Process a file
        \\  trim_html input.html -o output.html
        \\
        \\  # Use pipes
        \\  cat listing.html | trim_html > trimmed.html
        \\
        \\  # Show statistics
        \\  trim_html --verbose input.html -o output.html
        \\
        \\Description:
        \\  This tool removes unnecessary whitespace from HTML content while
        \\  preserving spaces within meaningful text. It's particularly useful
        \\  for platforms like Amazon that have character limits for HTML
        \\  listings.
        \\
        \\  The tool will:
        \\  - Remove spaces between HTML tags
        \\  - Remove spaces between tags and content
        \\  - Preserve single spaces within text content
        \\  - Preserve content in <script> and <style> tags
        \\  - Handle HTML comments correctly
        \\
    ;

    // std.io.getStdOut().writer().print("{s}", .{help_text}) catch {};
    ctx.info("{s}", .{help_text}) catch {};
}
