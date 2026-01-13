# che-pdf-mcp

以 Swift 原生開發的 MCP (Model Context Protocol) 伺服器，用於操作 PDF 文件。使用 macOS 原生框架（PDFKit、Vision、CoreGraphics）實現高效能 PDF 處理，無需外部依賴。

[English](README.md)

## 特色

- **純 Swift 實作**：不需要 Python、Node.js 或其他執行環境
- **macOS 原生 API**：使用 PDFKit 處理核心操作，Vision 處理 OCR
- **單一執行檔**：只有一個 binary 檔案
- **12 個 MCP 工具**（MVP）：文件資訊、文字提取、搜尋、合併、抽頁
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
```

### Claude Code Skill

```bash
mkdir -p .claude/skills/che-pdf-mcp
curl -o .claude/skills/che-pdf-mcp/SKILL.md \
  https://raw.githubusercontent.com/kiki830621/che-pdf-mcp/main/skills/che-pdf-mcp/SKILL.md
```

## 可用工具（12 個 MVP 工具）

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

## 技術細節

### 使用的 macOS 框架

- **PDFKit**：核心 PDF 操作（讀取、寫入、合併、搜尋）
- **Vision**：掃描件 OCR（Milestone B）
- **CoreGraphics**：低階 PDF 存取、圖片提取

### 依賴

- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)（v0.10.0+）

## 與其他方案比較

| 功能 | mcp-pdf-tools | MCP_PDF_Server | **che-pdf-mcp** |
|------|---------------|----------------|-----------------|
| 語言 | Rust | Python | **Swift** |
| Runtime | 無 | Python | **無** |
| OCR | 否 | 否 | **計劃中** |
| 合併 | 是 | 否 | **是** |
| 抽頁 | 是 | 否 | **是** |
| macOS 原生 | 否 | 否 | **是** |

## 開發路線圖

### Milestone A（MVP）- 目前

- [x] 文件存取和資訊
- [x] 文字提取
- [x] 搜尋
- [x] 合併
- [x] 抽頁

### Milestone B（RAG/文件理解）

- [ ] Vision framework OCR
- [ ] PDF 轉 Markdown
- [ ] 大綱/目錄提取
- [ ] 圖片提取
- [ ] PDF 類型偵測（文字/掃描/混合）

### Milestone C（進階功能）

- [ ] 頁面旋轉
- [ ] PDF 分割
- [ ] 浮水印
- [ ] 加密
- [ ] URL 讀取

## 授權

MIT License

## 作者

鄭澈 ([@kiki830621](https://github.com/kiki830621))

## 相關專案

- [che-word-mcp](https://github.com/kiki830621/che-word-mcp) - Word 文件 MCP 伺服器
- [che-apple-mail-mcp](https://github.com/kiki830621/che-apple-mail-mcp) - Apple Mail MCP 伺服器
