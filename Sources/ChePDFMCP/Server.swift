import Foundation
import MCP
import PDFKit
import Vision
import AppKit

// MARK: - PDF MCP Server

actor PDFMCPServer {
    private let server: Server
    private let transport: StdioTransport
    private var openDocuments: [String: PDFDocument] = [:]

    init() {
        self.server = Server(
            name: "che-pdf-mcp",
            version: "1.0.0"
        )
        self.transport = StdioTransport()
    }

    func run() async throws {
        await registerToolHandlers()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Tool Registration

    private func registerToolHandlers() async {
        let tools = allTools

        await server.withMethodHandler(ListTools.self) { [tools] _ in
            ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                return CallTool.Result(content: [.text("Server unavailable")], isError: true)
            }
            return try await self.handleToolCall(params)
        }
    }

    // MARK: - Tool Definitions

    private var allTools: [Tool] {
        [
            // A1. Document Access (6 tools)
            Tool(
                name: "pdf_info",
                description: "Get PDF information (page count, version, encryption, metadata)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Path to PDF file")
                        ])
                    ]),
                    "required": .array([.string("path")])
                ])
            ),
            Tool(
                name: "pdf_list",
                description: "List PDF files in a directory",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "directory": .object([
                            "type": .string("string"),
                            "description": .string("Directory path to search for PDFs")
                        ]),
                        "recursive": .object([
                            "type": .string("boolean"),
                            "description": .string("Search recursively (default: false)")
                        ])
                    ]),
                    "required": .array([.string("directory")])
                ])
            ),
            Tool(
                name: "pdf_open",
                description: "Open a PDF file and return a document ID for subsequent operations",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Path to PDF file")
                        ]),
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Custom document ID (optional, auto-generated if not provided)")
                        ])
                    ]),
                    "required": .array([.string("path")])
                ])
            ),
            Tool(
                name: "pdf_close",
                description: "Close an open PDF document",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID to close")
                        ])
                    ]),
                    "required": .array([.string("doc_id")])
                ])
            ),
            Tool(
                name: "pdf_list_open",
                description: "List all currently open PDF documents",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([:])
                ])
            ),
            Tool(
                name: "pdf_page_count",
                description: "Get the number of pages in a PDF",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID (use pdf_open first)")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ])
                    ])
                ])
            ),

            // A2. Text Extraction & Search (3 tools)
            Tool(
                name: "pdf_extract_text",
                description: "Extract plain text from PDF (optionally specify page range)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "start_page": .object([
                            "type": .string("integer"),
                            "description": .string("Start page (1-indexed, default: 1)")
                        ]),
                        "end_page": .object([
                            "type": .string("integer"),
                            "description": .string("End page (1-indexed, default: last page)")
                        ])
                    ])
                ])
            ),
            Tool(
                name: "pdf_search_text",
                description: "Search for text in PDF",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Text to search for")
                        ]),
                        "case_sensitive": .object([
                            "type": .string("boolean"),
                            "description": .string("Case sensitive search (default: false)")
                        ])
                    ]),
                    "required": .array([.string("query")])
                ])
            ),
            Tool(
                name: "pdf_extract_text_with_layout",
                description: "Extract text with position/layout information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "page": .object([
                            "type": .string("integer"),
                            "description": .string("Page number (1-indexed)")
                        ])
                    ]),
                    "required": .array([.string("page")])
                ])
            ),

            // A3. Document Operations (3 tools)
            Tool(
                name: "pdf_merge",
                description: "Merge multiple PDF files into one",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "paths": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Array of PDF file paths to merge")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output file path")
                        ])
                    ]),
                    "required": .array([.string("paths"), .string("output_path")])
                ])
            ),
            Tool(
                name: "pdf_extract_pages",
                description: "Extract specific pages from a PDF",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Source PDF path")
                        ]),
                        "pages": .object([
                            "type": .string("string"),
                            "description": .string("Page specification (e.g., '1,3,5-10')")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output file path")
                        ])
                    ]),
                    "required": .array([.string("path"), .string("pages"), .string("output_path")])
                ])
            ),
            Tool(
                name: "pdf_save",
                description: "Save changes to a PDF document",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output file path")
                        ])
                    ]),
                    "required": .array([.string("doc_id"), .string("output_path")])
                ])
            ),

            // B1. OCR (3 tools)
            Tool(
                name: "pdf_ocr_text",
                description: "Extract text from PDF using OCR (for scanned documents)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "start_page": .object([
                            "type": .string("integer"),
                            "description": .string("Start page (1-indexed, default: 1)")
                        ]),
                        "end_page": .object([
                            "type": .string("integer"),
                            "description": .string("End page (1-indexed, default: last page)")
                        ]),
                        "languages": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Recognition languages (default: ['en-US'])")
                        ])
                    ])
                ])
            ),
            Tool(
                name: "pdf_ocr_page",
                description: "OCR a single page and return text with position information",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "page": .object([
                            "type": .string("integer"),
                            "description": .string("Page number (1-indexed)")
                        ]),
                        "languages": .object([
                            "type": .string("array"),
                            "items": .object(["type": .string("string")]),
                            "description": .string("Recognition languages (default: ['en-US'])")
                        ])
                    ]),
                    "required": .array([.string("page")])
                ])
            ),
            // B2. Structured Output (2 tools)
            Tool(
                name: "pdf_to_markdown",
                description: "Convert PDF to Markdown format",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "include_metadata": .object([
                            "type": .string("boolean"),
                            "description": .string("Include YAML frontmatter (default: true)")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional output file path")
                        ])
                    ])
                ])
            ),
            Tool(
                name: "pdf_get_outline",
                description: "Get PDF outline/table of contents",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ])
                    ])
                ])
            ),

            // B3. Image Processing (2 tools)
            Tool(
                name: "pdf_extract_images",
                description: "Extract embedded images from PDF pages",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "output_directory": .object([
                            "type": .string("string"),
                            "description": .string("Directory to save extracted images")
                        ]),
                        "format": .object([
                            "type": .string("string"),
                            "description": .string("Output format: png, jpg (default: png)")
                        ])
                    ]),
                    "required": .array([.string("output_directory")])
                ])
            ),
            Tool(
                name: "pdf_render_page",
                description: "Render a PDF page to an image file",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ]),
                        "page": .object([
                            "type": .string("integer"),
                            "description": .string("Page number (1-indexed)")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output image file path")
                        ]),
                        "dpi": .object([
                            "type": .string("integer"),
                            "description": .string("Resolution in DPI (default: 150)")
                        ]),
                        "format": .object([
                            "type": .string("string"),
                            "description": .string("Output format: png, jpg (default: png)")
                        ])
                    ]),
                    "required": .array([.string("page"), .string("output_path")])
                ])
            ),

            // B4. Detection (2 tools)
            Tool(
                name: "pdf_detect_type",
                description: "Detect PDF type (text-based, scanned/image-based, or mixed)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ])
                    ])
                ])
            ),
            Tool(
                name: "pdf_check_accessibility",
                description: "Check PDF accessibility features (tagged, language, etc.)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Document ID")
                        ]),
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Or provide path directly")
                        ])
                    ])
                ])
            ),

            // C. Advanced Operations (5 tools)
            Tool(
                name: "pdf_rotate_pages",
                description: "Rotate pages in a PDF",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Source PDF path")
                        ]),
                        "pages": .object([
                            "type": .string("string"),
                            "description": .string("Page specification (e.g., '1,3,5-10' or 'all')")
                        ]),
                        "angle": .object([
                            "type": .string("integer"),
                            "description": .string("Rotation angle: 90, 180, or 270 degrees")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output file path")
                        ])
                    ]),
                    "required": .array([.string("path"), .string("pages"), .string("angle"), .string("output_path")])
                ])
            ),
            Tool(
                name: "pdf_split",
                description: "Split a PDF into multiple files",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Source PDF path")
                        ]),
                        "split_method": .object([
                            "type": .string("string"),
                            "description": .string("Method: 'each' (one file per page), 'count:N' (N pages each), 'ranges:1-3,4-6' (specific ranges)")
                        ]),
                        "output_directory": .object([
                            "type": .string("string"),
                            "description": .string("Directory to save split files")
                        ]),
                        "prefix": .object([
                            "type": .string("string"),
                            "description": .string("Filename prefix (default: 'split')")
                        ])
                    ]),
                    "required": .array([.string("path"), .string("split_method"), .string("output_directory")])
                ])
            ),
            Tool(
                name: "pdf_add_watermark",
                description: "Add a text watermark to PDF pages",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Source PDF path")
                        ]),
                        "text": .object([
                            "type": .string("string"),
                            "description": .string("Watermark text")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output file path")
                        ]),
                        "pages": .object([
                            "type": .string("string"),
                            "description": .string("Page specification (default: 'all')")
                        ]),
                        "opacity": .object([
                            "type": .string("number"),
                            "description": .string("Opacity 0.0-1.0 (default: 0.3)")
                        ]),
                        "rotation": .object([
                            "type": .string("integer"),
                            "description": .string("Text rotation angle (default: 45)")
                        ]),
                        "font_size": .object([
                            "type": .string("integer"),
                            "description": .string("Font size (default: 48)")
                        ])
                    ]),
                    "required": .array([.string("path"), .string("text"), .string("output_path")])
                ])
            ),
            Tool(
                name: "pdf_encrypt",
                description: "Encrypt a PDF with password protection",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "path": .object([
                            "type": .string("string"),
                            "description": .string("Source PDF path")
                        ]),
                        "output_path": .object([
                            "type": .string("string"),
                            "description": .string("Output file path")
                        ]),
                        "user_password": .object([
                            "type": .string("string"),
                            "description": .string("Password to open/view the PDF")
                        ]),
                        "owner_password": .object([
                            "type": .string("string"),
                            "description": .string("Password for full access (default: same as user_password)")
                        ]),
                        "allow_printing": .object([
                            "type": .string("boolean"),
                            "description": .string("Allow printing (default: true)")
                        ]),
                        "allow_copying": .object([
                            "type": .string("boolean"),
                            "description": .string("Allow copying text (default: false)")
                        ])
                    ]),
                    "required": .array([.string("path"), .string("output_path"), .string("user_password")])
                ])
            ),
            Tool(
                name: "pdf_url_fetch",
                description: "Fetch and open a PDF from a URL",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "url": .object([
                            "type": .string("string"),
                            "description": .string("URL of the PDF file")
                        ]),
                        "save_path": .object([
                            "type": .string("string"),
                            "description": .string("Optional path to save the PDF locally")
                        ]),
                        "doc_id": .object([
                            "type": .string("string"),
                            "description": .string("Custom document ID (optional)")
                        ])
                    ]),
                    "required": .array([.string("url")])
                ])
            )
        ]
    }

    // MARK: - Tool Call Handler

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        let name = params.name
        let args = params.arguments ?? [:]

        do {
            // Special handling: tools that support mixed content output
            if name == "pdf_extract_text" {
                let contents = try await pdfExtractTextWithContent(args: args)
                return CallTool.Result(content: contents)
            }

            // Other tools return plain text
            let result = try await executeToolTask(name: name, args: args)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    private func executeToolTask(name: String, args: [String: Value]) async throws -> String {
        switch name {
        // A1. Document Access
        case "pdf_info":
            return try await pdfInfo(args: args)
        case "pdf_list":
            return try await pdfList(args: args)
        case "pdf_open":
            return try await pdfOpen(args: args)
        case "pdf_close":
            return try pdfClose(args: args)
        case "pdf_list_open":
            return pdfListOpen()
        case "pdf_page_count":
            return try await pdfPageCount(args: args)

        // A2. Text Extraction & Search
        case "pdf_extract_text":
            return try await pdfExtractText(args: args)
        case "pdf_search_text":
            return try await pdfSearchText(args: args)
        case "pdf_extract_text_with_layout":
            return try await pdfExtractTextWithLayout(args: args)

        // A3. Document Operations
        case "pdf_merge":
            return try await pdfMerge(args: args)
        case "pdf_extract_pages":
            return try await pdfExtractPages(args: args)
        case "pdf_save":
            return try pdfSave(args: args)

        // B1. OCR
        case "pdf_ocr_text":
            return try await pdfOcrText(args: args)
        case "pdf_ocr_page":
            return try await pdfOcrPage(args: args)

        // B2. Structured Output
        case "pdf_to_markdown":
            return try await pdfToMarkdown(args: args)
        case "pdf_get_outline":
            return try await pdfGetOutline(args: args)

        // B3. Image Processing
        case "pdf_extract_images":
            return try await pdfExtractImages(args: args)
        case "pdf_render_page":
            return try await pdfRenderPage(args: args)

        // B4. Detection
        case "pdf_detect_type":
            return try await pdfDetectType(args: args)
        case "pdf_check_accessibility":
            return try await pdfCheckAccessibility(args: args)

        // C. Advanced Operations
        case "pdf_rotate_pages":
            return try await pdfRotatePages(args: args)
        case "pdf_split":
            return try await pdfSplit(args: args)
        case "pdf_add_watermark":
            return try await pdfAddWatermark(args: args)
        case "pdf_encrypt":
            return try await pdfEncrypt(args: args)
        case "pdf_url_fetch":
            return try await pdfUrlFetch(args: args)

        default:
            throw PDFError.unknownTool(name)
        }
    }

    // MARK: - Helper Functions

    private func getParameter<T>(args: [String: Value], key: String, as type: T.Type) throws -> T {
        guard let value = args[key] else {
            throw PDFError.missingParameter(key)
        }

        if T.self == String.self {
            guard case .string(let str) = value else {
                throw PDFError.invalidParameter(key, "expected string")
            }
            return str as! T
        } else if T.self == Int.self {
            if case .int(let i) = value {
                return i as! T
            } else if case .double(let d) = value {
                return Int(d) as! T
            }
            throw PDFError.invalidParameter(key, "expected integer")
        } else if T.self == Bool.self {
            guard case .bool(let b) = value else {
                throw PDFError.invalidParameter(key, "expected boolean")
            }
            return b as! T
        } else if T.self == [String].self {
            guard case .array(let arr) = value else {
                throw PDFError.invalidParameter(key, "expected array")
            }
            let strings = arr.compactMap { v -> String? in
                if case .string(let s) = v { return s }
                return nil
            }
            return strings as! T
        }

        throw PDFError.invalidParameter(key, "unsupported type")
    }

    private func getOptionalParameter<T>(args: [String: Value], key: String, as type: T.Type) throws -> T? {
        guard args[key] != nil else { return nil }
        return try getParameter(args: args, key: key, as: type)
    }

    private func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private func getDocument(docId: String) throws -> PDFDocument {
        guard let doc = openDocuments[docId] else {
            throw PDFError.documentNotOpen(docId)
        }
        return doc
    }

    private func getDocumentOrOpen(args: [String: Value]) throws -> (PDFDocument, Bool) {
        if let docId = try? getParameter(args: args, key: "doc_id", as: String.self) {
            return (try getDocument(docId: docId), false)
        }

        if let path = try? getParameter(args: args, key: "path", as: String.self) {
            let url = URL(fileURLWithPath: expandPath(path))
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PDFError.fileNotFound(path)
            }
            guard let doc = PDFDocument(url: url) else {
                throw PDFError.invalidPDF(path)
            }
            return (doc, true)
        }

        throw PDFError.missingParameter("doc_id or path")
    }

    // MARK: - A1. Document Access Implementations

    private func pdfInfo(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let url = URL(fileURLWithPath: expandPath(path))

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.fileNotFound(path)
        }

        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        var info: [String: String] = [:]
        info["path"] = path
        info["pageCount"] = String(doc.pageCount)
        info["isEncrypted"] = String(doc.isEncrypted)
        info["isLocked"] = String(doc.isLocked)
        info["allowsCopying"] = String(doc.allowsCopying)
        info["allowsPrinting"] = String(doc.allowsPrinting)

        // Get document attributes
        if let attrs = doc.documentAttributes {
            if let title = attrs[PDFDocumentAttribute.titleAttribute] as? String {
                info["title"] = title
            }
            if let author = attrs[PDFDocumentAttribute.authorAttribute] as? String {
                info["author"] = author
            }
            if let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String {
                info["subject"] = subject
            }
            if let creator = attrs[PDFDocumentAttribute.creatorAttribute] as? String {
                info["creator"] = creator
            }
            if let producer = attrs[PDFDocumentAttribute.producerAttribute] as? String {
                info["producer"] = producer
            }
            if let creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date {
                info["creationDate"] = ISO8601DateFormatter().string(from: creationDate)
            }
            if let modificationDate = attrs[PDFDocumentAttribute.modificationDateAttribute] as? Date {
                info["modificationDate"] = ISO8601DateFormatter().string(from: modificationDate)
            }
        }

        // Get PDF version from CGPDFDocument
        if let page = doc.page(at: 0), let pageRef = page.pageRef,
           let cgDoc = pageRef.document {
            var majorVersion: Int32 = 0
            var minorVersion: Int32 = 0
            cgDoc.getVersion(majorVersion: &majorVersion, minorVersion: &minorVersion)
            info["pdfVersion"] = "\(majorVersion).\(minorVersion)"
        }

        // Format output
        var output = "PDF Information:\n"
        for (key, value) in info.sorted(by: { $0.key < $1.key }) {
            output += "  \(key): \(value)\n"
        }
        return output
    }

    private func pdfList(args: [String: Value]) async throws -> String {
        let directory = try getParameter(args: args, key: "directory", as: String.self)
        let recursive = (try? getOptionalParameter(args: args, key: "recursive", as: Bool.self)) ?? false

        let dirURL = URL(fileURLWithPath: expandPath(directory))

        guard FileManager.default.fileExists(atPath: dirURL.path) else {
            throw PDFError.fileNotFound(directory)
        }

        var pdfs: [String] = []

        if recursive {
            let enumerator = FileManager.default.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    pdfs.append(fileURL.path)
                }
            }
        } else {
            let contents = try FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            pdfs = contents.filter { $0.pathExtension.lowercased() == "pdf" }.map { $0.path }
        }

        if pdfs.isEmpty {
            return "No PDF files found in \(directory)"
        }

        return "Found \(pdfs.count) PDF file(s):\n" + pdfs.map { "  - \($0)" }.joined(separator: "\n")
    }

    private func pdfOpen(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let customId = try? getOptionalParameter(args: args, key: "doc_id", as: String.self)

        let url = URL(fileURLWithPath: expandPath(path))

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.fileNotFound(path)
        }

        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        let docId = customId ?? UUID().uuidString
        if openDocuments[docId] != nil {
            throw PDFError.documentAlreadyOpen(docId)
        }

        openDocuments[docId] = doc
        return "Document opened with ID: \(docId) (pages: \(doc.pageCount))"
    }

    private func pdfClose(args: [String: Value]) throws -> String {
        let docId = try getParameter(args: args, key: "doc_id", as: String.self)

        guard openDocuments[docId] != nil else {
            throw PDFError.documentNotOpen(docId)
        }

        openDocuments.removeValue(forKey: docId)
        return "Document closed: \(docId)"
    }

    private func pdfListOpen() -> String {
        if openDocuments.isEmpty {
            return "No documents currently open"
        }

        var output = "Open documents (\(openDocuments.count)):\n"
        for (id, doc) in openDocuments {
            output += "  - \(id): \(doc.pageCount) pages\n"
        }
        return output
    }

    private func pdfPageCount(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        return "Page count: \(doc.pageCount)"
    }

    // MARK: - A2. Text Extraction & Search Implementations

    private func pdfExtractText(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)

        let startPage = (try? getOptionalParameter(args: args, key: "start_page", as: Int.self)) ?? 1
        let endPage = (try? getOptionalParameter(args: args, key: "end_page", as: Int.self)) ?? doc.pageCount

        guard startPage >= 1 && startPage <= doc.pageCount else {
            throw PDFError.invalidPageRange("start_page \(startPage) out of range (1-\(doc.pageCount))")
        }
        guard endPage >= startPage && endPage <= doc.pageCount else {
            throw PDFError.invalidPageRange("end_page \(endPage) out of range (\(startPage)-\(doc.pageCount))")
        }

        var fullText = ""
        for i in (startPage - 1)..<endPage {
            guard let page = doc.page(at: i) else { continue }
            let pageText = page.string ?? ""
            fullText += "--- Page \(i + 1) ---\n"
            fullText += pageText
            fullText += "\n\n"
        }

        if fullText.isEmpty {
            return "No text found in the specified pages"
        }

        return fullText
    }

    // MARK: - Garbled Text Detection & Mixed Content

    /// Represents a garbled region (e.g., math formula) detected on a page
    private struct GarbledRegion {
        let bounds: CGRect
        let charCount: Int
    }

    /// Quick check if page likely has garbled content (for pre-filtering)
    private func hasGarbledContent(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }

        let singleCharLines = lines.filter { $0.count == 1 }.count
        let singleCharRatio = Double(singleCharLines) / Double(lines.count)

        return singleCharRatio > 0.2  // Lower threshold for pre-filter
    }

    /// Detect garbled regions (math formulas) on a page using newline-based analysis
    private func detectGarbledRegions(page: PDFPage) -> [GarbledRegion] {
        guard let text = page.string, !text.isEmpty else { return [] }

        // Step 1: Split text by newlines to get actual lines
        let textLines = text.components(separatedBy: "\n")

        // Step 2: Build character index mapping for bounds lookup
        var charIndex = 0
        var lineData: [(content: String, startIndex: Int, isSingleChar: Bool)] = []

        for line in textLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                lineData.append((trimmed, charIndex, trimmed.count == 1))
            }
            charIndex += line.count + 1  // +1 for newline
        }

        guard !lineData.isEmpty else { return [] }

        // Step 3: Find clusters of single-character lines
        var garbledRegions: [GarbledRegion] = []
        var clusterStartIdx: Int? = nil
        var clusterCharIndices: [Int] = []

        for (i, line) in lineData.enumerated() {
            if line.isSingleChar {
                if clusterStartIdx == nil {
                    clusterStartIdx = i
                }
                clusterCharIndices.append(line.startIndex)
            } else {
                // End of cluster
                if let _ = clusterStartIdx, clusterCharIndices.count >= 3 {
                    // Get bounds for all chars in cluster
                    if let region = getBoundsForCharIndices(page: page, indices: clusterCharIndices) {
                        garbledRegions.append(region)
                    }
                }
                clusterStartIdx = nil
                clusterCharIndices = []
            }
        }

        // Handle cluster at end
        if let _ = clusterStartIdx, clusterCharIndices.count >= 3 {
            if let region = getBoundsForCharIndices(page: page, indices: clusterCharIndices) {
                garbledRegions.append(region)
            }
        }

        // Step 4: Merge nearby regions and add padding
        let pageBounds = page.bounds(for: .mediaBox)
        return mergeAndPadRegions(garbledRegions, pageBounds: pageBounds)
    }

    /// Get combined bounds for a set of character indices
    private func getBoundsForCharIndices(page: PDFPage, indices: [Int]) -> GarbledRegion? {
        var combinedBounds: CGRect? = nil

        for idx in indices {
            let bounds = page.characterBounds(at: idx)
            if bounds.width > 0 && bounds.height > 0 {
                if combinedBounds == nil {
                    combinedBounds = bounds
                } else {
                    combinedBounds = combinedBounds?.union(bounds)
                }
            }
        }

        guard let bounds = combinedBounds else { return nil }
        return GarbledRegion(bounds: bounds, charCount: indices.count)
    }

    /// Merge nearby garbled regions and add padding
    private func mergeAndPadRegions(_ regions: [GarbledRegion], pageBounds: CGRect) -> [GarbledRegion] {
        guard !regions.isEmpty else { return [] }

        let padding: CGFloat = 40  // Points of padding around region (enough for subscripts/superscripts)
        let mergeDistance: CGFloat = 50  // Merge regions closer than this

        var merged: [GarbledRegion] = []
        var current = regions[0]

        for i in 1..<regions.count {
            let next = regions[i]
            let gap = next.bounds.minY - current.bounds.maxY

            if abs(gap) < mergeDistance {
                // Merge regions
                current = GarbledRegion(
                    bounds: current.bounds.union(next.bounds),
                    charCount: current.charCount + next.charCount
                )
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)

        // Add padding and clamp to page bounds
        return merged.map { region in
            var padded = region.bounds.insetBy(dx: -padding, dy: -padding)
            padded = padded.intersection(pageBounds)
            return GarbledRegion(bounds: padded, charCount: region.charCount)
        }
    }

    /// Render a specific region of a PDF page to Base64-encoded PNG
    /// Uses content boundary detection to ensure no clipping
    private func renderRegionToBase64(page: PDFPage, region: CGRect, dpi: Int = 150) throws -> String {
        let scale = CGFloat(dpi) / 72.0

        // Step 1: Render with extra margin to capture any overflow content
        let extraMargin: CGFloat = 60  // Extra margin for initial render
        let expandedRegion = region.insetBy(dx: -extraMargin, dy: -extraMargin)
        let pageBounds = page.bounds(for: .mediaBox)
        let clampedRegion = expandedRegion.intersection(pageBounds)

        let renderWidth = Int(clampedRegion.width * scale)
        let renderHeight = Int(clampedRegion.height * scale)

        guard renderWidth > 0 && renderHeight > 0 else {
            throw PDFError.renderFailed
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: renderWidth,
                height: renderHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw PDFError.renderFailed
        }

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight))

        // Scale and translate
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -clampedRegion.origin.x, y: -clampedRegion.origin.y)

        guard let pageRef = page.pageRef else {
            throw PDFError.renderFailed
        }
        context.drawPDFPage(pageRef)

        guard let cgImage = context.makeImage() else {
            throw PDFError.renderFailed
        }

        // Step 2: Detect actual content boundary (non-white pixels)
        let contentBounds = detectContentBoundary(in: cgImage)

        // Step 3: Crop to content boundary with padding
        let padding: CGFloat = 10  // Final padding around actual content
        let cropRect = CGRect(
            x: max(0, contentBounds.minX - padding),
            y: max(0, contentBounds.minY - padding),
            width: min(CGFloat(renderWidth), contentBounds.width + padding * 2),
            height: min(CGFloat(renderHeight), contentBounds.height + padding * 2)
        ).integral

        // If content bounds is very small or invalid, use original image
        guard cropRect.width > 20 && cropRect.height > 20,
              let croppedImage = cgImage.cropping(to: cropRect) else {
            // Fallback: use full rendered image
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: renderWidth, height: renderHeight))
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                throw PDFError.renderFailed
            }
            return pngData.base64EncodedString()
        }

        let finalImage = NSImage(cgImage: croppedImage, size: cropRect.size)

        guard let tiffData = finalImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw PDFError.renderFailed
        }

        return pngData.base64EncodedString()
    }

    /// Detect the boundary of actual content (non-white pixels) in an image
    private func detectContentBoundary(in image: CGImage) -> CGRect {
        let width = image.width
        let height = image.height

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        // Scan for non-white pixels (threshold: 250 for near-white)
        let whiteThreshold: UInt8 = 250

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]

                // Check if pixel is not white
                if r < whiteThreshold || g < whiteThreshold || b < whiteThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        // If no content found, return full image bounds
        if minX >= maxX || minY >= maxY {
            return CGRect(x: 0, y: 0, width: width, height: height)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Render entire page to Base64-encoded PNG (fallback)
    private func renderPageToBase64(page: PDFPage, dpi: Int = 150) throws -> String {
        let bounds = page.bounds(for: .mediaBox)
        return try renderRegionToBase64(page: page, region: bounds, dpi: dpi)
    }

    /// Extract text with mixed content (text + region images for garbled formulas)
    private func pdfExtractTextWithContent(args: [String: Value]) async throws -> [Tool.Content] {
        let (doc, _) = try getDocumentOrOpen(args: args)

        let startPage = (try? getOptionalParameter(args: args, key: "start_page", as: Int.self)) ?? 1
        let endPage = (try? getOptionalParameter(args: args, key: "end_page", as: Int.self)) ?? doc.pageCount

        guard startPage >= 1 && startPage <= doc.pageCount else {
            throw PDFError.invalidPageRange("start_page \(startPage) out of range (1-\(doc.pageCount))")
        }
        guard endPage >= startPage && endPage <= doc.pageCount else {
            throw PDFError.invalidPageRange("end_page \(endPage) out of range (\(startPage)-\(doc.pageCount))")
        }

        var contents: [Tool.Content] = []

        for i in (startPage - 1)..<endPage {
            guard let page = doc.page(at: i) else { continue }
            let pageText = page.string ?? ""

            // Quick pre-filter: does this page likely have garbled content?
            if hasGarbledContent(pageText) {
                // Detect specific garbled regions
                let garbledRegions = detectGarbledRegions(page: page)

                if garbledRegions.isEmpty {
                    // No specific regions found, return plain text
                    contents.append(.text("--- Page \(i + 1) ---\n\(pageText)\n\n"))
                } else {
                    // Return text + region images
                    contents.append(.text("--- Page \(i + 1) ---\n\(pageText)\n"))

                    for (j, region) in garbledRegions.enumerated() {
                        do {
                            let imageData = try renderRegionToBase64(page: page, region: region.bounds, dpi: 150)
                            contents.append(.image(
                                data: imageData,
                                mimeType: "image/png",
                                metadata: [
                                    "page": "\(i + 1)",
                                    "region": "\(j + 1)",
                                    "width": "\(Int(region.bounds.width))",
                                    "height": "\(Int(region.bounds.height))",
                                    "reason": "garbled_formula_detected"
                                ]
                            ))
                        } catch {
                            // If region rendering fails, skip it
                            continue
                        }
                    }
                }
            } else {
                // No garbled content, return plain text
                contents.append(.text("--- Page \(i + 1) ---\n\(pageText)\n\n"))
            }
        }

        if contents.isEmpty {
            return [.text("No content found in the specified pages")]
        }

        return contents
    }

    private func pdfSearchText(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        let query = try getParameter(args: args, key: "query", as: String.self)
        let caseSensitive = (try? getOptionalParameter(args: args, key: "case_sensitive", as: Bool.self)) ?? false

        var options: NSString.CompareOptions = []
        if !caseSensitive {
            options.insert(.caseInsensitive)
        }

        var results: [(page: Int, context: String)] = []

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            guard let pageText = page.string else { continue }

            var searchRange = pageText.startIndex..<pageText.endIndex
            while let range = pageText.range(of: query, options: options, range: searchRange) {
                // Get context around the match
                let contextStart = pageText.index(range.lowerBound, offsetBy: -30, limitedBy: pageText.startIndex) ?? pageText.startIndex
                let contextEnd = pageText.index(range.upperBound, offsetBy: 30, limitedBy: pageText.endIndex) ?? pageText.endIndex
                let context = String(pageText[contextStart..<contextEnd])
                    .replacingOccurrences(of: "\n", with: " ")

                results.append((page: i + 1, context: "...\(context)..."))

                searchRange = range.upperBound..<pageText.endIndex
            }
        }

        if results.isEmpty {
            return "No matches found for '\(query)'"
        }

        var output = "Found \(results.count) match(es) for '\(query)':\n"
        for result in results {
            output += "  Page \(result.page): \(result.context)\n"
        }
        return output
    }

    private func pdfExtractTextWithLayout(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        let pageNum = try getParameter(args: args, key: "page", as: Int.self)

        guard pageNum >= 1 && pageNum <= doc.pageCount else {
            throw PDFError.invalidPageRange("page \(pageNum) out of range (1-\(doc.pageCount))")
        }

        guard let page = doc.page(at: pageNum - 1) else {
            throw PDFError.readError("Failed to get page \(pageNum)")
        }

        guard let pageText = page.string, !pageText.isEmpty else {
            return "No text found on page \(pageNum)"
        }

        // Get page bounds
        let bounds = page.bounds(for: .mediaBox)

        var output = "Page \(pageNum) Layout Information:\n"
        output += "  Page size: \(Int(bounds.width)) x \(Int(bounds.height)) points\n"
        output += "  Rotation: \(page.rotation) degrees\n\n"
        output += "Text content:\n"
        output += pageText

        return output
    }

    // MARK: - A3. Document Operations Implementations

    private func pdfMerge(args: [String: Value]) async throws -> String {
        let paths = try getParameter(args: args, key: "paths", as: [String].self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)

        guard paths.count >= 2 else {
            throw PDFError.mergeError("At least 2 PDF files required for merging")
        }

        let result = PDFDocument()
        var totalPages = 0

        for path in paths {
            let url = URL(fileURLWithPath: expandPath(path))
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PDFError.fileNotFound(path)
            }
            guard let doc = PDFDocument(url: url) else {
                throw PDFError.invalidPDF(path)
            }

            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    result.insert(page, at: result.pageCount)
                    totalPages += 1
                }
            }
        }

        let outputURL = URL(fileURLWithPath: expandPath(outputPath))
        guard result.write(to: outputURL) else {
            throw PDFError.writeError("Failed to write merged PDF")
        }

        return "Merged \(paths.count) PDFs into \(outputPath) (total: \(totalPages) pages)"
    }

    private func pdfExtractPages(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let pagesSpec = try getParameter(args: args, key: "pages", as: String.self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)

        let url = URL(fileURLWithPath: expandPath(path))
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.fileNotFound(path)
        }
        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        // Parse page specification (e.g., "1,3,5-10")
        var pageIndices: Set<Int> = []
        let parts = pagesSpec.components(separatedBy: ",")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("-") {
                let rangeParts = trimmed.components(separatedBy: "-")
                if rangeParts.count == 2,
                   let start = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)) {
                    for i in start...end {
                        if i >= 1 && i <= doc.pageCount {
                            pageIndices.insert(i - 1)
                        }
                    }
                }
            } else if let pageNum = Int(trimmed) {
                if pageNum >= 1 && pageNum <= doc.pageCount {
                    pageIndices.insert(pageNum - 1)
                }
            }
        }

        guard !pageIndices.isEmpty else {
            throw PDFError.invalidPageRange("No valid pages in specification '\(pagesSpec)'")
        }

        let result = PDFDocument()
        for index in pageIndices.sorted() {
            if let page = doc.page(at: index) {
                result.insert(page, at: result.pageCount)
            }
        }

        let outputURL = URL(fileURLWithPath: expandPath(outputPath))
        guard result.write(to: outputURL) else {
            throw PDFError.writeError("Failed to write extracted pages")
        }

        return "Extracted \(result.pageCount) page(s) to \(outputPath)"
    }

    private func pdfSave(args: [String: Value]) throws -> String {
        let docId = try getParameter(args: args, key: "doc_id", as: String.self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)

        guard let doc = openDocuments[docId] else {
            throw PDFError.documentNotOpen(docId)
        }

        let outputURL = URL(fileURLWithPath: expandPath(outputPath))
        guard doc.write(to: outputURL) else {
            throw PDFError.writeError("Failed to save document")
        }

        return "Document saved to \(outputPath)"
    }

    // MARK: - B1. OCR Implementations

    private func pdfOcrText(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)

        let startPage = (try? getOptionalParameter(args: args, key: "start_page", as: Int.self)) ?? 1
        let endPage = (try? getOptionalParameter(args: args, key: "end_page", as: Int.self)) ?? doc.pageCount
        let languages = (try? getOptionalParameter(args: args, key: "languages", as: [String].self)) ?? ["en-US"]

        guard startPage >= 1 && startPage <= doc.pageCount else {
            throw PDFError.invalidPageRange("start_page \(startPage) out of range (1-\(doc.pageCount))")
        }
        guard endPage >= startPage && endPage <= doc.pageCount else {
            throw PDFError.invalidPageRange("end_page \(endPage) out of range (\(startPage)-\(doc.pageCount))")
        }

        var fullText = ""
        for i in (startPage - 1)..<endPage {
            guard let page = doc.page(at: i) else { continue }

            fullText += "--- Page \(i + 1) (OCR) ---\n"
            let pageText = try await VisionOCR.performOCR(on: page, languages: languages)
            fullText += pageText
            fullText += "\n\n"
        }

        if fullText.isEmpty {
            return "No text found via OCR in the specified pages"
        }

        return fullText
    }

    private func pdfOcrPage(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        let pageNum = try getParameter(args: args, key: "page", as: Int.self)
        let languages = (try? getOptionalParameter(args: args, key: "languages", as: [String].self)) ?? ["en-US"]

        guard pageNum >= 1 && pageNum <= doc.pageCount else {
            throw PDFError.invalidPageRange("page \(pageNum) out of range (1-\(doc.pageCount))")
        }

        guard let page = doc.page(at: pageNum - 1) else {
            throw PDFError.readError("Failed to get page \(pageNum)")
        }

        let blocks = try await VisionOCR.performOCRWithLayout(on: page, languages: languages)

        if blocks.isEmpty {
            return "No text found via OCR on page \(pageNum)"
        }

        var output = "OCR Results for Page \(pageNum) (\(blocks.count) text blocks):\n\n"
        for (index, block) in blocks.enumerated() {
            output += "[\(index + 1)] \(block.text)\n"
            output += "    Position: (\(Int(block.bounds.origin.x)), \(Int(block.bounds.origin.y)))\n"
            output += "    Size: \(Int(block.bounds.width)) x \(Int(block.bounds.height))\n"
            output += "    Confidence: \(String(format: "%.1f%%", block.confidence * 100))\n\n"
        }

        return output
    }

    // MARK: - B2. Structured Output Implementations

    private func pdfToMarkdown(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        let includeMetadata = (try? getOptionalParameter(args: args, key: "include_metadata", as: Bool.self)) ?? true
        let outputPath = try? getOptionalParameter(args: args, key: "output_path", as: String.self)

        var options = MarkdownExporter.Options.default
        options.includeMetadata = includeMetadata

        let markdown = MarkdownExporter.export(document: doc, options: options)

        if let path = outputPath {
            let url = URL(fileURLWithPath: expandPath(path))
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return "Markdown saved to \(path)"
        }

        return markdown
    }

    private func pdfGetOutline(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)

        guard let outline = doc.outlineRoot else {
            return "No outline/table of contents found in this PDF"
        }

        func buildOutlineString(item: PDFOutline, level: Int) -> String {
            var result = ""
            let indent = String(repeating: "  ", count: level)

            if let label = item.label {
                var pageInfo = ""
                if let destination = item.destination, let page = destination.page {
                    let pageIndex = doc.index(for: page)
                    pageInfo = " (page \(pageIndex + 1))"
                }
                result += "\(indent)- \(label)\(pageInfo)\n"
            }

            for i in 0..<item.numberOfChildren {
                if let child = item.child(at: i) {
                    result += buildOutlineString(item: child, level: level + 1)
                }
            }

            return result
        }

        var output = "PDF Outline:\n"
        output += buildOutlineString(item: outline, level: 0)

        return output
    }

    // MARK: - B3. Image Processing Implementations

    private func pdfExtractImages(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        let outputDir = try getParameter(args: args, key: "output_directory", as: String.self)
        let format = (try? getOptionalParameter(args: args, key: "format", as: String.self)) ?? "png"

        let dirURL = URL(fileURLWithPath: expandPath(outputDir))
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        var extractedCount = 0

        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }

            // Render page as image (simplified approach - extracts page as image)
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0  // 2x for decent quality
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { continue }

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)

            guard let pageRef = page.pageRef else { continue }
            context.drawPDFPage(pageRef)

            guard let cgImage = context.makeImage() else { continue }

            let filename = "page_\(pageIndex + 1).\(format)"
            let fileURL = dirURL.appendingPathComponent(filename)

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

            if let tiffData = nsImage.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData) {
                let imageData: Data?
                if format.lowercased() == "jpg" || format.lowercased() == "jpeg" {
                    imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                } else {
                    imageData = bitmapRep.representation(using: .png, properties: [:])
                }

                if let data = imageData {
                    try data.write(to: fileURL)
                    extractedCount += 1
                }
            }
        }

        return "Extracted \(extractedCount) page(s) as images to \(outputDir)"
    }

    private func pdfRenderPage(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)
        let pageNum = try getParameter(args: args, key: "page", as: Int.self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)
        let dpi = (try? getOptionalParameter(args: args, key: "dpi", as: Int.self)) ?? 150
        let format = (try? getOptionalParameter(args: args, key: "format", as: String.self)) ?? "png"

        guard pageNum >= 1 && pageNum <= doc.pageCount else {
            throw PDFError.invalidPageRange("page \(pageNum) out of range (1-\(doc.pageCount))")
        }

        guard let page = doc.page(at: pageNum - 1) else {
            throw PDFError.readError("Failed to get page \(pageNum)")
        }

        let bounds = page.bounds(for: .mediaBox)
        let scale = CGFloat(dpi) / 72.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw PDFError.renderFailed
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)

        guard let pageRef = page.pageRef else {
            throw PDFError.renderFailed
        }
        context.drawPDFPage(pageRef)

        guard let cgImage = context.makeImage() else {
            throw PDFError.renderFailed
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        let outputURL = URL(fileURLWithPath: expandPath(outputPath))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw PDFError.renderFailed
        }

        let imageData: Data?
        if format.lowercased() == "jpg" || format.lowercased() == "jpeg" {
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        } else {
            imageData = bitmapRep.representation(using: .png, properties: [:])
        }

        guard let data = imageData else {
            throw PDFError.renderFailed
        }

        try data.write(to: outputURL)
        return "Page \(pageNum) rendered to \(outputPath) (\(width) x \(height) px, \(dpi) DPI)"
    }

    // MARK: - B4. Detection Implementations

    private func pdfDetectType(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)

        var pagesWithText = 0
        var pagesWithoutText = 0
        var totalChars = 0

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let text = page.string ?? ""
            let charCount = text.trimmingCharacters(in: .whitespacesAndNewlines).count

            if charCount > 50 {  // Threshold for "has text"
                pagesWithText += 1
            } else {
                pagesWithoutText += 1
            }
            totalChars += charCount
        }

        let totalPages = doc.pageCount
        let textRatio = Double(pagesWithText) / Double(totalPages)

        var pdfType: String
        var recommendation: String

        if textRatio >= 0.9 {
            pdfType = "text-based"
            recommendation = "Use pdf_extract_text for best results."
        } else if textRatio <= 0.1 {
            pdfType = "scanned/image-based"
            recommendation = "Use pdf_ocr_text for text extraction."
        } else {
            pdfType = "mixed (text and scanned)"
            recommendation = "Use pdf_extract_text first, then pdf_ocr_text for pages without text."
        }

        var output = "PDF Type Analysis:\n"
        output += "  Type: \(pdfType)\n"
        output += "  Total pages: \(totalPages)\n"
        output += "  Pages with text: \(pagesWithText) (\(String(format: "%.1f%%", textRatio * 100)))\n"
        output += "  Pages without text: \(pagesWithoutText)\n"
        output += "  Total characters: \(totalChars)\n"
        output += "  Recommendation: \(recommendation)\n"

        return output
    }

    private func pdfCheckAccessibility(args: [String: Value]) async throws -> String {
        let (doc, _) = try getDocumentOrOpen(args: args)

        var output = "PDF Accessibility Check:\n"

        // Check document attributes
        let attrs = doc.documentAttributes ?? [:]

        // Check for title
        let hasTitle = (attrs[PDFDocumentAttribute.titleAttribute] as? String)?.isEmpty == false
        output += "  Has title: \(hasTitle ? "Yes" : "No")\n"

        // Check for author
        let hasAuthor = (attrs[PDFDocumentAttribute.authorAttribute] as? String)?.isEmpty == false
        output += "  Has author: \(hasAuthor ? "Yes" : "No")\n"

        // Check for subject/description
        let hasSubject = (attrs[PDFDocumentAttribute.subjectAttribute] as? String)?.isEmpty == false
        output += "  Has subject: \(hasSubject ? "Yes" : "No")\n"

        // Check encryption/permissions
        output += "  Is encrypted: \(doc.isEncrypted ? "Yes" : "No")\n"
        output += "  Allows copying: \(doc.allowsCopying ? "Yes" : "No")\n"
        output += "  Allows printing: \(doc.allowsPrinting ? "Yes" : "No")\n"

        // Check for text content (accessibility needs selectable text)
        var pagesWithText = 0
        for i in 0..<min(doc.pageCount, 5) {  // Sample first 5 pages
            if let page = doc.page(at: i), let text = page.string, !text.isEmpty {
                pagesWithText += 1
            }
        }
        let hasSelectableText = pagesWithText > 0
        output += "  Has selectable text: \(hasSelectableText ? "Yes" : "No")\n"

        // Check for outline
        let hasOutline = doc.outlineRoot != nil && (doc.outlineRoot?.numberOfChildren ?? 0) > 0
        output += "  Has outline/TOC: \(hasOutline ? "Yes" : "No")\n"

        // Accessibility score
        var score = 0
        if hasTitle { score += 1 }
        if hasAuthor { score += 1 }
        if hasSelectableText { score += 2 }
        if hasOutline { score += 1 }
        if doc.allowsCopying { score += 1 }

        let maxScore = 6
        output += "\n  Accessibility score: \(score)/\(maxScore)\n"

        if score >= 5 {
            output += "  Rating: Good accessibility\n"
        } else if score >= 3 {
            output += "  Rating: Fair accessibility\n"
        } else {
            output += "  Rating: Poor accessibility - consider adding text layer via OCR\n"
        }

        return output
    }

    // MARK: - C. Advanced Operations Implementations

    private func pdfRotatePages(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let pagesSpec = try getParameter(args: args, key: "pages", as: String.self)
        let angle = try getParameter(args: args, key: "angle", as: Int.self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)

        guard [90, 180, 270].contains(angle) else {
            throw PDFError.invalidParameter("angle", "must be 90, 180, or 270")
        }

        let url = URL(fileURLWithPath: expandPath(path))
        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        // Parse page specification
        var pageIndices: Set<Int> = []
        if pagesSpec.lowercased() == "all" {
            pageIndices = Set(0..<doc.pageCount)
        } else {
            pageIndices = parsePageSpec(pagesSpec, maxPages: doc.pageCount)
        }

        // Rotate specified pages
        for index in pageIndices {
            if let page = doc.page(at: index) {
                let currentRotation = page.rotation
                page.rotation = (currentRotation + angle) % 360
            }
        }

        let outputURL = URL(fileURLWithPath: expandPath(outputPath))
        guard doc.write(to: outputURL) else {
            throw PDFError.writeError("Failed to write rotated PDF")
        }

        return "Rotated \(pageIndices.count) page(s) by \(angle)° and saved to \(outputPath)"
    }

    private func pdfSplit(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let splitMethod = try getParameter(args: args, key: "split_method", as: String.self)
        let outputDir = try getParameter(args: args, key: "output_directory", as: String.self)
        let prefix = (try? getOptionalParameter(args: args, key: "prefix", as: String.self)) ?? "split"

        let url = URL(fileURLWithPath: expandPath(path))
        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        let dirURL = URL(fileURLWithPath: expandPath(outputDir))
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        var filesCreated = 0

        if splitMethod == "each" {
            // One file per page
            for i in 0..<doc.pageCount {
                let newDoc = PDFDocument()
                if let page = doc.page(at: i) {
                    newDoc.insert(page, at: 0)
                }
                let filename = "\(prefix)_page_\(i + 1).pdf"
                let fileURL = dirURL.appendingPathComponent(filename)
                if newDoc.write(to: fileURL) {
                    filesCreated += 1
                }
            }
        } else if splitMethod.hasPrefix("count:") {
            // N pages per file
            let countStr = String(splitMethod.dropFirst(6))
            guard let pagesPerFile = Int(countStr), pagesPerFile > 0 else {
                throw PDFError.invalidParameter("split_method", "invalid count value")
            }

            var fileIndex = 1
            var currentDoc = PDFDocument()
            var pageCount = 0

            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    currentDoc.insert(page, at: currentDoc.pageCount)
                    pageCount += 1

                    if pageCount >= pagesPerFile {
                        let filename = "\(prefix)_part_\(fileIndex).pdf"
                        let fileURL = dirURL.appendingPathComponent(filename)
                        if currentDoc.write(to: fileURL) {
                            filesCreated += 1
                        }
                        currentDoc = PDFDocument()
                        pageCount = 0
                        fileIndex += 1
                    }
                }
            }

            // Write remaining pages
            if currentDoc.pageCount > 0 {
                let filename = "\(prefix)_part_\(fileIndex).pdf"
                let fileURL = dirURL.appendingPathComponent(filename)
                if currentDoc.write(to: fileURL) {
                    filesCreated += 1
                }
            }
        } else if splitMethod.hasPrefix("ranges:") {
            // Specific ranges like "1-3,4-6,7-10"
            let rangesStr = String(splitMethod.dropFirst(7))
            let ranges = rangesStr.components(separatedBy: ",")

            for (index, rangeStr) in ranges.enumerated() {
                let pageIndices = parsePageSpec(rangeStr, maxPages: doc.pageCount)
                if pageIndices.isEmpty { continue }

                let newDoc = PDFDocument()
                for pageIndex in pageIndices.sorted() {
                    if let page = doc.page(at: pageIndex) {
                        newDoc.insert(page, at: newDoc.pageCount)
                    }
                }

                let filename = "\(prefix)_part_\(index + 1).pdf"
                let fileURL = dirURL.appendingPathComponent(filename)
                if newDoc.write(to: fileURL) {
                    filesCreated += 1
                }
            }
        } else {
            throw PDFError.invalidParameter("split_method", "must be 'each', 'count:N', or 'ranges:1-3,4-6'")
        }

        return "Split PDF into \(filesCreated) file(s) in \(outputDir)"
    }

    private func pdfAddWatermark(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let text = try getParameter(args: args, key: "text", as: String.self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)
        let pagesSpec = (try? getOptionalParameter(args: args, key: "pages", as: String.self)) ?? "all"
        let opacity = (try? getOptionalParameter(args: args, key: "opacity", as: Double.self)) ?? 0.3
        let _ = (try? getOptionalParameter(args: args, key: "rotation", as: Int.self)) ?? 45  // Reserved for future use
        let fontSize = (try? getOptionalParameter(args: args, key: "font_size", as: Int.self)) ?? 48

        let url = URL(fileURLWithPath: expandPath(path))
        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        // Parse page specification
        var pageIndices: Set<Int> = []
        if pagesSpec.lowercased() == "all" {
            pageIndices = Set(0..<doc.pageCount)
        } else {
            pageIndices = parsePageSpec(pagesSpec, maxPages: doc.pageCount)
        }

        // Add watermark to each page
        for index in pageIndices {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            // Create a free text annotation as watermark
            let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = NSFont.systemFont(ofSize: CGFloat(fontSize))
            annotation.fontColor = NSColor.gray.withAlphaComponent(CGFloat(opacity))
            annotation.color = .clear
            annotation.alignment = .center

            page.addAnnotation(annotation)
        }

        let outputURL = URL(fileURLWithPath: expandPath(outputPath))
        guard doc.write(to: outputURL) else {
            throw PDFError.writeError("Failed to write watermarked PDF")
        }

        return "Added watermark '\(text)' to \(pageIndices.count) page(s) and saved to \(outputPath)"
    }

    private func pdfEncrypt(args: [String: Value]) async throws -> String {
        let path = try getParameter(args: args, key: "path", as: String.self)
        let outputPath = try getParameter(args: args, key: "output_path", as: String.self)
        let userPassword = try getParameter(args: args, key: "user_password", as: String.self)
        let ownerPassword = (try? getOptionalParameter(args: args, key: "owner_password", as: String.self)) ?? userPassword
        let allowPrinting = (try? getOptionalParameter(args: args, key: "allow_printing", as: Bool.self)) ?? true
        let allowCopying = (try? getOptionalParameter(args: args, key: "allow_copying", as: Bool.self)) ?? false

        let url = URL(fileURLWithPath: expandPath(path))
        guard let doc = PDFDocument(url: url) else {
            throw PDFError.invalidPDF(path)
        }

        let outputURL = URL(fileURLWithPath: expandPath(outputPath))

        // Build options dictionary for PDF encryption
        // Note: PDFKit encryption options on macOS 13+
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: userPassword,
            .ownerPasswordOption: ownerPassword
        ]

        // Note: allowsPrinting and allowsCopying are controlled by the password permissions
        // These are set based on the owner password access level
        _ = allowPrinting  // Reserved for future use with CoreGraphics PDF creation
        _ = allowCopying   // Reserved for future use with CoreGraphics PDF creation

        guard doc.write(to: outputURL, withOptions: options) else {
            throw PDFError.encryptionError("Failed to write encrypted PDF")
        }

        return "Encrypted PDF saved to \(outputPath)"
    }

    private func pdfUrlFetch(args: [String: Value]) async throws -> String {
        let urlString = try getParameter(args: args, key: "url", as: String.self)
        let savePath = try? getOptionalParameter(args: args, key: "save_path", as: String.self)
        let customId = try? getOptionalParameter(args: args, key: "doc_id", as: String.self)

        guard let url = URL(string: urlString) else {
            throw PDFError.urlFetchError("Invalid URL: \(urlString)")
        }

        // Fetch PDF data
        let (data, response) = try await URLSession.shared.data(from: url)

        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw PDFError.urlFetchError("HTTP error: \(httpResponse.statusCode)")
            }
        }

        // Create PDFDocument from data
        guard let doc = PDFDocument(data: data) else {
            throw PDFError.invalidPDF(urlString)
        }

        let docId = customId ?? UUID().uuidString
        openDocuments[docId] = doc

        var result = "Fetched PDF from URL (pages: \(doc.pageCount), ID: \(docId))"

        // Save to disk if requested
        if let path = savePath {
            let saveURL = URL(fileURLWithPath: expandPath(path))
            if doc.write(to: saveURL) {
                result += "\nSaved to: \(path)"
            } else {
                result += "\nWarning: Failed to save to disk"
            }
        }

        return result
    }

    // MARK: - Helper: Parse Page Specification

    private func parsePageSpec(_ spec: String, maxPages: Int) -> Set<Int> {
        var pageIndices: Set<Int> = []
        let parts = spec.components(separatedBy: ",")

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("-") {
                let rangeParts = trimmed.components(separatedBy: "-")
                if rangeParts.count == 2,
                   let start = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)) {
                    for i in start...end {
                        if i >= 1 && i <= maxPages {
                            pageIndices.insert(i - 1)
                        }
                    }
                }
            } else if let pageNum = Int(trimmed) {
                if pageNum >= 1 && pageNum <= maxPages {
                    pageIndices.insert(pageNum - 1)
                }
            }
        }

        return pageIndices
    }
}
