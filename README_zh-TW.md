# che-pdf-mcp

以 Swift 原生開發的 MCP (Model Context Protocol) 伺服器，用於操作 PDF 文件。使用 macOS 原生框架（PDFKit、Vision、CoreGraphics）實現高效能 PDF 處理，無需外部依賴。

[English](README.md)

## 特色

- **純 Swift 實作**：不需要 Python、Node.js 或其他執行環境
- **macOS 原生 API**：使用 PDFKit 處理核心操作，Vision 處理 OCR
- **單一執行檔**：只有一個 binary 檔案
- **25 個 MCP 工具**：完整的 PDF 操作工具集
- **高效能**：原生二進位檔，無解譯器開銷

## 安裝

### 系統需求

- macOS 13.0+（Ventura 或更新版本）
- Swift 5.9+

### 從原始碼編譯

```bash
git clone https://github.com/kiki830621/che-pdf-mcp.git
cd che-pdf-mcp
swift build -c release
```

執行檔位於 `.build/release/ChePDFMCP`

### 加入 Claude Code

```bash
claude mcp add che-pdf-mcp /path/to/che-pdf-mcp/.build/release/ChePDFMCP
```

### 加入 Claude Desktop

編輯 `~/Library/Application Support/Claude/claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "che-pdf-mcp": {
      "command": "/path/to/che-pdf-mcp/.build/release/ChePDFMCP"
    }
  }
}
```

## AI Agent 使用方式

### 直接告訴 Agent

最簡單的方式 - 直接告訴 AI agent 使用它：

```
使用 che-pdf-mcp 提取 ~/Documents/report.pdf 的文字
```

### AGENTS.md / CLAUDE.md

如需更一致的結果，將以下內容加入專案或全域指示檔：

```markdown
## PDF 文件操作

使用 `che-pdf-mcp` 讀取和處理 PDF 檔案。

核心流程：
1. `pdf_info` - 取得 PDF 資訊和頁數
2. `pdf_extract_text` - 提取文字內容
3. `pdf_search_text` - 搜尋 PDF 中的文字
4. `pdf_merge` - 合併多個 PDF
5. `pdf_extract_pages` - 抽取特定頁面
6. `pdf_ocr_text` - OCR 掃描件
7. `pdf_to_markdown` - 轉換為 Markdown
```

### Claude Code Skill

```bash
mkdir -p .claude/skills/che-pdf-mcp
curl -o .claude/skills/che-pdf-mcp/SKILL.md \
  https://raw.githubusercontent.com/kiki830621/che-pdf-mcp/main/skills/che-pdf-mcp/SKILL.md
```

## 可用工具（25 個工具）

### 文件存取（6 個）

| 工具 | 說明 |
|------|------|
| `pdf_info` | 取得 PDF 資訊（頁數、版本、加密狀態、metadata）|
| `pdf_list` | 列出目錄中的 PDF 檔案 |
| `pdf_open` | 開啟 PDF 並回傳 document ID |
| `pdf_close` | 關閉已開啟的文件 |
| `pdf_list_open` | 列出所有已開啟的文件 |
| `pdf_page_count` | 取得頁數 |

### 文字提取與搜尋（3 個）

| 工具 | 說明 |
|------|------|
| `pdf_extract_text` | 提取純文字（可指定頁面範圍）|
| `pdf_search_text` | 搜尋 PDF 中的文字 |
| `pdf_extract_text_with_layout` | 提取帶位置資訊的文字 |

### 文件操作（3 個）

| 工具 | 說明 |
|------|------|
| `pdf_merge` | 合併多個 PDF |
| `pdf_extract_pages` | 抽取特定頁面 |
| `pdf_save` | 儲存變更 |

### OCR（2 個）

| 工具 | 說明 |
|------|------|
| `pdf_ocr_text` | 使用 Vision OCR 從掃描 PDF 提取文字 |
| `pdf_ocr_page` | OCR 單頁並回傳帶位置資訊的文字 |

### 結構化輸出（2 個）

