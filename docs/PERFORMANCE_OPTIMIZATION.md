# 效能優化建議

## 當前效能瓶頸分析

### Benchmark 結果 (2025-01)

| 方法 | 時間/頁 | 說明 |
|------|---------|------|
| PDFKit 直接 | 0.0009s | Swift 直接調用，無 MCP |
| PyMuPDF | 0.0066s | Python 綁定 MuPDF |
| che-pdf-mcp (MCP) | 0.068s | 透過 MCP 協議 |

### 關鍵發現

**PDFKit 本身比 PyMuPDF 快 7 倍**，但 MCP 協議開銷讓整體慢了 75 倍。

```
實際 PDF 處理: ~1%
MCP 協議開銷:  ~99%
```

### MCP 開銷來源

1. **進程啟動** - 每次調用都啟動新進程
2. **JSON 序列化** - 請求/回應的 JSON 編解碼
3. **stdio 通訊** - 透過標準輸入輸出傳輸
4. **協議握手** - initialize/initialized 交換

---

## 優化方案

### 方案 1：常駐 MCP Server（推薦）

**預期改善：2-3x**

#### 原理
避免每次調用都重新啟動進程，讓 server 保持運行。

#### 實作方向
```swift
// 目前：每次調用都啟動新進程
// subprocess.run([mcp_binary], input=request)

// 改善：使用長連接
// 1. Server 啟動後保持運行
// 2. Client 重複使用同一連接
```

#### 需要修改
- Client 端：維護連接池
- Server 端：支援多次請求（目前已支援）

---

### 方案 2：批次處理 API

**預期改善：5-10x（多文件場景）**

#### 原理
一次請求處理多個 PDF，分攤協議開銷。

#### 實作方向
```swift
// 新增 Tool: pdf_batch_extract
Tool(
    name: "pdf_batch_extract",
    description: "Extract text from multiple PDFs in one call",
    inputSchema: .object([
        "paths": .array([.string]),  // 多個 PDF 路徑
        "options": .object([...])
    ])
)
```

#### 適用場景
- 批量處理文件夾中的 PDF
- 需要比較多個 PDF 內容

---

### 方案 3：直接 CLI 模式（繞過 MCP）

**預期改善：75x（與 PDFKit 直接調用相當）**

#### 原理
提供非 MCP 的命令列介面，直接輸出結果。

#### 實作方向
```swift
// 新增 CLI 模式
// che-pdf-mcp --cli extract /path/to/file.pdf

@main
struct ChePDFMCP {
    static func main() async throws {
        if CommandLine.arguments.contains("--cli") {
            // 直接 CLI 模式
            runCLI()
        } else {
            // MCP 模式
            try await PDFMCPServer().run()
        }
    }
}
```

#### 優點
- 腳本直接調用，無需 MCP client
- 可整合到 shell pipeline

#### 缺點
- 失去 MCP 的結構化回應
- 無法直接被 Claude 等 AI 使用

---

### 方案 4：平行處理

**預期改善：Nx（N = CPU 核心數）**

#### 原理
多頁 PDF 可以平行提取文字。

#### 實作方向
```swift
// 使用 Swift Concurrency
private func extractTextParallel(doc: PDFDocument) async -> [String] {
    await withTaskGroup(of: (Int, String).self) { group in
        for i in 0..<doc.pageCount {
            group.addTask {
                let page = doc.page(at: i)
                return (i, page?.string ?? "")
            }
        }

        var results = [(Int, String)]()
        for await result in group {
            results.append(result)
        }
        return results.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
}
```

#### 注意事項
- PDFKit 的 thread-safety 需要驗證
- 小文件可能因為開銷反而更慢
- 建議設定閾值（如 > 10 頁才平行處理）

---

### 方案 5：WebSocket 傳輸

**預期改善：1.5-2x**

#### 原理
用 WebSocket 取代 stdio，減少 I/O 開銷。

#### 實作方向
MCP 支援 SSE (Server-Sent Events) 傳輸，可以考慮：

```swift
// 使用 HTTP + SSE 傳輸
let transport = HTTPServerTransport(port: 8080)
try await server.start(transport: transport)
```

#### 優點
- 更高效的連接復用
- 支援多 client 連接

#### 缺點
- 需要管理 port
- 比 stdio 複雜

---

### 方案 6：結果快取

**預期改善：∞（相同文件）**

#### 原理
快取已處理過的 PDF 結果。

#### 實作方向
```swift
// 使用文件 hash 作為 key
private var cache: [String: CachedResult] = [:]

struct CachedResult {
    let text: String
    let timestamp: Date
    let fileHash: String
}

private func getCachedOrExtract(path: String) -> String {
    let hash = computeFileHash(path)
    if let cached = cache[hash], !isExpired(cached) {
        return cached.text
    }
    let text = extractText(path)
    cache[hash] = CachedResult(text: text, ...)
    return text
}
```

#### 適用場景
- 重複處理相同文件
- 文件很少更新

---

## 優先順序建議

| 優先級 | 方案 | 難度 | 效果 | 適用場景 |
|--------|------|------|------|----------|
| 1 | 常駐 Server | 低 | 2-3x | 所有場景 |
| 2 | 結果快取 | 低 | ∞ | 重複文件 |
| 3 | 平行處理 | 中 | Nx | 大文件 |
| 4 | 批次 API | 中 | 5-10x | 多文件 |
| 5 | CLI 模式 | 低 | 75x | 腳本使用 |
| 6 | WebSocket | 高 | 1.5x | 特殊需求 |

---

## 參考資料

- [MCP Transport 規格](https://modelcontextprotocol.io/docs/concepts/transports)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [PDFKit Thread Safety](https://developer.apple.com/documentation/pdfkit)

---

## 測試腳本

### 測試 PDFKit 直接效能
```bash
swift benchmark/test_pdfkit_direct.swift <pdf_path>
```

### 測試 MCP 效能
```bash
cd benchmark && source venv/bin/activate
python benchmark.py <pdf_path>
```
