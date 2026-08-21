#!/bin/bash
# Example usage of the improved APC dataset generator
# =====================================================

# Prerequisites
# -------------
# 1. Install required packages:
#    pip install openai>=1.0.0 pydantic>=2.0.0 python-dotenv
#
# 2. Set your OpenAI API key:
#    export OPENAI_API_KEY="your-api-key-here"
#    # Or create a .env file with: OPENAI_API_KEY=your-api-key-here

# Basic Usage Examples
# --------------------

# 1. Process a file with default settings
python scripts/generate_acp_dataset.py twitter_texts.txt

# Output: twitter_texts.apc.txt

# 2. Specify custom output path
python scripts/generate_acp_dataset.py twitter_texts.txt -o data/training.apc.txt

# 3. Verbose output to see progress
python scripts/generate_acp_dataset.py twitter_texts.txt -v

# 4. Process only first 100 texts (for testing)
python scripts/generate_acp_dataset.py twitter_texts.txt -n 100 -v

# 5. Use GPT-4 instead of GPT-4o-mini (more accurate but expensive)
python scripts/generate_acp_dataset.py twitter_texts.txt -m gpt-4o -v

# 6. Lower temperature for more deterministic results
python scripts/generate_acp_dataset.py twitter_texts.txt -t 0.1 -v

# 7. Skip first 500 lines (if resuming after interruption)
python scripts/generate_acp_dataset.py twitter_texts.txt --skip-lines 500 -v

# 8. Save statistics to JSON file
python scripts/generate_acp_dataset.py twitter_texts.txt \
  -o data/training.apc.txt \
  -s data/training_stats.json \
  -v

# Advanced Usage
# --------------

# Process large dataset with checkpointing
# (Process in batches, then combine)
python scripts/generate_acp_dataset.py twitter_texts.txt \
  -o data/batch_001.apc.txt \
  -n 1000 \
  --skip-lines 0 \
  -v

python scripts/generate_acp_dataset.py twitter_texts.txt \
  -o data/batch_002.apc.txt \
  -n 1000 \
  --skip-lines 1000 \
  -v

# Combine batches
cat data/batch_*.apc.txt > data/full_dataset.apc.txt


# Example Input File Format
# --------------------------
# twitter_texts.txt should contain one text per line:
#
# Зеленський провів важливі реформи для країни
# Порошенко був кращим президентом ніж поточний
# Тимошенко знову балотується на виборах
#
# (One text per line, UTF-8 encoding)


# Example Output Format
# ---------------------
# training.apc.txt will contain 3 lines per aspect:
#
# Line 1: Text with $T$ placeholder
# Line 2: Aspect term
# Line 3: Polarity (-1, 0, or 1)
#
# Example:
# Зеленський провів важливі $T$ для країни
# реформи
# 1
# Порошенко був $T$ президентом ніж поточний
# кращим
# 1


# Monitoring and Statistics
# --------------------------

# The script provides real-time progress updates:
# - Number of texts processed
# - Number of aspects extracted
# - API call count
# - Polarity distribution

# Example output:
# Processing 1000 texts from twitter_texts.txt
# Output: data/training.apc.txt
# Model: gpt-4o-mini
#
# Processing 1000/1000... (Aspects: 3457, API calls: 1000)
#
# ======================================================================
# Processing Statistics
# ======================================================================
# Total texts processed:      1000
# Successful extractions:     987
# Failed extractions:         13
# Total aspects extracted:    3457
# Total API calls:            1000
#
# Polarity Distribution:
#   Negative (-1):  1234 ( 35.7%)
#   Neutral  ( 0):   987 ( 28.6%)
#   Positive ( 1):  1236 ( 35.7%)
# ======================================================================


# Tips for Best Results
# ---------------------

# 1. Use gpt-4o-mini for cost-effective processing
#    - Faster and cheaper
#    - Good accuracy for most tasks
#
# 2. Use gpt-4o for higher quality (if budget allows)
#    - Better at detecting subtle sentiment
#    - More accurate aspect extraction
#
# 3. Set temperature between 0.1-0.3 for consistency
#    - Lower = more deterministic
#    - Higher = more varied (but less predictable)
#
# 4. Process in batches for large datasets
#    - Easier to resume if interrupted
#    - Can parallelize if needed
#
# 5. Always use -v flag to monitor progress
#    - See statistics in real-time
#    - Identify issues early
#
# 6. Save statistics to track quality
#    - Monitor polarity distribution
#    - Check success rate
#    - Identify problematic texts


# Cost Estimation
# ---------------

# Approximate costs (as of 2025):
# - gpt-4o-mini: ~$0.15 per 1M input tokens, ~$0.60 per 1M output tokens
# - gpt-4o:      ~$2.50 per 1M input tokens, ~$10.00 per 1M output tokens
#
# For 1000 texts averaging 100 tokens each:
# - Input: ~100K tokens
# - Output: ~50K tokens (aspects + formatting)
#
# Estimated cost for 1000 texts:
# - gpt-4o-mini: ~$0.03
# - gpt-4o:      ~$0.75


# Troubleshooting
# ---------------

# If you get "No API key" error:
export OPENAI_API_KEY="your-key-here"

# If you get "Rate limit exceeded":
# - Wait a few minutes
# - Use --skip-lines to resume
# - Consider upgrading your OpenAI plan

# If you get "Model not found":
# - Check you have access to the model
# - Try gpt-4o-mini instead of gpt-4o

# If many texts fail extraction:
# - Check input text quality
# - Ensure texts are political/relevant
# - Try with verbose flag to see errors

