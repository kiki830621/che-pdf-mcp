import Foundation
import Vision
import PDFKit
import AppKit

// MARK: - Vision OCR Helper

struct VisionOCR {

    // MARK: - OCR Text Result

    struct TextBlock {
        let text: String
        let bounds: CGRect
        let confidence: Float
    }

    // MARK: - Perform OCR on a PDF Page

    static func performOCR(
        on page: PDFPage,
        languages: [String] = ["en-US"],
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    ) async throws -> String {
        let cgImage = try renderPageToImage(page: page)
        return try await recognizeText(from: cgImage, languages: languages, level: recognitionLevel)
    }

    // MARK: - Perform OCR with Layout Information

    static func performOCRWithLayout(
        on page: PDFPage,
        languages: [String] = ["en-US"],
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    ) async throws -> [TextBlock] {
        let cgImage = try renderPageToImage(page: page)
        return try await recognizeTextWithLayout(from: cgImage, languages: languages, level: recognitionLevel)
    }

    // MARK: - Render PDF Page to CGImage

    private static func renderPageToImage(page: PDFPage, dpi: CGFloat = 300) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)

        // Calculate size based on DPI
        let scale = dpi / 72.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)

        // Create a bitmap context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw PDFError.renderFailed
        }

        guard let context = CGContext(
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

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Scale and render
        context.scaleBy(x: scale, y: scale)

        // Get CGPDFPage and draw
        guard let pageRef = page.pageRef else {
            throw PDFError.renderFailed
        }

        context.drawPDFPage(pageRef)

        // Create CGImage
        guard let cgImage = context.makeImage() else {
            throw PDFError.renderFailed
        }

        return cgImage
    }

    // MARK: - Recognize Text

    private static func recognizeText(
        from image: CGImage,
        languages: [String],
        level: VNRequestTextRecognitionLevel
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: PDFError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = level
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: PDFError.ocrFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Recognize Text with Layout

    private static func recognizeTextWithLayout(
        from image: CGImage,
        languages: [String],
        level: VNRequestTextRecognitionLevel
    ) async throws -> [TextBlock] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: PDFError.ocrFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let blocks = observations.compactMap { observation -> TextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }

                    // Convert normalized coordinates to image coordinates
                    let bounds = CGRect(
                        x: observation.boundingBox.origin.x * CGFloat(image.width),
                        y: observation.boundingBox.origin.y * CGFloat(image.height),
                        width: observation.boundingBox.width * CGFloat(image.width),
                        height: observation.boundingBox.height * CGFloat(image.height)
                    )

                    return TextBlock(
                        text: candidate.string,
                        bounds: bounds,
                        confidence: candidate.confidence
                    )
                }

                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = level
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: PDFError.ocrFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Get Supported Languages

    static func supportedLanguages() -> [String] {
        // Return common supported languages for macOS 13+
        return [
            "en-US", "en-GB", "en-AU", "en-CA",
            "zh-Hant", "zh-Hans",
            "ja", "ko",
            "fr", "de", "es", "it", "pt-BR", "pt-PT",
            "ru", "uk", "pl", "nl", "sv", "da", "no", "fi"
        ]
    }
}
