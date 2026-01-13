import Foundation
import PDFKit

// MARK: - Markdown Exporter

struct MarkdownExporter {

    // MARK: - Export Options

    struct Options {
        var includePageBreaks: Bool = true
        var includeHeaders: Bool = true
        var headerLevel: Int = 1  // 1 = #, 2 = ##, etc.
        var includeMetadata: Bool = true
        var imagePlaceholder: Bool = true  // Add [Image] placeholders

        static let `default` = Options()
    }

    // MARK: - Export PDF to Markdown

    static func export(document: PDFDocument, options: Options = .default) -> String {
        var markdown = ""

        // Add metadata header if requested
        if options.includeMetadata {
            markdown += generateMetadataHeader(document: document, options: options)
        }

        // Process each page
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }

            // Add page header
            if options.includeHeaders {
                let headerPrefix = String(repeating: "#", count: options.headerLevel + 1)
                markdown += "\n\(headerPrefix) Page \(i + 1)\n\n"
            }

            // Extract and process text
            if let pageText = page.string {
                let processedText = processText(pageText)
                markdown += processedText
                markdown += "\n"
            }

            // Add page break marker
            if options.includePageBreaks && i < document.pageCount - 1 {
                markdown += "\n---\n"
            }
        }

        return markdown
    }

    // MARK: - Export Single Page

    static func exportPage(page: PDFPage, pageNumber: Int, options: Options = .default) -> String {
        var markdown = ""

        // Add page header
        if options.includeHeaders {
            let headerPrefix = String(repeating: "#", count: options.headerLevel)
            markdown += "\(headerPrefix) Page \(pageNumber)\n\n"
        }

        // Extract and process text
        if let pageText = page.string {
            let processedText = processText(pageText)
            markdown += processedText
        }

        return markdown
    }

    // MARK: - Generate Metadata Header

    private static func generateMetadataHeader(document: PDFDocument, options: Options) -> String {
        var header = "---\n"

        if let attrs = document.documentAttributes {
            if let title = attrs[PDFDocumentAttribute.titleAttribute] as? String, !title.isEmpty {
                header += "title: \"\(escapeYAML(title))\"\n"
            }
            if let author = attrs[PDFDocumentAttribute.authorAttribute] as? String, !author.isEmpty {
                header += "author: \"\(escapeYAML(author))\"\n"
            }
            if let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String, !subject.isEmpty {
                header += "subject: \"\(escapeYAML(subject))\"\n"
            }
            if let creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date {
                header += "date: \"\(ISO8601DateFormatter().string(from: creationDate))\"\n"
            }
        }

        header += "pages: \(document.pageCount)\n"
        header += "---\n\n"

        return header
    }

    // MARK: - Text Processing

    private static func processText(_ text: String) -> String {
        var processed = text

        // Normalize line breaks
        processed = processed.replacingOccurrences(of: "\r\n", with: "\n")
        processed = processed.replacingOccurrences(of: "\r", with: "\n")

        // Convert multiple blank lines to double newline
        let multipleNewlinePattern = try? NSRegularExpression(pattern: "\n{3,}", options: [])
        if let regex = multipleNewlinePattern {
            processed = regex.stringByReplacingMatches(
                in: processed,
                options: [],
                range: NSRange(processed.startIndex..., in: processed),
                withTemplate: "\n\n"
            )
        }

        // Detect and format potential headers (lines in ALL CAPS with few words)
        processed = detectAndFormatHeaders(processed)

        // Detect and format bullet points
        processed = formatBulletPoints(processed)

        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Header Detection

    private static func detectAndFormatHeaders(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if line looks like a header:
            // - All uppercase
            // - Relatively short (< 60 chars)
            // - More than 2 characters
            // - No sentence-ending punctuation
            if trimmed.count > 2 && trimmed.count < 60 &&
               trimmed == trimmed.uppercased() &&
               !trimmed.hasSuffix(".") &&
               trimmed.contains(" ") {
                result.append("\n### \(titleCase(trimmed))\n")
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Bullet Point Detection

    private static func formatBulletPoints(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for common bullet patterns
            if trimmed.hasPrefix("• ") ||
               trimmed.hasPrefix("● ") ||
               trimmed.hasPrefix("○ ") ||
               trimmed.hasPrefix("◦ ") ||
               trimmed.hasPrefix("▪ ") ||
               trimmed.hasPrefix("▸ ") {
                // Convert to markdown bullet
                let content = String(trimmed.dropFirst(2))
                result.append("- \(content)")
            } else if let firstChar = trimmed.first,
                      (firstChar == "-" || firstChar == "*") && trimmed.count > 2,
                      trimmed[trimmed.index(after: trimmed.startIndex)] == " " {
                // Already looks like a bullet point
                result.append(line)
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func titleCase(_ text: String) -> String {
        text.lowercased().capitalized
    }

    private static func escapeYAML(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
