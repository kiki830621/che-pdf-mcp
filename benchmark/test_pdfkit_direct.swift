#!/usr/bin/env swift
// 直接測試 PDFKit 效能（不經過 MCP）

import Foundation
import PDFKit

let args = CommandLine.arguments
guard args.count > 1 else {
    print("Usage: swift test_pdfkit_direct.swift <pdf_path>")
    exit(1)
}

let pdfPath = args[1]
guard let doc = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else {
    print("Error: Cannot open PDF")
    exit(1)
}

let iterations = 10
var totalTime: Double = 0

for i in 0..<iterations {
    let start = Date()

    var fullText = ""
    for pageIndex in 0..<doc.pageCount {
        if let page = doc.page(at: pageIndex) {
            let pageText = page.string ?? ""
            fullText += "--- Page \(pageIndex + 1) ---\n"
            fullText += pageText
            fullText += "\n\n"
        }
    }

    let elapsed = Date().timeIntervalSince(start)
    totalTime += elapsed

    if i == 0 {
        print("Pages: \(doc.pageCount)")
        print("Text length: \(fullText.count) chars")
    }
}

let avgTime = totalTime / Double(iterations)
let perPage = avgTime / Double(doc.pageCount)

print("\nResults (averaged over \(iterations) runs):")
print("Total time: \(String(format: "%.4f", avgTime))s")
print("Per page:   \(String(format: "%.4f", perPage))s")
