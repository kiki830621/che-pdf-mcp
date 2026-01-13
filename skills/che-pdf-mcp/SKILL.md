# che-pdf-mcp

A Swift-native MCP server for PDF document manipulation using macOS native frameworks. Provides 25 tools for reading, extracting, searching, merging, OCR, and manipulating PDF files.

## When to Use

Use `che-pdf-mcp` when you need to:

- Get information about PDF files (page count, metadata, version)
- Extract text content from PDF documents
- Search for specific text within PDFs
- Merge multiple PDF files into one
- Extract specific pages from a PDF
- OCR scanned documents using Vision framework
- Convert PDF to Markdown format
- Extract or render images from PDFs
- Detect PDF type (text-based, scanned, mixed)
- Rotate, split, watermark, or encrypt PDFs
- Fetch PDFs from URLs

## Core Workflows

### Get PDF Information

```text
1. pdf_info(path: "/path/to/document.pdf")
   → Returns page count, version, metadata, encryption status
```

### Extract Text

```text
1. pdf_extract_text(path: "/path/to/document.pdf")
   → Returns all text content

   OR with page range:

   pdf_extract_text(path: "...", start_page: 1, end_page: 5)
   → Returns text from pages 1-5
```

### OCR Scanned Documents

```text
1. pdf_ocr_text(path: "/path/to/scanned.pdf", languages: ["en-US", "zh-Hant"])
   → Returns OCR-extracted text

   OR for detailed layout:

   pdf_ocr_page(path: "...", page: 1, languages: ["en-US"])
   → Returns text blocks with position and confidence
```

### Search Text

```text
1. pdf_search_text(path: "/path/to/document.pdf", query: "keyword")
   → Returns matches with page numbers and context
```

### Merge PDFs

```text
1. pdf_merge(
     paths: ["/path/to/file1.pdf", "/path/to/file2.pdf"],
     output_path: "/path/to/merged.pdf"
   )
   → Creates merged PDF
```

### Extract Pages

```text
1. pdf_extract_pages(
     path: "/path/to/source.pdf",
     pages: "1,3,5-10",
     output_path: "/path/to/extracted.pdf"
   )
   → Creates PDF with specified pages
```

### Convert to Markdown

```text
1. pdf_to_markdown(path: "/path/to/document.pdf")
   → Returns Markdown with YAML frontmatter

   OR save to file:

   pdf_to_markdown(path: "...", output_path: "/path/to/output.md")
```

### Render Page to Image

```text
1. pdf_render_page(
     path: "/path/to/document.pdf",
     page: 1,
     output_path: "/path/to/page1.png",
     dpi: 300
   )
   → Renders page as PNG image
```

### Detect PDF Type

```text
1. pdf_detect_type(path: "/path/to/document.pdf")
   → Returns type analysis (text-based, scanned, mixed)
   → Recommends appropriate extraction method
```

### Rotate Pages

```text
1. pdf_rotate_pages(
     path: "/path/to/source.pdf",
     pages: "1-3",
     angle: 90,
     output_path: "/path/to/rotated.pdf"
   )
   → Rotates specified pages
```

### Split PDF

```text
1. pdf_split(
     path: "/path/to/source.pdf",
     split_method: "each",  # or "count:5" or "ranges:1-3,4-6"
     output_directory: "/path/to/output"
   )
   → Creates multiple PDF files
```

### Add Watermark

```text
1. pdf_add_watermark(
     path: "/path/to/source.pdf",
     text: "CONFIDENTIAL",
     output_path: "/path/to/watermarked.pdf"
   )
   → Adds text watermark to all pages
```

### Encrypt PDF

```text
1. pdf_encrypt(
     path: "/path/to/source.pdf",
     user_password: "secret123",
     output_path: "/path/to/encrypted.pdf"
   )
   → Creates password-protected PDF
```

### Fetch from URL

```text
1. pdf_url_fetch(
     url: "https://example.com/document.pdf",
     save_path: "/path/to/local.pdf"
   )
   → Downloads and opens PDF from URL
```

