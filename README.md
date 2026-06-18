# VeriWalk: RTL Hardware Trojan Detection via Data Flow Graph Walk

VeriWalk is a hardware Trojan detection framework that analyzes Register-Transfer Level (RTL) Verilog designs by constructing Data Flow Graphs (DFGs), generating subgraph embeddings via graph walk algorithms, and identifying Trojan-modified signals through subgraph similarity comparison.

## Overview

The core detection pipeline:

1. **Verilog Parsing** — Parse RTL Verilog source files using [pyverilog](https://github.com/PyHDI/Pyverilog) to extract signal-level Data Flow Graphs (DFGs).
2. **Subgraph Extraction** — Decompose the full DFG into per-signal subgraphs via backward tracing from each output signal.
3. **Graph Embedding** — Generate fixed-length embedding vectors for each subgraph using GraphWalk (random walk + Word2Vec) or GNN-based methods.
4. **Similarity Comparison** — Compare Trojan-variant subgraphs (TjIn) against golden reference subgraphs (TjFree) using cosine similarity, per baseline circuit.
5. **Trojan Localization** — Identify low-similarity subgraphs as potential Trojan insertions, mapping back to specific Verilog signals.

## Project Structure

```
VeriWalk/
├── hw2vec/                     # Core library
│   ├── config.py               # Configuration loader (YAML + CLI)
│   ├── hw2graph.py             # Verilog → DFG conversion, subgraph extraction
│   ├── graphwalk.py            # Graph walk algorithm + embedding generation
│   ├── TJDetection.py          # Trojan detection: similarity computation & classification
│   ├── graph2vec/              # GNN-based graph embedding (GCN + pooling)
│   │   ├── models.py           # GRAPH2VEC model definition
│   │   └── trainers.py         # Training/evaluation logic
│   ├── configs/                # YAML configuration files
│   ├── yosys_dfg_extractor.py  # Alternative DFG extraction via Yosys (optional)
│   └── graphgen_patch.py       # Pyverilog patch for enhanced graph generation
├── pyverilog/                  # Modified pyverilog (v1.3.0 with DFG enhancements)
├── examples/
│   ├── use_case_7.2-逐个比对.py    # **Main detection script** (per-baseline comparison)
│   ├── example_gnn4tj.yaml     # YAML config for GNN model parameters
│   ├── EXTRTL_dataset.csv      # Ground truth signal annotations
│   ├── jplag_*.py              # JPlag-based analysis scripts
│   └── result/                 # Archived detection results
├── graphcodebert_ht/           # GraphCodeBERT comparison experiments
│   ├── graphcodebert_dfg_lite.py   # Lightweight DFG-based GraphCodeBERT analysis
│   ├── graphcodebert_dfg_analysis.py
│   ├── graphcodebert_differential.py
│   ├── graphcodebert_enhanced_features.py
│   ├── graphcodebert_subgraph_analysis.py
│   └── graphcodebert_with_verilog_dfg.py
├── assets/
│   ├── EXTRTL/                 # EXTRTL benchmark dataset (Verilog source)
│   │   ├── TjFree/             # 45 golden reference circuits
│   │   ├── TjIn/               # 45 Trojan variants (AES, PIC16F84, RS232)
│   │   └── TjIn2/              # 90 extended Trojan variants (16 circuit families)
│   └── rtl_dfg_graphs_full/   # Pre-computed DFG subgraphs (183 pkl files)
│       ├── EXTRTL_0_index.pkl          # Dataset index
│       ├── EXTRTL_0_detection_results.pkl  # Detection results
│       ├── EXTRTL_<circuit>.pkl        # Per-circuit DFG data (subgraphs, signal mapping)
│       └── ...                         # 180 circuit pkl files
├── JPlag/                      # JPlag plagiarism detection tool (Java)
├── outputs/                    # Detection output directory
├── requirements.txt
├── setup.py
└── LICENSE
```

## Installation

### Prerequisites

- Python >= 3.8
- (Optional) Java JRE >= 11 for JPlag comparison

### Setup

```bash
# Clone the repository
git clone https://github.com/herg2009/VeriWalk.git
cd VeriWalk

# Create a conda environment (recommended)
conda create -n veriwalk python=3.10
conda activate veriwalk

# Install dependencies
pip install -r requirements.txt
```

> **Note on pyverilog**: This project includes a modified version of pyverilog 1.3.0 in the `pyverilog/` directory with DFG-specific enhancements. The local version takes precedence via `sys.path` ordering in the detection scripts. Alternatively, you can install the stock version via `pip install pyverilog==1.3.0`, but some DFG generation features may behave differently.

## Usage

### Main Detection Script

The primary detection script is `examples/use_case_7.2-逐个比对.py`, which performs per-baseline Trojan detection:

```bash
cd examples

# Run with default config (GraphWalk embedding, EXTRTL dataset)
python "use_case_7.2-逐个比对.py"

# Or specify config explicitly
python "use_case_7.2-逐个比对.py" --yaml_path example_gnn4tj.yaml
```

#### Configuration

Key parameters are set at the top of the script:

| Variable | Values | Description |
|---|---|---|
| `DATASET_CHOICE` | 0–4 | Dataset selection (default: 4 = EXTRTL) |
| `EMBEDDING_METHOD` | 0/1/2 | 0=GraphWalk, 1=GNN, 2=GraphMatching |
| `STORAGE_MODE` | 0/1 | 0=Single pkl, 1=Per-circuit pkl (NTL-style) |

#### Output

The script produces:
- `rsl_EXTRTL_simRow.txt` — Per-variant detection results with similarity scores
- `rsl_EXTRTL_dataset.csv` — CSV format for further analysis
- `histogram_similarity.png` — Similarity distribution histogram
- Console output with TP/FP/TN/FN metrics per circuit and overall

### DFG Data

Pre-computed DFG subgraph data is included in `assets/rtl_dfg_graphs_full/` (183 pkl files, covering all 180 EXTRTL circuits). The script loads these automatically — no Verilog parsing needed.

To regenerate DFGs from Verilog source (e.g., after modifying the parser), set the `if 0:` block at line ~283 to `if 1:`:

```python
if 1:  # Change from 0 to 1 to regenerate DFGs from Verilog source
    '''converting graph using hw2graph'''
```

After regeneration, revert to `if 0:` for subsequent runs.

### JPlag Analysis

JPlag-based Verilog similarity analysis (requires Java for the original JPlag, or use the Python reimplementation):

```bash
# Python-based JPlag-style analysis (no Java needed)
python jplag_verilog_analyzer.py

# Signal-level JPlag evaluation with ground truth
python jplag_signal_evaluation.py
```

### GraphCodeBERT Comparison

GraphCodeBERT-based code similarity experiments are located in `graphcodebert_ht/`:

```bash
cd graphcodebert_ht

# Lightweight DFG-based GraphCodeBERT analysis
python graphcodebert_dfg_lite.py

# Full DFG analysis
python graphcodebert_dfg_analysis.py
```

## EXTRTL Dataset

The EXTRTL dataset includes 180 RTL Verilog circuit variants across 45 base designs:

| Category | Count | Description |
|---|---|---|
| TjFree | 45 | Golden reference circuits (no Trojan) |
| TjIn | 45 | Trojan variants on AES, PIC16F84, RS232 |
| TjIn2 | 90 | Extended variants on 16 additional circuit families |

Ground truth signal annotations are provided in `examples/EXTRTL_dataset.csv`.

## Detection Methods

### GraphWalk (Default)

Generates subgraph embeddings by performing random walks on DFG subgraphs and training a Word2Vec model on the walk sequences. The resulting node embeddings are averaged to produce a fixed-length subgraph vector.

### GNN

Uses a Graph Convolutional Network (GCN) with top-k pooling to learn subgraph embeddings in a supervised or self-supervised manner.

### Graph Matching

Computes structural similarity between subgraphs using graph edit distance or node-matching heuristics.

## Citation

If you use VeriWalk in your research, please cite:

```bibtex
@article{VeriWalk,
  title={VeriWalk: A GraphWalk-Based Approach for Verilog Code Modification Detection},
  author={He Guowu, Li Qingbao, Geng Zhixuan},
  journal={...},
  year={2026}
}
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

The included [JPlag](https://github.com/jplag/JPlag) tool is licensed under Apache License 2.0.
The included [pyverilog](https://github.com/PyHDI/Pyverilog) is licensed under Apache License 2.0.
