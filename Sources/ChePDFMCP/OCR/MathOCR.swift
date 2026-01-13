import Foundation
import Vision
import PDFKit
import AppKit

// MARK: - Math OCR with Spatial Analysis (Enhanced)

struct MathOCR {

    // MARK: - Character Element (for character-level analysis)

    struct CharElement {
        let char: String
        let bounds: CGRect
        let confidence: Float
        let baselineY: CGFloat  // Estimated baseline position
    }

    // MARK: - Text Block (for internal use)

    struct TextBlock {
        let text: String
        let bounds: CGRect
        let confidence: Float
        let characters: [CharElement]  // Character-level breakdown
    }

    // MARK: - Math Element Types

    enum MathElementType: String {
        case normal       = "txt"
        case subScript    = "sub"
        case superScript  = "sup"
        case fraction     = "frac"
        case matrix       = "mat"
        case symbol       = "sym"
        case transpose    = "trans"
    }

    // MARK: - Math Element

    struct MathElement {
        let text: String
        let bounds: CGRect
        let confidence: Float
        let type: MathElementType
        let fontSize: CGFloat
    }

    // MARK: - Math Region

    struct MathRegion {
        let elements: [MathElement]
        let bounds: CGRect
        let latex: String
        let rawText: String
        let confidence: Float
    }

    // MARK: - OCR Result

    struct MathOCRResult {
        let pageNumber: Int
        let regions: [MathRegion]
        let fullLatex: String
        let plainText: String
        let reconstructedLatex: String  // Post-processed with pattern matching
        let hasMathContent: Bool
        let detectedPatterns: [String]  // Detected math patterns
    }

    // MARK: - Greek Letter Mapping

    private static let greekLetters: [String: String] = [
        "α": "\\alpha", "β": "\\beta", "γ": "\\gamma", "δ": "\\delta",
        "ε": "\\epsilon", "ζ": "\\zeta", "η": "\\eta", "θ": "\\theta",
        "ι": "\\iota", "κ": "\\kappa", "λ": "\\lambda", "μ": "\\mu",
        "ν": "\\nu", "ξ": "\\xi", "π": "\\pi", "ρ": "\\rho",
        "σ": "\\sigma", "τ": "\\tau", "υ": "\\upsilon", "φ": "\\phi",
        "χ": "\\chi", "ψ": "\\psi", "ω": "\\omega",
        "Γ": "\\Gamma", "Δ": "\\Delta", "Θ": "\\Theta",
        "Λ": "\\Lambda", "Ξ": "\\Xi", "Π": "\\Pi",
        "Σ": "\\Sigma", "Υ": "\\Upsilon", "Φ": "\\Phi",
        "Ψ": "\\Psi", "Ω": "\\Omega"
    ]

    // MARK: - Math Symbol Mapping

    private static let mathSymbols: [String: String] = [
        "∑": "\\sum", "∏": "\\prod", "∫": "\\int",
        "√": "\\sqrt", "∞": "\\infty", "≠": "\\neq",
        "≤": "\\leq", "≥": "\\geq", "≈": "\\approx",
        "±": "\\pm", "∓": "\\mp", "×": "\\times", "÷": "\\div",
        "→": "\\rightarrow", "←": "\\leftarrow", "↔": "\\leftrightarrow",
        "⇒": "\\Rightarrow", "⇐": "\\Leftarrow", "⇔": "\\Leftrightarrow",
        "∈": "\\in", "∉": "\\notin", "⊂": "\\subset", "⊆": "\\subseteq",
        "⊃": "\\supset", "⊇": "\\supseteq", "∪": "\\cup", "∩": "\\cap",
        "∧": "\\land", "∨": "\\lor", "¬": "\\neg",
        "∀": "\\forall", "∃": "\\exists", "∂": "\\partial",
        "∇": "\\nabla", "′": "'", "″": "''",
        "°": "^{\\circ}", "·": "\\cdot", "…": "\\ldots",
        "⋯": "\\cdots", "⋮": "\\vdots", "⋱": "\\ddots",
        "ℕ": "\\mathbb{N}", "ℤ": "\\mathbb{Z}", "ℚ": "\\mathbb{Q}",
        "ℝ": "\\mathbb{R}", "ℂ": "\\mathbb{C}"
    ]

    // MARK: - Pattern Loading (from YAML file or built-in)

    private static var _cachedPatterns: [MathPatternLoader.MathPattern]?

    private static var loadedPatterns: [MathPatternLoader.MathPattern] {
        if let cached = _cachedPatterns {
            return cached
        }
        let patterns = MathPatternLoader.loadPatterns()
        _cachedPatterns = patterns
        return patterns
    }

