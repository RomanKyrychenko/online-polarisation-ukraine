# Reproducing the analysis

This document walks through recreating every table and figure in the
empirical chapters of *Examining Polarisation Dynamics: The Case of Ukraine*,
from raw Twitter data collection through the final polarisation-metric
outputs. Total end-to-end runtime is roughly 3–5 days on a workstation with a
single mid-range GPU; a large fraction of that is Twitter API pagination.

## 0. Prerequisites

- **Twitter Academic Research access.** The corpus used by the dissertation
  was collected under the v2 Academic Research Product Track (2019–2022).
  That track has since been discontinued. If you have alternative access to
  full-archive search, adjust `src/collection/config.R` accordingly;
  otherwise, start from the released tweet IDs in `data/tweet_ids/`.
- **Compute.** A CUDA-capable GPU with ≥12 GB VRAM for ABSA and BERTopic;
  CPU-only is possible but ~30× slower.
- **Disk.** ~180 GB for the full raw corpus; ~15 GB for the processed
  analysis set.
- **Ollama** installed and running locally for the LLM topic-labelling step
  (`ollama pull qwen2.5:7b`).

## 1. Environment

```bash
mamba env create -f environment.yml
conda activate polarisation-ukraine
python -m spacy download uk_core_news_sm
python -m spacy download ru_core_news_sm
Rscript scripts/install_r_deps.R
```

## 2. Pipeline (numbered scripts)

Each script in `scripts/` is a driver for one stage of the pipeline. They
are numbered so that running them in order reproduces the full analysis.

| # | Script                       | Chapter | Output                                    |
|---|------------------------------|---------|-------------------------------------------|
| 1 | `01_collect_data.R`          |    7    | `data/raw/tweets/*.parquet`               |
| 2 | `02_bot_detection.R`         |    7    | `data/interim/bot_scores.parquet`         |
| 3 | `03_ner_inference.py`        |    7    | `data/interim/entities.parquet`           |
| 4 | `04_absa_inference.py`       |    7    | `data/interim/sentiment.parquet`          |
| 5 | `05_bertopic.py`             |    7    | `data/interim/topics.parquet`             |
| 6 | `06_llm_label_topics.py`     |    7    | `data/interim/topic_labels.jsonl`         |
| 7 | `07_compute_metrics.py`      |    4, 9 | `data/aggregates/metrics_*.parquet`       |
| 8 | `08_generate_figures.R`      |  8–11   | `visualisations/*.tex`                    |

Skip step 1 if starting from the released IDs; run
`scripts/rehydrate_from_ids.R` instead.

## 3. Model weights

All four custom models are hosted on Hugging Face under
`kyrychenko17roman`. `scripts/03_ner_inference.py` and
`scripts/04_absa_inference.py` pull them at first run:

- [`kyrychenko17roman/ukrainian-political-ner`](https://huggingface.co/kyrychenko17roman/ukrainian-political-ner)
- [`kyrychenko17roman/lcf-bert-ukrainian-absa`](https://huggingface.co/kyrychenko17roman/lcf-bert-ukrainian-absa)
- [`kyrychenko17roman/multilingual-bert-ukrainian-absa-210`](https://huggingface.co/kyrychenko17roman/multilingual-bert-ukrainian-absa-210)
- [`kyrychenko17roman/sbert-ukrainian-temporal`](https://huggingface.co/kyrychenko17roman/sbert-ukrainian-temporal)

If you want to retrain from scratch, the training scripts live in
`src/{ner,absa,embeddings}/train.py` and use the hand-labelled dataset
described in Chapter 7 (released separately on request).

## 4. Regenerating the dissertation figures

`08_generate_figures.R` writes one `.tex` per figure into `visualisations/`,
matching the filenames referenced from the thesis chapters. Copy them
into the thesis `visualisations/` folder and rebuild the thesis with
`latexmk -xelatex main.tex`.

## 5. Sanity checks

`tests/` contains regression tests that compare small samples against
frozen reference outputs. Run before submitting a pull request:

```bash
pytest tests/ -q
```
