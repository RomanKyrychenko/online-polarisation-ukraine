# online-polarisation-ukraine

Reproducible pipeline for measuring online political polarisation on Ukrainian
Twitter (Dec 2018 – Feb 2022), accompanying the doctoral dissertation
*Examining Polarisation Dynamics: The Case of Ukraine* (Roman Kyrychenko,
University of Helsinki, Faculty of Social Sciences, 2026).

## What is here

- Data-collection scripts (R, `academictwitteR`) for the seed-and-expand
  strategy against the Twitter v2 Academic Research Track.
- Preprocessing and bot-detection wrappers around `tweetbotornot`.
- Training and inference code for four custom NLP models:
  - **NER** — spaCy `tok2vec` model, 8 political entity classes, UK/RU text.
  - **ABSA (small)** — LCF-BERT on RuBERT-base, 3-class sentiment
    (negative / neutral / positive) per target entity.
  - **ABSA (large)** — LCF-BERT on multilingual BERT, extended to 210
    Ukrainian political and social entities.
  - **Sentence embeddings** — SBERT with temporal augmentation, used as the
    embedding backbone for BERTopic.
- BERTopic pipeline for topic discovery, plus a Qwen 2.5 7B (local, via
  Ollama) topic-labelling step for interpreting the 500+ clusters.
- Polarisation-metric implementations for the five-component framework
  introduced in Chapter 4 of the dissertation.
- Figure-generation scripts (R + ggplot2) that reproduce the visualisations
  in the empirical chapters.

## What is NOT here

- **Raw tweet text and user metadata** cannot be redistributed under the
  Twitter Developer Agreement. The repository releases only tweet IDs and
  aggregated, de-identified analysis tables. Researchers with API access
  can rehydrate the corpus using the provided IDs.
- **Trained model weights** live on Hugging Face rather than in this repo,
  because they are large binaries. See `models/README.md` for direct links.

## Directory layout

```
online-polarisation-ukraine/
├── data/
│   ├── tweet_ids/          # released tweet IDs (one .txt per day/query)
│   └── aggregates/         # de-identified analysis tables
├── models/                 # pointers only; weights are on Hugging Face
├── notebooks/              # exploratory notebooks (numbered)
├── src/
│   ├── collection/         # R scripts: academictwitteR wrappers
│   ├── preprocessing/      # cleaning, dedup, language filter
│   ├── ner/                # spaCy training + inference
│   ├── absa/               # LCF-BERT training + inference (pyabsa)
│   ├── topics/             # BERTopic + UMAP + HDBSCAN config
│   ├── embeddings/         # SBERT temporal-pair training
│   ├── llm_labelling/      # Qwen 2.5 topic-label prompts + parser
│   └── metrics/            # polarisation-metric implementations
├── scripts/                # numbered end-to-end pipeline drivers
└── docs/                   # REPRODUCE.md and ETHICS.md
```

## Reproducing the analysis

The end-to-end pipeline is driven by the numbered scripts in `scripts/`,
which correspond one-to-one with the empirical chapters. A step-by-step
walkthrough — including Twitter API prerequisites, expected runtime,
disk footprint, and GPU requirements — lives in
[`docs/REPRODUCE.md`](docs/REPRODUCE.md).

## Environment

Two dependency specifications are provided:

- `requirements.txt` — pip-installable Python deps.
- `environment.yml` — full conda environment (Python + R + system libs
  pinned to the versions used to produce the published figures).

## Citation

If you use this pipeline or the released tweet IDs, please cite:

```
Kyrychenko, R. (2026). Examining Polarisation Dynamics: The Case of Ukraine.
Dissertationes Universitatis Helsingiensis 345/2026.
University of Helsinki, Faculty of Social Sciences.
ISBN 978-952-84-2803-9 (Paperback), 978-952-84-2802-2 (PDF).
```

## Licence

Code released under the [MIT License](LICENSE). Model weights (on
Hugging Face) are released under CC BY-NC 4.0 for non-commercial research
use. Tweet IDs are released in compliance with the Twitter Developer
Agreement (see `docs/ETHICS.md`).
