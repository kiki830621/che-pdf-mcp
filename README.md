# che-pdf-mcp

A Swift-native MCP (Model Context Protocol) server for PDF document manipulation. Uses macOS native frameworks (PDFKit, Vision, CoreGraphics) for high-performance PDF processing without external dependencies.

[中文說明](README_zh-TW.md)

## Features

- **Pure Swift Implementation**: No Python, Node.js, or external runtime required
- **macOS Native APIs**: PDFKit for core operations, Vision for OCR
- **Single Binary**: Just one executable file
- **12 MCP Tools** (MVP): Document info, text extraction, search, merge, extract pages
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
```

### Claude Code Skill

```bash
mkdir -p .claude/skills/che-pdf-mcp
curl -o .claude/skills/che-pdf-mcp/SKILL.md \
  https://raw.githubusercontent.com/kiki830621/che-pdf-mcp/main/skills/che-pdf-mcp/SKILL.md
```

## Available Tools (12 MVP Tools)

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

## Technical Details

### macOS Frameworks Used

- **PDFKit**: Core PDF operations (read, write, merge, search)
- **Vision**: OCR for scanned documents (Milestone B)
- **CoreGraphics**: Low-level PDF access, image extraction

### Dependencies

- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) (v0.10.0+)

## Comparison with Other Solutions

| Feature | mcp-pdf-tools | MCP_PDF_Server | **che-pdf-mcp** |
|---------|---------------|----------------|-----------------|
| Language | Rust | Python | **Swift** |
| Runtime | None | Python | **None** |
| OCR | No | No | **Planned** |
| Merge | Yes | No | **Yes** |
| Extract Pages | Yes | No | **Yes** |
| macOS Native | No | No | **Yes** |

## Roadmap

### Milestone A (MVP) - Current

- [x] Document access and info
- [x] Text extraction
- [x] Search
- [x] Merge
- [x] Extract pages

### Milestone B (RAG/Document Understanding)

- [ ] OCR with Vision framework
- [ ] PDF to Markdown conversion
- [ ] Outline/TOC extraction
- [ ] Image extraction
- [ ] PDF type detection (text/scanned/mixed)

### Milestone C (Advanced)

- [ ] Page rotation
- [ ] PDF split
- [ ] Watermark
- [ ] Encryption
- [ ] URL fetch

## License

MIT License

## Author

Che Cheng ([@kiki830621](https://github.com/kiki830621))

## Related Projects

- [che-word-mcp](https://github.com/kiki830621/che-word-mcp) - Word document MCP server
- [che-apple-mail-mcp](https://github.com/kiki830621/che-apple-mail-mcp) - Apple Mail MCP server