    // MARK: - Get Pattern Info (for debugging/output)

    static func getPatternInfo() -> (total: Int, fromFile: Bool, domains: [String: Int]) {
        return MathPatternLoader.getPatternInfo()
    }

    // MARK: - Perform Math OCR on a PDF Page

    static func performMathOCR(
        on page: PDFPage,
        pageNumber: Int,
        languages: [String] = ["en-US"]
    ) async throws -> MathOCRResult {
        // Render page to image at high DPI for better recognition
        let cgImage = try renderPageToImage(page: page, dpi: 300)

        // Get text blocks with character-level layout information
        let textBlocks = try await recognizeTextWithCharacters(
            from: cgImage,
            languages: languages
        )

        // Analyze spatial relationships and classify elements
        let mathElements = classifyElementsEnhanced(textBlocks, imageHeight: CGFloat(cgImage.height))

        // Detect math regions (clusters of math-related content)
        let mathRegions = detectMathRegions(mathElements)

        // Generate LaTeX for each region
        var regionsWithLatex: [MathRegion] = []
        for region in mathRegions {
            let latex = generateLatex(for: region.elements)
            let rawText = region.elements.map { $0.text }.joined(separator: " ")
            let avgConfidence = region.elements.map { $0.confidence }.reduce(0, +) / Float(max(region.elements.count, 1))
            regionsWithLatex.append(MathRegion(
                elements: region.elements,
                bounds: region.bounds,
                latex: latex,
                rawText: rawText,
                confidence: avgConfidence
            ))
        }

        // Generate full output
        let fullLatex = regionsWithLatex.map { $0.latex }.joined(separator: "\n\n")
        let plainText = mathElements.map { $0.text }.joined(separator: " ")

        // Post-process with pattern matching
        let (reconstructedLatex, detectedPatterns) = postProcessWithPatterns(plainText)

        let hasMathContent = mathElements.contains { $0.type != .normal } || !detectedPatterns.isEmpty

        return MathOCRResult(
            pageNumber: pageNumber,
            regions: regionsWithLatex,
            fullLatex: fullLatex,
            plainText: plainText,
            reconstructedLatex: reconstructedLatex,
            hasMathContent: hasMathContent,
            detectedPatterns: detectedPatterns
        )
    }

    // MARK: - Render PDF Page to CGImage

