import Foundation
import MCP
import PDFKit

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
            )
        ]
    }

    // MARK: - Tool Call Handler

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        let name = params.name
        let args = params.arguments ?? [:]

        do {
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
}
