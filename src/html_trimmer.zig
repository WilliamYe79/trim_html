const std = @import("std");
const testing = std.testing;

pub const HtmlTrimmer = struct {
    allocator: std.mem.Allocator,

    const State = enum {
        text,
        tag,
        tag_closing,
        comment,
        script,
        style,
    };

    pub fn init(allocator: std.mem.Allocator) HtmlTrimmer {
        return .{ .allocator = allocator };
    }

    /// Trims unnecessary whitespaces from HTML content
    /// Remove spaces between tags and between tags and content
    /// Preserve spaces within meaningful text content
    pub fn trim(self: HtmlTrimmer, html: []const u8) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        defer result.deinit();

        var state = State.text;
        var i: usize = 0;
        var last_was_space = false;
        var text_content_started = false;
        var pending_spaces = std.ArrayList(u8).init(self.allocator);
        defer pending_spaces.deinit();

        while (i < html.len) {
            const c = html[i];
            switch (state) {
                .text => {
                    if (c == '<') {
                        // Check for comment
                        if (i + 3 < html.len and html[i + 1] == '!' and html[i + 2] == '-' and html[i + 3] == '-') {
                            state = .comment;
                            try result.append(c);
                            text_content_started = false;
                            pending_spaces.clearRetainingCapacity();
                        }
                        // Check for script tag
                        else if (self.isTagStart(html, i, "script")) {
                            state = .script;
                            try result.append(c);
                            text_content_started = false;
                            pending_spaces.clearRetainingCapacity();
                        }
                        // Check for style tag
                        else if (self.isTagStart(html, i, "style")) {
                            state = .style;
                            try result.append(c);
                            text_content_started = false;
                            pending_spaces.clearRetainingCapacity();
                        }
                        // Regular tag
                        else {
                            state = .tag;
                            // Don't add pending spaces before a tag
                            pending_spaces.clearRetainingCapacity();
                            try result.append(c);
                            text_content_started = false;
                        }
                        last_was_space = false;
                    } else if (self.isWhitespace(c)) {
                        if (text_content_started) {
                            // In the middle of text content, collect spaces
                            try pending_spaces.append(c);
                        }
                        // Otherwise, ignore spaces at the beginning
                        last_was_space = true;
                    } else {
                        // Non-space character in text
                        if (!text_content_started) {
                            text_content_started = true;
                        }
                        // Add any pending spaces before this character
                        if (pending_spaces.items.len > 0) {
                            // Normalize multiple spaces to a single space
                            try result.append(' ');
                            pending_spaces.clearRetainingCapacity();
                        }
                        try result.append(c);
                        last_was_space = false;
                    }
                },

                .tag => {
                    // Skip spaces immediately after < or before >
                    if (self.isWhitespace(c)) {
                        // Check if we're right after '<' or right before '>'
                        const last_char = if (result.items.len > 0) result.items[result.items.len - 1] else 0;
                        if (last_char == '<') {
                            // Skip space after '<'
                            continue;
                        }
                        // Look ahead for '>'
                        var j = i + 1;
                        while (j < html.len and self.isWhitespace(html[j])) : (j += 1) {}
                        if (j < html.len and html[j] == '>') {
                            // Skip spaces before >
                            continue;
                        }
                    }
                    try result.append(c);
                    if (c == '>') {
                        state = .text;
                        text_content_started = false;
                    }
                },

                .comment => {
                    try result.append(c);
                    // Check for end of comment
                    if (c == '>' and i > 2 and html[i - 1] == '-' and html[i - 2] == '-') {
                        state = .text;
                        text_content_started = false;
                    }
                },

                .script => {
                    try result.append(c);
                    // Check for </script>
                    if (c == '>' and self.isClosingTag(html, i, "script")) {
                        state = .text;
                        text_content_started = false;
                    }
                },

                .style => {
                    try result.append(c);
                    // Check for </style>
                    if (c == '>' and self.isClosingTag(html, i, "style")) {
                        state = .text;
                        text_content_started = false;
                    }
                },

                else => {},
            }
            i += 1;
        }

        return result.toOwnedSlice();
    }

    fn isWhitespace(self: HtmlTrimmer, c: u8) bool {
        _ = self;
        return switch (c) {
            ' ', '\t', '\n', '\r', '\x0B', '\x0C' => true,
            else => false,
        };
    }

    fn isTagStart(self: HtmlTrimmer, html: []const u8, pos: usize, tag: []const u8) bool {
        _ = self;
        if (pos + tag.len + 1 >= html.len) return false;
        if (html[pos] != '<') return false;

        // Check if it matches the tag name (case insensitive)
        var i: usize = 0;
        while (i < tag.len) : (i += 1) {
            const html_char = std.ascii.toLower(html[pos + 1 + i]);
            const tag_char = std.ascii.toLower(tag[i]);
            if (html_char != tag_char) return false;
        }

        // Check if next character is '>' or space
        const next_pos = pos + 1 + tag.len;
        if (next_pos < html.len) {
            const next_char = html[next_pos];
            return next_char == '>' or next_char == ' ' or next_char == '\t' or next_char == '\n' or next_char == '\r';
        }

        return false;
    }

    fn isClosingTag(self: HtmlTrimmer, html: []const u8, pos: usize, tag: []const u8) bool {
        if (pos < tag.len + 3) return false; // Need at least </tag>

        // Work backwards from '>' to find '</tag'
        var i = pos - 1;
        
        // Skip whitespace before '>'
        while (i > 0 and self.isWhitespace(html[i])) : (i -= 1) {}
        const tag_end = i + 1;

        // Skip back to find tag name
        while (i > 0 and html[i] != '/') : (i -= 1) {}
        if (i == 0 or html[i - 1] != '<') return false;

        // Check tag name
        const tag_start = i + 1;
        const tag_found = html[tag_start..tag_end];

        if (tag_found.len != tag.len) return false;

        // Case insensitive comparison
        var j: usize = 0;
        while (j < tag.len) : (j += 1) {
            if (std.ascii.toLower(tag_found[j]) != std.ascii.toLower(tag[j])) {
                return false;
            }
        }

        return true;
    }
};

