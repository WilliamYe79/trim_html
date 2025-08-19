# trim_html

A fast and efficient HTML whitespace trimmer written in Zig. This tool removes unnecessary spaces between HTML tags while preserving spaces within meaningful text content. Perfect for optimizing HTML listings for platforms with character limits like Amazon.

## Features

- **Smart Space Removal**: Removes all unnecessary whitespace between HTML tags
- **Content Preservation**: Maintains single spaces within text content
- **Special Tag Handling**: Preserves formatting in `<script>` and `<style>` tags
- **Comment Support**: Correctly handles HTML comments
- **Fast Performance**: Written in Zig for optimal speed and memory efficiency
- **Flexible I/O**: Supports file input/output and stdin/stdout piping

## Installation

### Prerequisites

- Zig 0.11.0 or later

### Building from Source

```bash
git clone https://github.com/yourusername/trim_html.git
cd trim_html
zig build -Doptimize=ReleaseFast
```

The compiled binary will be available in `zig-out/bin/trim_html`.

## Usage

### Basic Usage

```bash
# Process a file
trim_html input.html -o output.html

# Use with pipes
cat listing.html | trim_html > trimmed.html

# Show processing statistics
trim_html --verbose input.html -o output.html
```

### Command Line Options

```
Options:
  -h, --help        Show help message
  -v, --version     Show version information
  -i, --input FILE  Input HTML file (default: stdin)
  -o, --output FILE Output file (default: stdout)
  --stdin           Force reading from stdin
  --stdout          Force writing to stdout
  --verbose         Show processing statistics
```

## Examples

### Amazon Listing Optimization

Original HTML (312 characters):
```html
  <h2>  Product Features  </h2>
  <ul>
    <li>  High quality material  </li>
    <li>  Durable design  </li>
  </ul>
  <p>  Perfect for everyday use.  </p>
```

After trimming (167 characters):
```html
<h2>Product Features</h2><ul><li>High quality material</li><li>Durable design</li></ul><p>Perfect for everyday use.</p>
```

**Saved: 145 characters (46.5% reduction)**

### Complex HTML with Mixed Content

Input:
```html
<div class="container">
  <h1>  Welcome to Our Store  </h1>
  <p>  We offer   great   products   at   affordable   prices.  </p>
  <div>
    <span>  Contact us:  </span>
    <a href="mailto:info@example.com">  info@example.com  </a>
  </div>
</div>
```

Output:
```html
<div class="container"><h1>Welcome to Our Store</h1><p>We offer great products at affordable prices.</p><div><span>Contact us:</span><a href="mailto:info@example.com">info@example.com</a></div></div>
```

## How It Works

The trimmer operates using a state machine that tracks whether it's currently:
- Inside text content
- Inside an HTML tag
- Inside a comment
- Inside a script or style block

Rules applied:
1. **Between tags**: All whitespace is removed
2. **Between tag and text**: All whitespace is removed
3. **Within text content**: Multiple spaces are collapsed to single spaces
4. **Special blocks**: Content in `<script>` and `<style>` tags is preserved as-is

## Project Structure

```
trim_html/
├── build.zig           # Build configuration
├── build.zig.zon       # Build dependencies
├── CLAUDE.md           # Project instructions for Claude Code
├── src/
│   ├── main.zig        # CLI application
│   └── html_trimmer.zig # Core trimming logic
├── examples/
│   └── sample.html     # Example HTML files
└── README.md          # This file
```

## Testing

Run the test suite:
```bash
zig build test
```

## Performance

The tool is designed for high performance:
- Single-pass processing
- Minimal memory allocations
- Efficient string handling
- Supports large files (up to 10MB by default)

## Use Cases

- **E-commerce Platforms**: Optimize product listings for Amazon, eBay, etc.
- **Email Templates**: Reduce HTML email size
- **Web Optimization**: Minimize HTML before compression
- **Content Management**: Clean up HTML from WYSIWYG editors
- **API Responses**: Reduce bandwidth for HTML API responses

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See LICENSE file for details

## Author

Created for efficient HTML optimization, particularly for e-commerce platforms with character restrictions.