| 工具 | 說明 |
|------|------|
| `pdf_to_markdown` | 轉換 PDF 為 Markdown 格式 |
| `pdf_get_outline` | 取得 PDF 大綱/目錄 |

### 圖片處理（2 個）

| 工具 | 說明 |
|------|------|
| `pdf_extract_images` | 從 PDF 提取內嵌圖片 |
| `pdf_render_page` | 將 PDF 頁面渲染為圖片 |

### 偵測（2 個）

| 工具 | 說明 |
|------|------|
| `pdf_detect_type` | 偵測 PDF 類型（文字/掃描/混合）|
| `pdf_check_accessibility` | 檢查 PDF 可及性功能 |

### 進階操作（5 個）

| 工具 | 說明 |
|------|------|
| `pdf_rotate_pages` | 旋轉頁面 |
| `pdf_split` | 分割 PDF 為多個檔案 |
| `pdf_add_watermark` | 加入文字浮水印 |
| `pdf_encrypt` | 使用密碼加密 PDF |
| `pdf_url_fetch` | 從 URL 取得 PDF |

## 使用範例

### 取得 PDF 資訊

```
取得 ~/Documents/report.pdf 的資訊
```

### 提取文字

```
提取 ~/Documents/thesis.pdf 第 1-5 頁的文字
```

### 合併 PDF

```
合併 ~/Documents/part1.pdf 和 ~/Documents/part2.pdf 到 ~/Documents/combined.pdf
```

### 搜尋文字

```
在 ~/Documents/paper.pdf 中搜尋 "machine learning"
```

### 抽取頁面

```
從 ~/Documents/document.pdf 抽取第 1,3,5-10 頁到 ~/Documents/selected.pdf
```

### OCR 掃描文件

```
使用 pdf_ocr_text 處理 ~/Documents/scanned.pdf，語言設為 ["en-US", "zh-Hant"]
```

### 轉換為 Markdown

```
將 ~/Documents/paper.pdf 轉換為 Markdown 格式
```

### 偵測 PDF 類型

```
偵測 ~/Documents/document.pdf 是文字型還是掃描型
```

### 旋轉頁面

```
將 ~/Documents/document.pdf 第 1-3 頁旋轉 90 度
```

### 分割 PDF

```
將 ~/Documents/book.pdf 分割為每頁一個檔案
```

### 加入浮水印

```
在 ~/Documents/report.pdf 加入 "CONFIDENTIAL" 浮水印
```

### 加密 PDF

```
使用密碼 "secret123" 加密 ~/Documents/sensitive.pdf
```

## 技術細節

### 使用的 macOS 框架

- **PDFKit**：核心 PDF 操作（讀取、寫入、合併、搜尋）
- **Vision**：掃描件 OCR
- **CoreGraphics**：低階 PDF 存取、圖片渲染
- **AppKit**：圖片格式轉換

### 依賴

- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)（v0.10.0+）

## 與其他方案比較

| 功能 | mcp-pdf-tools | MCP_PDF_Server | **che-pdf-mcp** |
|------|---------------|----------------|--------------------|
| 語言 | Rust | Python | **Swift** |
| Runtime | 無 | Python | **無** |
| OCR | 否 | 否 | **是 (Vision)** |
| 合併 | 是 | 否 | **是** |
| 抽頁 | 是 | 否 | **是** |
| Markdown 輸出 | 否 | 否 | **是** |
| 浮水印 | 否 | 否 | **是** |
| 加密 | 否 | 否 | **是** |
| URL 讀取 | 否 | 否 | **是** |
| macOS 原生 | 否 | 否 | **是** |

## 授權

MIT License

## 作者

鄭澈 ([@kiki830621](https://github.com/kiki830621))

## 相關專案

- [che-word-mcp](https://github.com/kiki830621/che-word-mcp) - Word 文件 MCP 伺服器
- [che-apple-mail-mcp](https://github.com/kiki830621/che-apple-mail-mcp) - Apple Mail MCP 伺服器
