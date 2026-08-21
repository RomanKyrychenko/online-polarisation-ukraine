# Ethics & data handling

The pipeline processes publicly available Twitter data collected under the
Twitter Academic Research Product Track (2019–2022) via the official v2 API
and the `academictwitteR` package. No private messages, protected accounts,
or non-public profile fields were collected.

## Redistribution policy

- **Raw tweet text and user metadata are NOT redistributed.** Twitter's
  Developer Agreement permits redistribution of tweet IDs only, and requires
  that deleted or protected tweets be excluded from released identifier
  lists ("honour the deletion").
- **Only tweet IDs and de-identified aggregate tables are released.**
  Researchers with API access can rehydrate the corpus using
  `scripts/rehydrate_from_ids.R`.
- **Public figures** (politicians, named officials, media outlets) are
  referred to by their public names in aggregate outputs, as is standard in
  research on political communication. **Non-public users** are never
  identified by handle, display name, or ID in any published output.

## Bot accounts

Accounts flagged with high bot probability by `tweetbotornot` are retained
in the analysis rather than excluded, on the principle that bots are active
participants in the digital public sphere whose influence on observed
polarisation is itself a finding of interest. Bot probability is kept as a
per-user feature so downstream readers can inspect the contribution of
likely automated accounts.

## Model biases

The trained models inherit biases from their pre-training corpora (RuBERT,
multilingual BERT) and from the annotation choices of the labelled training
set. These are discussed in Chapter 5 of the dissertation and revisited as a
limitation in Chapter 12.

## Regulatory basis

The research was conducted in accordance with the ethical guidelines of the
University of Helsinki Faculty of Social Sciences for studies involving
publicly available digital trace data. Because the project does not involve
human-subjects intervention, identification of private individuals, or
processing of sensitive personal data within the meaning of GDPR Article 9,
it did not require separate ethical-board approval — following established
Finnish and European practice for non-interventional research on public
social-media data.

Raw payloads are held on encrypted institutional storage with access
restricted to the author.

## Wartime scope

The empirical corpus terminates on 24 February 2022. The analysis does not
draw on wartime communications or content produced under martial law, when
expressive incentives, platform moderation, and threat conditions are
qualitatively different. Extending the analysis into the wartime period
would require additional ethical review addressing the heightened risks
faced by Ukrainian users posting under conditions of conflict.
