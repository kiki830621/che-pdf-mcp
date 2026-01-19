#!/usr/bin/env python3
"""
PDF Text Extraction Benchmark

Compares multiple PDF text extraction methods:
1. PyMuPDF (fitz) - Fast, AGPL licensed
2. pdftext (pypdfium2) - Fast, Apache licensed
3. pdfplumber - Slow but accurate
4. che-pdf-mcp (PDFKit via MCP) - Native macOS

Metrics:
- Extraction time (seconds per page)
- Text alignment accuracy (% match vs PyMuPDF baseline)
- Garbled text detection (for math formulas)
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from pathlib import Path
from statistics import mean
from typing import Dict, List, Optional, Tuple

import fitz as pymupdf
import pdfplumber
from pdftext.extraction import plain_text_output, dictionary_output
from rapidfuzz import fuzz
from tabulate import tabulate
from tqdm import tqdm

# Optional imports for visualization
try:
    import matplotlib.pyplot as plt
    import pandas as pd
    HAS_VISUALIZATION = True
except ImportError:
    HAS_VISUALIZATION = False


class PDFBenchmark:
    """PDF text extraction benchmark runner."""

    def __init__(self, mcp_binary: Optional[str] = None):
        """
        Initialize benchmark.

        Args:
            mcp_binary: Path to che-pdf-mcp binary for PDFKit comparison
        """
        self.mcp_binary = mcp_binary or self._find_mcp_binary()
        self.results = {
            "times": defaultdict(list),
            "alignments": defaultdict(list),
            "garbled_detection": defaultdict(list),
            "details": []
        }

    def _find_mcp_binary(self) -> Optional[str]:
        """Find the che-pdf-mcp binary."""
        possible_paths = [
            Path(__file__).parent.parent / ".build/release/ChePDFMCP",
            Path(__file__).parent.parent / ".build/debug/ChePDFMCP",
        ]
        for path in possible_paths:
            if path.exists():
                return str(path)
        return None

    # ==================== Extraction Methods ====================

    def extract_pymupdf(self, pdf_path: str) -> List[str]:
        """Extract text using PyMuPDF (baseline)."""
        doc = pymupdf.open(pdf_path)
        pages = []
        for i in range(len(doc)):
            page = doc[i]
            # Use detailed extraction for fair comparison
            blocks = page.get_text("dict",
                flags=pymupdf.TEXTFLAGS_DICT & ~pymupdf.TEXT_PRESERVE_LIGATURES & ~pymupdf.TEXT_PRESERVE_IMAGES)
            text = ""
            for block in blocks["blocks"]:
                if "lines" not in block:
                    continue
                for line in block["lines"]:
                    for span in line["spans"]:
                        text += span["text"]
                    text = text.rstrip() + "\n"
                text = text.rstrip() + "\n\n"
            pages.append(text)
        doc.close()
        return pages

    def extract_pdftext(self, pdf_path: str) -> List[str]:
        """Extract text using pdftext (pypdfium2)."""
        text = plain_text_output(pdf_path, sort=False, hyphens=False)
        # Split by page markers or double newlines
        pages = text.split("\n\n\n")
        return [p.strip() + "\n\n" for p in pages if p.strip()]

    def extract_pdfplumber(self, pdf_path: str) -> List[str]:
        """Extract text using pdfplumber."""
        pages = []
        with pdfplumber.open(pdf_path) as pdf:
            for page in pdf.pages:
                lines = page.extract_text_lines(strip=False, return_chars=True, keep_text_flow=True)
                text = ""
                for line in lines:
                    text += line["text"].rstrip() + "\n"
                pages.append(text + "\n")
        return pages

    def extract_pdfkit_mcp(self, pdf_path: str) -> List[str]:
        """Extract text using che-pdf-mcp (PDFKit via MCP protocol)."""
        if not self.mcp_binary:
            return []

        # Create MCP request
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "benchmark", "version": "1.0"}
            }
        }
        request2 = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "pdf_extract_text",
                "arguments": {"path": pdf_path}
            }
        }

        # Send request via stdin
        input_data = json.dumps(request) + "\n" + json.dumps(request2) + "\n"

        try:
            result = subprocess.run(
                [self.mcp_binary],
                input=input_data,
                capture_output=True,
                text=True,
                timeout=60
            )

            # Parse response
            lines = result.stdout.strip().split("\n")
            for line in lines:
                if not line:
                    continue
                try:
                    response = json.loads(line)
                    if response.get("id") == 2 and "result" in response:
                        content = response["result"].get("content", [])
                        if content:
                            # Handle both text and mixed content
                            text_parts = []
                            for item in content:
                                if isinstance(item, dict) and item.get("type") == "text":
                                    text_parts.append(item.get("text", ""))
                                elif isinstance(item, str):
                                    text_parts.append(item)

                            full_text = "".join(text_parts)
                            # Split by page markers
                            pages = []
                            current_page = ""
                            for line in full_text.split("\n"):
                                if line.startswith("--- Page "):
                                    if current_page:
                                        pages.append(current_page)
                                    current_page = ""
                                else:
                                    current_page += line + "\n"
                            if current_page:
                                pages.append(current_page)
                            return pages
                except json.JSONDecodeError:
                    continue
        except subprocess.TimeoutExpired:
            print(f"Warning: MCP extraction timed out for {pdf_path}")
        except Exception as e:
            print(f"Warning: MCP extraction failed: {e}")

        return []

    # ==================== Analysis Methods ====================

    def compare_texts(self, text1: str, text2: str) -> float:
        """Compare two texts using fuzzy matching."""
        return fuzz.ratio(text1, text2)

    def detect_garbled_ratio(self, text: str) -> float:
        """
        Detect ratio of likely garbled content (math formulas).
        Returns ratio of single-character lines to total lines.
        """
        lines = [l for l in text.split("\n") if l.strip()]
        if not lines:
            return 0.0

        single_char_lines = sum(1 for l in lines if len(l.strip()) == 1)
        return single_char_lines / len(lines)

    def analyze_structure(self, text: str) -> Dict:
        """Analyze text structure."""
        lines = text.split("\n")
        words = text.split()

        return {
            "total_chars": len(text),
            "total_lines": len(lines),
            "total_words": len(words),
            "avg_line_length": mean([len(l) for l in lines]) if lines else 0,
            "empty_lines": sum(1 for l in lines if not l.strip()),
        }

    # ==================== Benchmark Runner ====================

    def benchmark_pdf(self, pdf_path: str) -> Dict:
        """Run benchmark on a single PDF."""
        results = {
            "file": os.path.basename(pdf_path),
            "times": {},
            "alignments": {},
            "garbled_ratios": {},
            "structures": {},
        }

        extractors = {
            "pymupdf": self.extract_pymupdf,
            "pdftext": self.extract_pdftext,
            "pdfplumber": self.extract_pdfplumber,
        }

        # Add che-pdf-mcp if available
        if self.mcp_binary:
            extractors["che-pdf-mcp"] = self.extract_pdfkit_mcp

        extracted = {}

        # Run extractions
        for name, extractor in extractors.items():
            start = time.time()
            try:
                pages = extractor(pdf_path)
                elapsed = time.time() - start

                full_text = "\n\n".join(pages)
                extracted[name] = full_text

                results["times"][name] = elapsed
                results["garbled_ratios"][name] = self.detect_garbled_ratio(full_text)
                results["structures"][name] = self.analyze_structure(full_text)

                self.results["times"][name].append(elapsed)
                self.results["garbled_detection"][name].append(results["garbled_ratios"][name])

            except Exception as e:
                print(f"Warning: {name} failed on {pdf_path}: {e}")
                extracted[name] = ""
                results["times"][name] = -1

        # Calculate alignments (vs PyMuPDF baseline)
        baseline = extracted.get("pymupdf", "")
        for name, text in extracted.items():
            if name != "pymupdf" and baseline and text:
                alignment = self.compare_texts(baseline, text)
                results["alignments"][name] = alignment
                self.results["alignments"][name].append(alignment)

        self.results["details"].append(results)
        return results

    def benchmark_directory(self, pdf_dir: str, max_files: Optional[int] = None) -> None:
        """Run benchmark on all PDFs in a directory."""
        pdf_files = list(Path(pdf_dir).glob("*.pdf"))

        if max_files:
            pdf_files = pdf_files[:max_files]

        for pdf_path in tqdm(pdf_files, desc="Benchmarking PDFs"):
            self.benchmark_pdf(str(pdf_path))

    # ==================== Results ====================

    def get_summary(self) -> str:
        """Get benchmark summary as formatted table."""
        tools = list(self.results["times"].keys())

        headers = [
            "Library",
            "Time (s/page)",
            "Alignment (%)",
            "Garbled Ratio",
        ]

        table_data = []
        for tool in tools:
            times = self.results["times"][tool]
            alignments = self.results["alignments"].get(tool, [])
            garbled = self.results["garbled_detection"][tool]

            avg_time = mean(times) if times else -1
            avg_align = mean(alignments) if alignments else "--"
            avg_garbled = mean(garbled) if garbled else 0

            if isinstance(avg_align, float):
                avg_align = f"{avg_align:.2f}"

            table_data.append([
                tool,
                f"{avg_time:.3f}" if avg_time >= 0 else "failed",
                avg_align,
                f"{avg_garbled:.3f}",
            ])

        return tabulate(table_data, headers=headers, tablefmt="github")

    def save_results(self, output_path: str) -> None:
        """Save detailed results to JSON."""
        # Convert defaultdicts to regular dicts for JSON serialization
        output = {
            "summary": {
                tool: {
                    "avg_time": mean(times) if times else -1,
                    "avg_alignment": mean(self.results["alignments"].get(tool, []))
                        if self.results["alignments"].get(tool) else None,
                    "avg_garbled_ratio": mean(self.results["garbled_detection"][tool])
                        if self.results["garbled_detection"][tool] else 0,
                }
                for tool, times in self.results["times"].items()
            },
            "details": self.results["details"],
        }

        with open(output_path, "w") as f:
            json.dump(output, f, indent=2)

    def plot_results(self, output_path: str) -> None:
        """Generate visualization of results."""
        if not HAS_VISUALIZATION:
            print("Warning: matplotlib/pandas not installed, skipping visualization")
            return

        fig, axes = plt.subplots(1, 3, figsize=(15, 5))

        tools = list(self.results["times"].keys())

        # Time comparison
        times = [mean(self.results["times"][t]) for t in tools]
        axes[0].bar(tools, times, color=['#2ecc71', '#3498db', '#e74c3c', '#9b59b6'][:len(tools)])
        axes[0].set_title("Extraction Time (seconds)")
        axes[0].set_ylabel("Time (s)")
        axes[0].tick_params(axis='x', rotation=45)

        # Alignment comparison
        alignments = []
        align_tools = []
        for t in tools:
            if t != "pymupdf" and self.results["alignments"].get(t):
                alignments.append(mean(self.results["alignments"][t]))
                align_tools.append(t)

        if alignments:
            axes[1].bar(align_tools, alignments, color=['#3498db', '#e74c3c', '#9b59b6'][:len(align_tools)])
            axes[1].set_title("Alignment Score (% vs PyMuPDF)")
            axes[1].set_ylabel("Alignment (%)")
            axes[1].set_ylim(0, 100)
            axes[1].tick_params(axis='x', rotation=45)

        # Garbled ratio comparison
        garbled = [mean(self.results["garbled_detection"][t]) * 100 for t in tools]
        axes[2].bar(tools, garbled, color=['#2ecc71', '#3498db', '#e74c3c', '#9b59b6'][:len(tools)])
        axes[2].set_title("Garbled Text Ratio (%)")
        axes[2].set_ylabel("Ratio (%)")
        axes[2].tick_params(axis='x', rotation=45)

        plt.tight_layout()
        plt.savefig(output_path, dpi=150)
        plt.close()
        print(f"Saved visualization to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="PDF Text Extraction Benchmark")
    parser.add_argument("pdf_path", nargs="?", help="PDF file or directory to benchmark")
    parser.add_argument("--output", "-o", default="results", help="Output directory for results")
    parser.add_argument("--max", type=int, help="Maximum number of PDFs to process")
    parser.add_argument("--mcp-binary", help="Path to che-pdf-mcp binary")
    parser.add_argument("--no-plot", action="store_true", help="Skip generating plots")

    args = parser.parse_args()

    # Default to sample PDF if none specified
    if not args.pdf_path:
        sample_pdf = Path(__file__).parent / "pdfs"
        if not sample_pdf.exists() or not list(sample_pdf.glob("*.pdf")):
            # Use the reference benchmark PDF
            sample_pdf = Path(__file__).parent.parent / "reference/pdftext/benchmark/adversarial_short.pdf"
            if sample_pdf.exists():
                args.pdf_path = str(sample_pdf)
            else:
                print("Error: No PDF specified and no sample PDFs found")
                print("Usage: python benchmark.py <pdf_file_or_directory>")
                sys.exit(1)
        else:
            args.pdf_path = str(sample_pdf)

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Run benchmark
    benchmark = PDFBenchmark(mcp_binary=args.mcp_binary)

    pdf_path = Path(args.pdf_path)
    if pdf_path.is_file():
        print(f"Benchmarking single PDF: {pdf_path}")
        benchmark.benchmark_pdf(str(pdf_path))
    elif pdf_path.is_dir():
        print(f"Benchmarking directory: {pdf_path}")
        benchmark.benchmark_directory(str(pdf_path), max_files=args.max)
    else:
        print(f"Error: {args.pdf_path} not found")
        sys.exit(1)

    # Print summary
    print("\n" + "=" * 60)
    print("BENCHMARK RESULTS")
    print("=" * 60)
    print(benchmark.get_summary())
    print("=" * 60)

    # Save results
    results_path = output_dir / "results.json"
    benchmark.save_results(str(results_path))
    print(f"\nDetailed results saved to: {results_path}")

    # Generate plot
    if not args.no_plot and HAS_VISUALIZATION:
        plot_path = output_dir / "benchmark_plot.png"
        benchmark.plot_results(str(plot_path))


if __name__ == "__main__":
    main()
