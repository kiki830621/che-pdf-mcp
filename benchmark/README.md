# PDF Text Extraction Benchmark

比較不同 PDF 文字提取方法的效能和準確度。

## 比較的方法

| 方法 | 底層引擎 | 授權 | 特點 |
|------|----------|------|------|
| **PyMuPDF** | MuPDF | AGPL | 快速，作為基準線 |
| **pdftext** | pypdfium2 (Google PDFium) | Apache 2.0 | 快速，無 AGPL 限制 |
| **pdfplumber** | pdfminer.six | MIT | 精確但較慢 |
| **che-pdf-mcp** | Apple PDFKit | MIT | macOS 原生，支援亂碼偵測 |

## 安裝

```bash
cd benchmark
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 使用方式

### 測試單一 PDF

```bash
python benchmark.py /path/to/your.pdf
```

### 測試目錄中的所有 PDF

```bash
python benchmark.py /path/to/pdf/directory --max 10
```

### 指定輸出目錄

```bash
python benchmark.py sample.pdf --output ./my_results
```

### 使用預設測試 PDF

```bash
python benchmark.py
```

## 輸出

1. **終端機輸出** - 格式化的比較表格
2. **results.json** - 詳細的 JSON 結果
3. **benchmark_plot.png** - 視覺化圖表（需要 matplotlib）

## 評估指標

| 指標 | 說明 |
|------|------|
| **Time (s/page)** | 每頁提取時間（秒） |
| **Alignment (%)** | 與 PyMuPDF 的文字相似度（使用 rapidfuzz） |
| **Garbled Ratio** | 亂碼比例（單字符行數/總行數） |

## 範例輸出

```
============================================================
BENCHMARK RESULTS
============================================================
| Library     | Time (s/page) | Alignment (%) | Garbled Ratio |
|-------------|---------------|---------------|---------------|
| pymupdf     | 0.032         | --            | 0.050         |
| pdftext     | 0.136         | 97.78         | 0.048         |
| pdfplumber  | 0.316         | 90.36         | 0.052         |
| che-pdf-mcp | 0.045         | 95.20         | 0.055         |
============================================================
```

## 關於亂碼偵測

`Garbled Ratio` 是用來衡量 PDF 中可能有亂碼（如數學公式）的比例：

- 計算方式：單字符行數 / 總行數
- 高比例（> 0.2）通常表示有數學公式或特殊符號
- che-pdf-mcp 會自動將高亂碼區域渲染成圖片

## 自訂測試

將你的 PDF 檔案放入 `pdfs/` 目錄，然後執行：

```bash
python benchmark.py pdfs/
```

## 參考資料

- [pdftext benchmark](https://github.com/datalab-to/pdftext)
- [py-pdf benchmarks](https://github.com/py-pdf/benchmarks)
