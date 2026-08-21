# Data

## What's here

- **`tweet_ids/`** — released tweet IDs (one `.txt` per query / date range).
  Rehydrate with `scripts/rehydrate_from_ids.R` if you have API access.
- **`aggregates/`** — de-identified analysis tables that back the empirical
  chapter figures. These are safe to redistribute (no user handles, no raw
  text).

## What's NOT here

Raw tweet text, user metadata, and API payloads are **not** in this
repository per the Twitter Developer Agreement (see
[`../docs/ETHICS.md`](../docs/ETHICS.md)). The `.gitignore` blocks
`data/raw/`, `data/interim/`, and common raw-payload extensions from being
committed.