// Testing
test "basic HTML trimming" {
    const allocator = testing.allocator;
    const trimmer = HtmlTrimmer.init(allocator);

    const input = "  <div>  Hello   World  </div>  ";
    const expected = "<div>Hello World</div>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "preserve spaces in text content" {
    const allocator = testing.allocator;
    const trimmer = HtmlTrimmer.init(allocator);

    const input = "<p>This is   a   test   with spaces</p>";
    const expected = "<p>This is a test with spaces</p>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "nested tags with spaces" {
    const allocator = testing.allocator;
    var trimmer = HtmlTrimmer.init(allocator);

    const input = "  <div>  \n  <p>  Text  </p>  \n  </div>  ";
    const expected = "<div><p>Text</p></div>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "mixed content" {
    const allocator = testing.allocator;
    var trimmer = HtmlTrimmer.init(allocator);

    const input = "<ul>\n  <li>Item 1</li>\n  <li>Item 2</li>\n</ul>";
    const expected = "<ul><li>Item 1</li><li>Item 2</li></ul>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "preserve script and style content" {
    const allocator = testing.allocator;
    const trimmer = HtmlTrimmer.init(allocator);

    const input = "<script>  var x = 1;  </script>";
    const expected = "<script>  var x = 1;  </script>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "HTML comments" {
    const allocator = testing.allocator;
    var trimmer = HtmlTrimmer.init(allocator);

    const input = "  <!-- Comment -->  <div>Text</div>  ";
    const expected = "<!-- Comment --><div>Text</div>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}

test "Amazon listing example" {
    const allocator = testing.allocator;
    const trimmer = HtmlTrimmer.init(allocator);

    const input =
        \\  <h2>  Product Features  </h2>
        \\  <ul>
        \\    <li>  High quality material  </li>
        \\    <li>  Durable design  </li>
        \\  </ul>
        \\  <p>  Perfect for everyday use.  </p>
    ;

    const expected = "<h2>Product Features</h2><ul><li>High quality material</li><li>Durable design</li></ul><p>Perfect for everyday use.</p>";

    const result = try trimmer.trim(input);
    defer allocator.free(result);

    try testing.expectEqualStrings(expected, result);
}