### Session-based Operations

```text
1. pdf_open(path: "/path/to/document.pdf")
   → Returns document_id

2. pdf_extract_text(doc_id: "...")
   pdf_search_text(doc_id: "...", query: "...")
   pdf_ocr_text(doc_id: "...")

3. pdf_close(doc_id: "...")
   → Clean up when done
```

## Tool Reference

### Document Access (6 tools)

- `pdf_info` - Get PDF metadata (pages, version, author, title, etc.)
- `pdf_list` - List PDF files in a directory
- `pdf_open` - Open PDF and get document ID for subsequent operations
- `pdf_close` - Close an open document
- `pdf_list_open` - List all currently open documents
- `pdf_page_count` - Get number of pages

### Text Operations (3 tools)

- `pdf_extract_text` - Extract plain text (with optional page range)
- `pdf_search_text` - Search for text with context
- `pdf_extract_text_with_layout` - Get text with position information

### Document Operations (3 tools)

- `pdf_merge` - Combine multiple PDFs into one
- `pdf_extract_pages` - Extract specific pages (supports "1,3,5-10" format)
- `pdf_save` - Save changes to an open document

### OCR (2 tools)

- `pdf_ocr_text` - Extract text from scanned PDFs using Vision OCR
- `pdf_ocr_page` - OCR single page with position and confidence info

### Structured Output (2 tools)

- `pdf_to_markdown` - Convert PDF to Markdown format
- `pdf_get_outline` - Get PDF outline/table of contents

### Image Processing (2 tools)

- `pdf_extract_images` - Extract embedded images from PDF
- `pdf_render_page` - Render PDF page to image file (PNG/JPG)

### Detection (2 tools)

- `pdf_detect_type` - Detect PDF type (text/scanned/mixed)
- `pdf_check_accessibility` - Check accessibility features

### Advanced Operations (5 tools)

- `pdf_rotate_pages` - Rotate pages (90, 180, 270 degrees)
- `pdf_split` - Split PDF into multiple files
- `pdf_add_watermark` - Add text watermark
- `pdf_encrypt` - Password-protect PDF
- `pdf_url_fetch` - Fetch PDF from URL

## Tips

1. **Direct path vs session**: For single operations, use `path` parameter directly. For multiple operations on the same file, use `pdf_open` first to get a `doc_id`.

2. **Page numbers are 1-indexed**: First page is page 1, not page 0.

3. **Page specification format**: Use comma-separated values and ranges like "1,3,5-10,15".

4. **Search is case-insensitive by default**: Use `case_sensitive: true` if needed.

5. **Merge order matters**: Files are merged in the order provided in the `paths` array.

6. **OCR languages**: Use Vision-supported language codes like "en-US", "zh-Hant", "ja", "ko".

7. **PDF type detection**: Use `pdf_detect_type` first to determine if OCR is needed.

8. **DPI for rendering**: Default is 150 DPI; use 300 for print quality.

## Examples

### Analyze a Research Paper

```text
Get info about ~/Documents/paper.pdf
Detect if it's text-based or scanned
Extract text (or use OCR if scanned)
Search for "methodology" to find relevant sections
Convert to Markdown for easier reading
```

### Combine Reports

```text
Merge quarterly reports:
- ~/Reports/Q1.pdf
- ~/Reports/Q2.pdf
- ~/Reports/Q3.pdf
- ~/Reports/Q4.pdf
into ~/Reports/annual-report.pdf
```

### Process Scanned Document

```text
Detect type of ~/Documents/old_scan.pdf
If scanned, use pdf_ocr_text with appropriate languages
Convert to Markdown for text processing
```

### Secure a Document

```text
Add "CONFIDENTIAL" watermark to ~/Documents/sensitive.pdf
Encrypt with password protection
Save to ~/Documents/secured.pdf
```

### Extract Chapter

```text
Get outline of ~/Books/textbook.pdf
Extract pages 50-80 (Chapter 3)
Save as ~/Excerpts/chapter3.pdf
```