    private static func renderPageToImage(page: PDFPage, dpi: CGFloat) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)

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

        return cgImage
    }

    // MARK: - Recognize Text with Character-Level Layout

    private static func recognizeTextWithCharacters(
        from image: CGImage,
        languages: [String]
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

                var blocks: [TextBlock] = []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string

                    // Get block-level bounds
                    let blockBounds = CGRect(
                        x: observation.boundingBox.origin.x * CGFloat(image.width),
                        y: observation.boundingBox.origin.y * CGFloat(image.height),
                        width: observation.boundingBox.width * CGFloat(image.width),
                        height: observation.boundingBox.height * CGFloat(image.height)
                    )

                    // Try to get character-level bounds
                    var characters: [CharElement] = []
                    let fullRange = text.startIndex..<text.endIndex

                    if (try? candidate.boundingBox(for: fullRange)) != nil {
                        // Estimate character positions by dividing the box
                        let charWidth = blockBounds.width / CGFloat(max(text.count, 1))
                        var xOffset: CGFloat = 0

                        for char in text {
                            let charBounds = CGRect(
                                x: blockBounds.minX + xOffset,
                                y: blockBounds.minY,
                                width: charWidth,
                                height: blockBounds.height
                            )

                            // Estimate baseline (typically ~20% from bottom)
                            let baselineY = charBounds.minY + charBounds.height * 0.2

                            characters.append(CharElement(
                                char: String(char),
                                bounds: charBounds,
                                confidence: candidate.confidence,
                                baselineY: baselineY
                            ))

                            xOffset += charWidth
                        }
                    }

                    blocks.append(TextBlock(
                        text: text,
                        bounds: blockBounds,
                        confidence: candidate.confidence,
                        characters: characters
                    ))
                }

                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = false  // Disable for math

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: PDFError.ocrFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Enhanced Element Classification

    private static func classifyElementsEnhanced(_ blocks: [TextBlock], imageHeight: CGFloat) -> [MathElement] {
        guard !blocks.isEmpty else { return [] }

        // Sort blocks by position (top to bottom, left to right)
        let sortedBlocks = blocks.sorted { b1, b2 in
            if abs(b1.bounds.midY - b2.bounds.midY) > 20 {
                return b1.bounds.midY > b2.bounds.midY
            }
            return b1.bounds.minX < b2.bounds.minX
        }

        // Calculate statistics for classification
        let heights = sortedBlocks.map { $0.bounds.height }.sorted()
        let medianHeight = heights[heights.count / 2]
        // Reserved for future adaptive thresholding
        let _ = heights.reduce(0, +) / CGFloat(heights.count)  // avgHeight

        var elements: [MathElement] = []

        for (index, block) in sortedBlocks.enumerated() {
            let fontSize = block.bounds.height
            var elementType: MathElementType = .normal

            // 1. Check for mathematical symbols
            if containsMathSymbol(block.text) || containsGreekLetter(block.text) {
                elementType = .symbol
            }
            // 2. Check for transpose notation (prime/apostrophe)
            else if block.text.contains("'") || block.text.contains("'") || block.text.contains("′") {
                elementType = .transpose
            }
            // 3. Check for subscript/superscript based on size
            else if fontSize < medianHeight * 0.7 {
                // Significantly smaller - likely sub/superscript
                if let baseElement = findBaseElementEnhanced(for: block, in: sortedBlocks, beforeIndex: index, medianHeight: medianHeight) {
                    let baseMidY = baseElement.bounds.midY
                    let baseBottom = baseElement.bounds.minY
                    let baseTop = baseElement.bounds.maxY
                    let blockMidY = block.bounds.midY
                    let blockBottom = block.bounds.minY
                    let blockTop = block.bounds.maxY

                    // Subscript: block is positioned lower
                    if blockTop < baseMidY || blockMidY < baseBottom + medianHeight * 0.3 {
                        elementType = .subScript
                    }
                    // Superscript: block is positioned higher
                    else if blockBottom > baseMidY || blockMidY > baseTop - medianHeight * 0.3 {
                        elementType = .superScript
                    }
                }
            }
            // 4. Check text patterns for inline subscripts/superscripts
            else {
                let patterns = detectInlinePatterns(block.text)
                if !patterns.isEmpty {
                    elementType = .symbol  // Contains math patterns
                }
            }

            elements.append(MathElement(
                text: block.text,
                bounds: block.bounds,
                confidence: block.confidence,
                type: elementType,
                fontSize: fontSize
            ))
        }

        return elements
    }

    // MARK: - Enhanced Base Element Finding

    private static func findBaseElementEnhanced(
        for block: TextBlock,
        in blocks: [TextBlock],
        beforeIndex: Int,
        medianHeight: CGFloat
    ) -> TextBlock? {
        var bestCandidate: TextBlock?
        var minDistance: CGFloat = .infinity

        for i in stride(from: beforeIndex - 1, through: max(0, beforeIndex - 5), by: -1) {
            let candidate = blocks[i]

            // Must be normal sized
            guard candidate.bounds.height >= medianHeight * 0.6 else { continue }

            // Calculate horizontal distance
            let horizontalDistance = block.bounds.minX - candidate.bounds.maxX

            // Must be to the left and reasonably close
            if horizontalDistance >= -5 && horizontalDistance < medianHeight * 1.5 {
                // Prefer the closest one
                if horizontalDistance < minDistance {
                    minDistance = horizontalDistance
                    bestCandidate = candidate
                }
            }
        }

        return bestCandidate
    }

    // MARK: - Detect Inline Patterns

    private static func detectInlinePatterns(_ text: String) -> [String] {
        var patterns: [String] = []

        // Variable with number: X1, X2, β0, σ2
        let varNumPattern = try? NSRegularExpression(pattern: "[A-Za-zαβγδεθλμσφω][0-9]+", options: [])
        if let matches = varNumPattern?.numberOfMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text)), matches > 0 {
            patterns.append("var_subscript")
        }

        // Transpose: X', Y'
        if text.contains("'") || text.contains("'") {
            patterns.append("transpose")
        }

        // Fraction-like: a/b
        if text.contains("/") && text.count > 1 {
            patterns.append("fraction")
        }

        // Power notation: x^2, e^x
        if text.contains("^") {
            patterns.append("power")
        }

        return patterns
    }

    // MARK: - Detect Math Regions

    private static func detectMathRegions(_ elements: [MathElement]) -> [(elements: [MathElement], bounds: CGRect)] {
        guard !elements.isEmpty else { return [] }

        var lines: [[MathElement]] = []
        var currentLine: [MathElement] = []
        var lastY: CGFloat = elements.first?.bounds.midY ?? 0

        for element in elements {
            let yDiff = abs(element.bounds.midY - lastY)

            if yDiff > element.fontSize * 1.5 && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = [element]
            } else {
                currentLine.append(element)
            }
            lastY = element.bounds.midY
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        var regions: [(elements: [MathElement], bounds: CGRect)] = []

        for line in lines {
            guard !line.isEmpty else { continue }

            let minX = line.map { $0.bounds.minX }.min() ?? 0
            let minY = line.map { $0.bounds.minY }.min() ?? 0
            let maxX = line.map { $0.bounds.maxX }.max() ?? 0
            let maxY = line.map { $0.bounds.maxY }.max() ?? 0

            let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            regions.append((elements: line, bounds: bounds))
        }

        return regions
    }

    // MARK: - Generate LaTeX

    private static func generateLatex(for elements: [MathElement]) -> String {
        guard !elements.isEmpty else { return "" }

        var latex = ""

        for (i, element) in elements.enumerated() {
            let text = element.text

            switch element.type {
            case .subScript:
                latex += "_{" + convertToLatex(text) + "}"

            case .superScript:
                latex += "^{" + convertToLatex(text) + "}"

            case .transpose:
                latex += convertToLatex(text)

            case .symbol:
                latex += convertToLatex(text)

            case .normal, .fraction, .matrix:
                latex += convertToLatex(text)
            }

            // Add space between normal elements
            if i < elements.count - 1 {
                let next = elements[i + 1]
                if next.type == .normal && element.type == .normal {
                    latex += " "
                }
            }
        }

        return latex.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Post-Process with Pattern Matching

    private static func postProcessWithPatterns(_ text: String) -> (String, [String]) {
        var result = text
        var detectedPatterns: [String] = []
        var appliedPatternCount: [String: Int] = [:]  // Track by domain

        // Use patterns from YAML file (sorted by priority)
        for mathPattern in loadedPatterns {
            guard let regex = try? NSRegularExpression(pattern: mathPattern.pattern, options: []) else { continue }

            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.numberOfMatches(in: result, options: [], range: range)

            if matches > 0 {
                let desc = mathPattern.description.isEmpty ? mathPattern.pattern : mathPattern.description
                detectedPatterns.append("[\(mathPattern.domain)] \(desc) (\(matches)x)")
                appliedPatternCount[mathPattern.domain, default: 0] += matches
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: mathPattern.replacement)
            }
        }

        // Additional cleanup
        result = cleanupLatex(result)

        return (result, detectedPatterns)
    }

    // MARK: - Cleanup LaTeX

    private static func cleanupLatex(_ text: String) -> String {
        var result = text

        // Fix common OCR errors in math
        let replacements = [
            ("X{", "X'"),      // OCR sometimes reads ' as {
            ("Y{", "Y'"),
            ("≥", "\\geq "),   // Greater or equal
            ("≤", "\\leq "),   // Less or equal
            ("ı", "1"),        // Turkish i → 1
            ("ı", "i"),        // Or Greek iota
            ("Х", "X"),        // Cyrillic → Latin
            ("У", "Y"),
            ("М", "M"),
            ("  ", " "),       // Double spaces
        ]

        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }

        return result
    }

    // MARK: - Convert Text to LaTeX

    private static func convertToLatex(_ text: String) -> String {
        var result = text

        // Replace Greek letters
        for (greek, latex) in greekLetters {
            result = result.replacingOccurrences(of: greek, with: latex + " ")
        }

        // Replace math symbols
        for (symbol, latex) in mathSymbols {
            result = result.replacingOccurrences(of: symbol, with: latex + " ")
        }

        // Normalize apostrophes for transpose
        result = result.replacingOccurrences(of: "'", with: "'")
        result = result.replacingOccurrences(of: "′", with: "'")

        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Helper Functions

    private static func containsMathSymbol(_ text: String) -> Bool {
        for symbol in mathSymbols.keys {
            if text.contains(symbol) { return true }
        }
        return false
    }

    private static func containsGreekLetter(_ text: String) -> Bool {
        for letter in greekLetters.keys {
            if text.contains(letter) { return true }
        }
        return false
    }

    // MARK: - Detect if Page Likely Contains Math

    static func detectMathContent(in text: String) -> Bool {
        let mathIndicators = [
            "=", "+", "-", "×", "÷", "±",
            "∑", "∏", "∫", "√",
            "α", "β", "γ", "δ", "θ", "σ", "μ", "λ",
            "matrix", "equation", "formula",
            "X'", "Y'", "regression", "coefficient"
        ]

        var indicatorCount = 0
        for indicator in mathIndicators {
            if text.contains(indicator) { indicatorCount += 1 }
        }

        let subscriptPattern = try? NSRegularExpression(pattern: "[A-Za-z][0-9]", options: [])
        let subscriptMatches = subscriptPattern?.numberOfMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text)
        ) ?? 0

        return indicatorCount >= 2 || subscriptMatches >= 3
    }
}
