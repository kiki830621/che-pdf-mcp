import Foundation

enum PDFError: Error, LocalizedError {
    case documentNotOpen(String)
    case documentAlreadyOpen(String)
    case fileNotFound(String)
    case invalidPDF(String)
    case readError(String)
    case writeError(String)
    case renderFailed
    case ocrFailed(String)
    case invalidPageRange(String)
    case accessDenied(String)
    case hostNotAllowed(String)
    case unknownTool(String)
    case missingParameter(String)
    case invalidParameter(String, String)
    case mergeError(String)
    case encryptionError(String)
    case urlFetchError(String)

    var errorDescription: String? {
        switch self {
        case .documentNotOpen(let id):
            return "Document not open: \(id)"
        case .documentAlreadyOpen(let id):
            return "Document already open: \(id)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidPDF(let path):
            return "Invalid PDF file: \(path)"
        case .readError(let message):
            return "Read error: \(message)"
        case .writeError(let message):
            return "Write error: \(message)"
        case .renderFailed:
            return "Failed to render PDF page to image"
        case .ocrFailed(let message):
            return "OCR failed: \(message)"
        case .invalidPageRange(let range):
            return "Invalid page range: \(range)"
        case .accessDenied(let path):
            return "Access denied: \(path)"
        case .hostNotAllowed(let host):
            return "Host not allowed: \(host)"
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .missingParameter(let name):
            return "Missing required parameter: \(name)"
        case .invalidParameter(let name, let reason):
            return "Invalid parameter '\(name)': \(reason)"
        case .mergeError(let message):
            return "Merge error: \(message)"
        case .encryptionError(let message):
            return "Encryption error: \(message)"
        case .urlFetchError(let message):
            return "URL fetch error: \(message)"
        }
    }
}
