import Foundation

// MARK: - Math Pattern Loader
// 從 YAML 檔案載入數學模式，無需外部依賴

struct MathPatternLoader {

    // MARK: - Math Pattern Definition

    struct MathPattern: Comparable {
        let pattern: String
        let replacement: String
        let priority: Int
        let description: String
        let domain: String

        static func < (lhs: MathPattern, rhs: MathPattern) -> Bool {
            lhs.priority < rhs.priority
        }
    }

    // MARK: - Load Patterns from YAML

    static func loadPatterns() -> [MathPattern] {
        // Try to load from file first
        if let patterns = loadFromFile() {
            return patterns.sorted()
        }

        // Fall back to built-in patterns
        return builtInPatterns.sorted()
    }

    // MARK: - Load from File

    private static func loadFromFile() -> [MathPattern]? {
        // Build search paths for the YAML file
        var searchPaths: [String] = []

        // Same directory as executable
        if let execPath = Bundle.main.executablePath {
            let execDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
            searchPaths.append(execDir.appendingPathComponent("Resources/math_patterns.yaml").path)
            searchPaths.append(execDir.appendingPathComponent("math_patterns.yaml").path)
        }

        // User config directory
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/che-pdf-mcp/math_patterns.yaml").path
        searchPaths.append(configPath)

        // Development path (for testing)
        searchPaths.append("/Users/che/Library/CloudStorage/Dropbox/che_workspace/projects/mcp/che-pdf-mcp/Resources/math_patterns.yaml")

        for path in searchPaths {
            if let patterns = parseYAMLFile(at: path) {
                return patterns
            }
        }

        return nil
    }

    // MARK: - Simple YAML Parser (for our specific format)

