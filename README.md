# che-pdf-mcp

A Swift-native MCP (Model Context Protocol) server for PDF document manipulation. Uses macOS native frameworks (PDFKit, Vision, CoreGraphics) for high-performance PDF processing without external dependencies.

[中文說明](README_zh-TW.md)

## Features

- **Pure Swift Implementation**: No Python, Node.js, or external runtime required
- **macOS Native APIs**: PDFKit for core operations, Vision for OCR
- **Single Binary**: Just one executable file
- **25 MCP Tools**: Complete PDF manipulation toolkit
- **High Performance**: Native binary with no interpreter overhead

## Installation

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Swift 5.9+

### Build from Source

```bash
git clone https://github.com/kiki830621/che-pdf-mcp.git
cd che-pdf-mcp
swift build -c release
```

The binary will be located at `.build/release/ChePDFMCP`

### Add to Claude Code

```bash
claude mcp add che-pdf-mcp /path/to/che-pdf-mcp/.build/release/ChePDFMCP
```

### Add to Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "che-pdf-mcp": {
      "command": "/path/to/che-pdf-mcp/.build/release/ChePDFMCP"
    }
  }
}
```

## Usage with AI Agents

### Just ask the agent

The simplest approach - just tell your agent to use it:

```
Use che-pdf-mcp to extract text from ~/Documents/report.pdf
```

### AGENTS.md / CLAUDE.md

For more consistent results, add to your project or global instructions file:

```markdown
## PDF Document Manipulation

Use `che-pdf-mcp` for reading and processing PDF files.

Core workflow:
1. `pdf_info` - Get PDF metadata and page count
2. `pdf_extract_text` - Extract text content
3. `pdf_search_text` - Search for text in PDF
4. `pdf_merge` - Combine multiple PDFs
5. `pdf_extract_pages` - Extract specific pages
6. `pdf_ocr_text` - OCR scanned documents
7. `pdf_to_markdown` - Convert to Markdown
```

### Claude Code Skill

```bash
mkdir -p .claude/skills/che-pdf-mcp
curl -o .claude/skills/che-pdf-mcp/SKILL.md \
  https://raw.githubusercontent.com/kiki830621/che-pdf-mcp/main/skills/che-pdf-mcp/SKILL.md
```

## Available Tools (25 Tools)

### Document Access (6 tools)

| Tool | Description |
|------|-------------|
| `pdf_info` | Get PDF information (page count, version, encryption, metadata) |
| `pdf_list` | List PDF files in a directory |
| `pdf_open` | Open PDF and return document ID |
| `pdf_close` | Close an open document |
| `pdf_list_open` | List all open documents |
| `pdf_page_count` | Get page count |

### Text Extraction & Search (3 tools)

| Tool | Description |
|------|-------------|
| `pdf_extract_text` | Extract plain text (with optional page range) |
| `pdf_search_text` | Search for text in PDF |
| `pdf_extract_text_with_layout` | Extract text with position info |

### Document Operations (3 tools)

| Tool | Description |
|------|-------------|
| `pdf_merge` | Merge multiple PDFs |
| `pdf_extract_pages` | Extract specific pages |
| `pdf_save` | Save changes to PDF |

### OCR (2 tools)

| Tool | Description |
|------|-------------|
| `pdf_ocr_text` | Extract text from scanned PDFs using Vision OCR |
| `pdf_ocr_page` | OCR single page with position information |

### Structured Output (2 tools)

| Tool | Description |
|------|-------------|
| `pdf_to_markdown` | Convert PDF to Markdown format |
| `pdf_get_outline` | Get PDF outline/table of contents |

### Image Processing (2 tools)

| Tool | Description |
|------|-------------|
| `pdf_extract_images` | Extract embedded images from PDF |
| `pdf_render_page` | Render PDF page to image file |

### Detection (2 tools)

| Tool | Description |
|------|-------------|
| `pdf_detect_type` | Detect PDF type (text/scanned/mixed) |
| `pdf_check_accessibility` | Check PDF accessibility features |

### Advanced Operations (5 tools)

| Tool | Description |
|------|-------------|
| `pdf_rotate_pages` | Rotate pages |
| `pdf_split` | Split PDF into multiple files |
| `pdf_add_watermark` | Add text watermark |
| `pdf_encrypt` | Encrypt PDF with password |
| `pdf_url_fetch` | Fetch PDF from URL |

## Usage Examples

### Get PDF Information

```
Get info about ~/Documents/report.pdf
```

### Extract Text

```
Extract text from pages 1-5 of ~/Documents/thesis.pdf
```

### Merge PDFs

```
Merge ~/Documents/part1.pdf and ~/Documents/part2.pdf into ~/Documents/combined.pdf
```

### Search in PDF

```
Search for "machine learning" in ~/Documents/paper.pdf
```

### Extract Pages

```
Extract pages 1,3,5-10 from ~/Documents/document.pdf to ~/Documents/selected.pdf
```

### OCR Scanned Document

```
Use pdf_ocr_text on ~/Documents/scanned.pdf with languages ["en-US", "zh-Hant"]
```

### Convert to Markdown

```
Convert ~/Documents/paper.pdf to Markdown format
```

### Detect PDF Type

```
Detect whether ~/Documents/document.pdf is text-based or scanned
```

### Rotate Pages

```
Rotate pages 1-3 of ~/Documents/document.pdf by 90 degrees
```

### Split PDF

```
Split ~/Documents/book.pdf into one file per page
```

### Add Watermark

```
Add "CONFIDENTIAL" watermark to ~/Documents/report.pdf
```

### Encrypt PDF

```
Encrypt ~/Documents/sensitive.pdf with password "secret123"
```

## Technical Details

### macOS Frameworks Used

- **PDFKit**: Core PDF operations (read, write, merge, search)
- **Vision**: OCR for scanned documents
- **CoreGraphics**: Low-level PDF access, image rendering
- **AppKit**: Image format conversion

### Dependencies

- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) (v0.10.0+)

## Comparison with Other Solutions

| Feature | mcp-pdf-tools | MCP_PDF_Server | **che-pdf-mcp** |
|---------|---------------|----------------|-----------------|
| Language | Rust | Python | **Swift** |
| Runtime | None | Python | **None** |
| OCR | No | No | **Yes (Vision)** |
| Merge | Yes | No | **Yes** |
| Extract Pages | Yes | No | **Yes** |
| Markdown Export | No | No | **Yes** |
| Watermark | No | No | **Yes** |
| Encryption | No | No | **Yes** |
| URL Fetch | No | No | **Yes** |
| macOS Native | No | No | **Yes** |

## License

MIT License

## Author

Che Cheng ([@kiki830621](https://github.com/kiki830621))

## Related Projects

- [che-word-mcp](https://github.com/kiki830621/che-word-mcp) - Word document MCP server
- [che-apple-mail-mcp](https://github.com/kiki830621/che-apple-mail-mcp) - Apple Mail MCP server
