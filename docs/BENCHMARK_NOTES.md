# PDF 文字提取效能分析

## 問題

為什麼 PyMuPDF 這麼快？是平行處理嗎？

## 結論

**不是平行處理**。從 benchmark 代碼可以看到 PyMuPDF 是順序處理每一頁的。

### PyMuPDF 快的真正原因

| 因素 | 說明 |
|------|------|
| **C 語言核心** | MuPDF 是純 C 實現，Python 只是薄薄的綁定層 |
| **單次調用** | `page.get_text("dict")` 一次調用直接返回完整結構化資料 |
| **無後處理** | 不做連字符展開、字符去重等額外 Python 處理 |
| **記憶體效率** | 直接操作 PDF 內部結構，無需多次解析 |

## 各方法處理流程比較

```
PyMuPDF:     PDF → C層直接提取 → Python dict        (最快)
pdftext:     PDF → pypdfium2逐字符 → Python分組/去重  (中等)
pdfplumber:  PDF → pdfminer解析 → Python逐行處理     (最慢)
che-pdf-mcp: PDF → PDFKit(ObjC) → Swift → MCP輸出   (快)
```

## Benchmark 結果

測試環境：M 系列 Mac，單線程

| Library | Time (s/page) | Alignment (%) | 說明 |
|---------|---------------|---------------|------|
| pymupdf | 0.042 | -- (基準線) | C 語言核心，無後處理 |
| che-pdf-mcp | 0.068 | 95.16 | 原生 macOS API |
| pdftext | 0.090 | 98.57 | pypdfium2 + Python 後處理 |
| pdfplumber | 0.193 | 59.37 | 純 Python 解析 |

## 關鍵洞察

1. **語言層級決定速度**：C > Swift/ObjC > Python
2. **後處理成本高**：pdftext 雖用 pypdfium2（C++），但 Python 層的分組/去重拖慢了速度
3. **平行處理不是關鍵**：這些測試都是單線程，速度差異來自底層實現
4. **準確度與速度權衡**：pdftext 最準確但較慢，che-pdf-mcp 在速度和準確度間取得平衡

## 參考資料

- [pdftext](https://github.com/datalab-to/pdftext) - Apache 2.0 授權的 PDF 文字提取
- [PyMuPDF](https://github.com/pymupdf/PyMuPDF) - 基於 MuPDF 的 Python 綁定
- [pdfplumber](https://github.com/jsvine/pdfplumber) - 基於 pdfminer 的 PDF 解析
- [py-pdf benchmarks](https://github.com/py-pdf/benchmarks) - PDF 工具效能比較
