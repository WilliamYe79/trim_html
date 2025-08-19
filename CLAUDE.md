# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build and Development
- `zig build` - Build the executable (outputs to `zig-out/bin/trim_html`)
- `zig build -Doptimize=ReleaseFast` - Build optimized release version
- `zig build run` - Build and run the application
- `zig build run -- [args]` - Build and run with arguments
- `zig build test` - Run all unit tests
- `zig build example` - Run example trimming on `examples/sample.html` (outputs to `examples/sample_trimmed.html`)

### Usage Examples
- `./zig-out/bin/trim_html input.html -o output.html` - Process file
- `cat input.html | trim_html > output.html` - Use with pipes
- `trim_html --verbose input.html -o output.html` - Show statistics

## Architecture

This is a Zig-based HTML whitespace trimmer designed for optimizing HTML content (particularly for e-commerce platforms like Amazon with character limits).

### Core Components

- **`src/main.zig`** - CLI interface with argument parsing, file I/O, and error handling
- **`src/html_trimmer.zig`** - Core trimming logic with state machine parser

### HTML Trimming Algorithm

The trimmer uses a finite state machine with these states:
- `text` - Processing text content between tags
- `tag` - Inside HTML tags
- `comment` - Inside HTML comments (`<!-- -->`)
- `script` - Inside `<script>` tags (content preserved)
- `style` - Inside `<style>` tags (content preserved)

#### Processing Rules
1. **Between tags**: All whitespace removed
2. **Between tag and text**: All whitespace removed  
3. **Within text content**: Multiple spaces collapsed to single spaces
4. **Special blocks**: `<script>` and `<style>` content preserved as-is
5. **Comments**: HTML comments preserved with original formatting

### Module Structure

The project uses Zig's module system:
- `html_trimmer` module is imported into the main executable
- `build.zig` configures both executable and library builds
- Tests are embedded in source files using `test` blocks

### Memory Management

Uses Zig's `GeneralPurposeAllocator` with proper cleanup:
- Input content allocated based on file size or stdin
- Output allocated using `ArrayList` and converted to owned slice
- All allocations properly freed with `defer` statements