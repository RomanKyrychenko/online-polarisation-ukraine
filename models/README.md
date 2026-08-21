# Trained models

Model weights are hosted on Hugging Face rather than in this repo — they are
large binaries and Hugging Face provides versioning, model cards, and
programmatic download from the `transformers` / `spacy` loaders.

| Task                         | Model                                                                                                    | Chapter |
|------------------------------|----------------------------------------------------------------------------------------------------------|---------|
| Ukrainian political NER      | [`kyrychenko17roman/ukrainian-political-ner`](https://huggingface.co/kyrychenko17roman/ukrainian-political-ner) | 7 |
| ABSA (RuBERT, small)         | [`kyrychenko17roman/lcf-bert-ukrainian-absa`](https://huggingface.co/kyrychenko17roman/lcf-bert-ukrainian-absa) | 7 |
| ABSA (mBERT, 210 entities)   | [`kyrychenko17roman/multilingual-bert-ukrainian-absa-210`](https://huggingface.co/kyrychenko17roman/multilingual-bert-ukrainian-absa-210) | 7 |
| Temporal SBERT (embeddings)  | [`kyrychenko17roman/sbert-ukrainian-temporal`](https://huggingface.co/kyrychenko17roman/sbert-ukrainian-temporal) | 7 |

The inference drivers in `scripts/` pull the weights from Hugging Face on
first run and cache them under `~/.cache/huggingface/`.

## Retraining from scratch

Training scripts live in `src/{ner,absa,embeddings}/train.py`. The
hand-labelled Ukrainian political dataset (13,866 tweets for the small ABSA;
52,000 triplets for the extended 210-entity ABSA) is available separately
on request — contact the author.