    private static func parseYAMLFile(at path: String) -> [MathPattern]? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        return parseYAMLContent(content)
    }

    static func parseYAMLContent(_ content: String) -> [MathPattern]? {
        var patterns: [MathPattern] = []
        var currentDomain: String = ""
        var currentPattern: [String: String] = [:]
        var inPatternBlock = false

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Skip metadata lines
            if trimmed.hasPrefix("version:") || trimmed.hasPrefix("last_updated:") {
                continue
            }

            // Detect domain section (no indentation, ends with :)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && trimmed.hasSuffix(":") && !trimmed.contains("\"") {
                // Save previous pattern if exists
                if let pattern = createPattern(from: currentPattern, domain: currentDomain) {
                    patterns.append(pattern)
                }
                currentPattern = [:]
                inPatternBlock = false

                // Extract domain name
                currentDomain = String(trimmed.dropLast())
                continue
            }

            // Detect new pattern entry (starts with -)
            if trimmed.hasPrefix("- pattern:") || trimmed == "-" {
                // Save previous pattern if exists
                if let pattern = createPattern(from: currentPattern, domain: currentDomain) {
                    patterns.append(pattern)
                }
                currentPattern = [:]
                inPatternBlock = true

                // Parse inline pattern if exists
                if trimmed.hasPrefix("- pattern:") {
                    let value = extractValue(from: trimmed, prefix: "- pattern:")
                    currentPattern["pattern"] = value
                }
                continue
            }

            // Parse pattern properties
            if inPatternBlock && !currentDomain.isEmpty {
                if trimmed.hasPrefix("pattern:") {
                    currentPattern["pattern"] = extractValue(from: trimmed, prefix: "pattern:")
                } else if trimmed.hasPrefix("replacement:") {
                    currentPattern["replacement"] = extractValue(from: trimmed, prefix: "replacement:")
                } else if trimmed.hasPrefix("priority:") {
                    currentPattern["priority"] = extractValue(from: trimmed, prefix: "priority:")
                } else if trimmed.hasPrefix("description:") {
                    currentPattern["description"] = extractValue(from: trimmed, prefix: "description:")
                }
            }
        }

        // Don't forget the last pattern
        if let pattern = createPattern(from: currentPattern, domain: currentDomain) {
            patterns.append(pattern)
        }

        return patterns.isEmpty ? nil : patterns
    }

    // MARK: - Helper: Extract Value

    private static func extractValue(from line: String, prefix: String) -> String {
        var value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)

        // Remove surrounding quotes
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        } else if value.hasPrefix("'") && value.hasSuffix("'") {
            value = String(value.dropFirst().dropLast())
        }

        // Handle escape sequences
        value = value.replacingOccurrences(of: "\\\\", with: "\\")

        return value
    }

    // MARK: - Helper: Create Pattern

    private static func createPattern(from dict: [String: String], domain: String) -> MathPattern? {
        guard let pattern = dict["pattern"],
              let replacement = dict["replacement"],
              !pattern.isEmpty else {
            return nil
        }

        let priority = Int(dict["priority"] ?? "5") ?? 5
        let description = dict["description"] ?? ""

        return MathPattern(
            pattern: pattern,
            replacement: replacement,
            priority: priority,
            description: description,
            domain: domain
        )
    }

    // MARK: - Built-in Patterns (Fallback)

    private static let builtInPatterns: [MathPattern] = [
        // Basic subscripts
        MathPattern(pattern: "([A-Za-z])([0-9]+)(?![0-9a-zA-Z_])", replacement: "$1_{$2}", priority: 5, description: "變數下標: X1→X_{1}", domain: "statistics"),

        // Greek subscripts
        MathPattern(pattern: "(α|β|γ|δ|ε|η|θ|λ|μ|ν|ρ|σ|τ|φ|ω)([0-9]+)", replacement: "$1_{$2}", priority: 4, description: "希臘字母下標", domain: "statistics"),

        // Transpose
        MathPattern(pattern: "([A-Za-z])['']", replacement: "$1'", priority: 3, description: "轉置", domain: "linear_algebra"),

        // Matrix inverse
        MathPattern(pattern: "([A-Za-z])\\^?[-]?1", replacement: "$1^{-1}", priority: 3, description: "逆矩陣", domain: "linear_algebra"),

        // Expectation
        MathPattern(pattern: "E\\[([^\\]]+)\\]", replacement: "\\mathbb{E}[$1]", priority: 2, description: "期望值", domain: "statistics"),

        // Variance
        MathPattern(pattern: "Var\\(([^)]+)\\)", replacement: "\\text{Var}($1)", priority: 2, description: "變異數", domain: "statistics"),

        // Sample mean
        MathPattern(pattern: "([Xx])[-_]?bar", replacement: "\\bar{X}", priority: 2, description: "樣本平均", domain: "statistics"),

        // Sigma squared
        MathPattern(pattern: "sigma\\^?2", replacement: "\\sigma^{2}", priority: 3, description: "變異數 σ²", domain: "statistics"),

        // Hat notation
        MathPattern(pattern: "([A-Za-z])\\^", replacement: "\\hat{$1}", priority: 3, description: "估計值", domain: "statistics"),

        // Sum notation
        MathPattern(pattern: "sum_\\{([^}]+)\\}", replacement: "\\sum_{$1}", priority: 2, description: "求和", domain: "calculus"),

        // Product notation
        MathPattern(pattern: "prod_\\{([^}]+)\\}", replacement: "\\prod_{$1}", priority: 2, description: "連乘", domain: "calculus"),

        // Integral
        MathPattern(pattern: "int_\\{([^}]+)\\}", replacement: "\\int_{$1}", priority: 2, description: "積分", domain: "calculus"),

        // Fraction
        MathPattern(pattern: "([0-9]+)/([0-9]+)", replacement: "\\frac{$1}{$2}", priority: 4, description: "分數", domain: "calculus"),

        // Square root
        MathPattern(pattern: "sqrt\\(([^)]+)\\)", replacement: "\\sqrt{$1}", priority: 3, description: "平方根", domain: "calculus"),

        // Limit
        MathPattern(pattern: "lim_\\{([^}]+)\\}", replacement: "\\lim_{$1}", priority: 2, description: "極限", domain: "calculus"),
    ]

    // MARK: - Get Pattern Count (for debugging)

    static func getPatternInfo() -> (total: Int, fromFile: Bool, domains: [String: Int]) {
        let patterns = loadPatterns()
        var domainCounts: [String: Int] = [:]

        for pattern in patterns {
            domainCounts[pattern.domain, default: 0] += 1
        }

        let fromFile = loadFromFile() != nil

        return (patterns.count, fromFile, domainCounts)
    }
}
