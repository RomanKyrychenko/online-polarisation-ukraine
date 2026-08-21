# legacy/

Older exploratory scripts from the PhD's early phases (2019–2023). Kept
for reference and reproducibility of the earlier working papers. The
production pipeline lives in `src/` and `scripts/`; nothing in `legacy/`
is required to reproduce the dissertation's final figures.

Files here have been sanitised the same way as the rest of the repo:
credentials and absolute paths have been replaced with environment
variables (see `../.env.example`). The Twitter Bearer token that was
previously hard-coded in `phd/twitter_load.R` now reads from
`TWITTER_BEARER_TOKEN`.

## phd/

Collection and preliminary processing scripts from the initial Twitter
Academic Research Track work:

| File                        | Purpose                                                          |
|-----------------------------|------------------------------------------------------------------|
| `twitter_load.R`            | First-generation Twitter loader (bearer-token API)               |
| `twitter_fullload.R`        | Full timeline expansion loop                                     |
| `twitter_users.R`           | User metadata collection                                         |
| `twitter_locations.R`       | Geographic annotation                                            |
| `twitter_bots_fast.R`       | `tweetbotornot` wrapper                                          |
| `read_json_tweets.R`        | JSON payload → dataframe                                         |
| `twitter_text.R`            | Text-cleaning heuristics                                         |
| `user_country.R`            | Country attribution from user metadata                           |
| `named_entity_dataset.R`    | Early NER training set                                           |
| `sent_amb.py`               | Early sentiment / ambiguity work                                 |
| `entity.py`                 | spaCy loader for the first-generation NER model                  |
| `additional_links.py`       | Link enrichment                                                  |
| `links_scraper.py`          | URL scraper                                                      |
| `postanalysis.R`            | Post-hoc analysis helpers                                        |
| `baldassari_simulations.R`  | Baldassari-Bearman simulation code (Chapter 4 background)        |
