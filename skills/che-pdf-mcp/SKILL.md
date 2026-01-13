# che-pdf-mcp

A Swift-native MCP server for PDF document manipulation using macOS native frameworks. Provides tools for reading, extracting, searching, merging, and manipulating PDF files.

## When to Use

Use `che-pdf-mcp` when you need to:

- Get information about PDF files (page count, metadata, version)
- Extract text content from PDF documents
- Search for specific text within PDFs
- Merge multiple PDF files into one
- Extract specific pages from a PDF
- List PDF files in a directory

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

### Session-based Operations

```text
1. pdf_open(path: "/path/to/document.pdf")
   → Returns document_id

2. pdf_extract_text(doc_id: "...")
   pdf_search_text(doc_id: "...", query: "...")

3. pdf_close(doc_id: "...")
   → Clean up when done
```

## Tool Reference

### Document Access

- `pdf_info` - Get PDF metadata (pages, version, author, title, etc.)
- `pdf_list` - List PDF files in a directory
- `pdf_open` - Open PDF and get document ID for subsequent operations
- `pdf_close` - Close an open document
- `pdf_list_open` - List all currently open documents
- `pdf_page_count` - Get number of pages

### Text Operations

- `pdf_extract_text` - Extract plain text (with optional page range)
- `pdf_search_text` - Search for text with context
- `pdf_extract_text_with_layout` - Get text with position information

### Document Operations

- `pdf_merge` - Combine multiple PDFs into one
- `pdf_extract_pages` - Extract specific pages (supports "1,3,5-10" format)
- `pdf_save` - Save changes to an open document

## Tips

1. **Direct path vs session**: For single operations, use `path` parameter directly. For multiple operations on the same file, use `pdf_open` first to get a `doc_id`.

2. **Page numbers are 1-indexed**: First page is page 1, not page 0.

3. **Page specification format**: Use comma-separated values and ranges like "1,3,5-10,15".

4. **Search is case-insensitive by default**: Use `case_sensitive: true` if needed.

5. **Merge order matters**: Files are merged in the order provided in the `paths` array.

## Examples

### Analyze a Research Paper

```text
Get info about ~/Documents/paper.pdf
Extract text from pages 1-3 (abstract and introduction)
Search for "methodology" to find relevant sections
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

### Extract Specific Content

```text
Extract the table of contents and first chapter (pages 1-20)
from ~/Books/textbook.pdf to ~/Excerpts/chapter1.pdf
```

### Find Information

```text
Search for "budget" in ~/Documents/proposal.pdf
to find all mentions of budget-related content
```
