#/Volumes/PRO-G40/fast_lcf_bert_politics_acc_92.86_f1_87.95

from pyabsa import AspectPolarityClassification as APC
from sqlalchemy import create_engine, text
import pandas as pd
import yaml
import re
import tempfile
import os
import gc

# Load entities from YAML file
with open('entities.yaml', 'r', encoding='utf-8') as f:
    entities_config = yaml.safe_load(f)

# Initialize sentiment classifier
sentiment_classifier = APC.SentimentClassifier(
    checkpoint="checkpoints/fast_lcf_bert_politics_acc_92.86_f1_87.95"
)

# Set up the database connection
engine = create_engine(
    f"postgresql://{os.environ['PGUSER']}:{os.environ['PGPASSWORD']}@{os.environ.get('PGHOST','localhost')}:{os.environ.get('PGPORT','5432')}/{os.environ.get('PGDATABASE','twitter')}"
)

# Define chunk size for processing
CHUNK_SIZE = 200000  # Process 1000 tweets at a time
BATCH_SIZE = 2048    # Batch size for predictions

# Process each target iteratively
for target_name, variations_str in entities_config.items():
    print(f"\nProcessing target: {target_name}")

    # Prepare variations for this target
    variations = [v.strip() for v in variations_str.split(',') if v.strip()]
    escaped_variations = [re.escape(v) for v in variations]

    # Create PostgreSQL regex pattern for this target
    postgres_pattern = '\\m(' + '|'.join(escaped_variations) + ')\\M'

    # Count total tweets for this target
    with engine.connect() as conn:
        count_query = text("SELECT COUNT(*) FROM tweets WHERE text ~* :pattern")
        total_tweets = conn.execute(count_query, {'pattern': postgres_pattern}).scalar()

    print(f"Found {total_tweets} tweets for {target_name}")

    if total_tweets == 0:
        continue

    # Process tweets in chunks
    offset = 0
    while offset < total_tweets:
        # Query the database for a chunk of tweets
        with engine.connect() as conn:
            query = text("""
                SELECT id, text, created_at, author_id 
                FROM tweets 
                WHERE text ~* :pattern 
                ORDER BY id 
                LIMIT :limit OFFSET :offset
            """)
            tweets_df = pd.read_sql(query, conn, params={
                'pattern': postgres_pattern,
                'limit': CHUNK_SIZE,
                'offset': offset
            })

        if len(tweets_df) == 0:
            break

        print(f"Processing chunk {offset}-{offset + len(tweets_df)} for {target_name}")

        # Prepare marked tweets
        marked_tweets = []
        tweet_ids = []

        for _, row in tweets_df.iterrows():
            tweet_text = row['text']
            tweet_id = row['id']

            # Find which variation is present in this tweet
            found_variation = None
            for variation in variations:
                if re.search(r'\b' + re.escape(variation) + r'\b', tweet_text, re.IGNORECASE):
                    found_variation = variation
                    break

            if found_variation:
                # Wrap the entity variation with aspect markers
                marked_text = re.sub(
                    r'\b(' + re.escape(found_variation) + r')\b',
                    r'[B-ASP]\1[E-ASP]',
                    tweet_text,
                    flags=re.IGNORECASE
                )
                # Normalize whitespace: replace newlines and multiple spaces with single space
                marked_text = ' '.join(marked_text.split())
                # Skip if the result is empty after normalization
                if marked_text.strip():
                    marked_tweets.append(marked_text)
                    tweet_ids.append(row)

        # Clear the dataframe to free memory
        del tweets_df
        gc.collect()

        if len(marked_tweets) == 0:
            offset += CHUNK_SIZE
            continue

        # Create temporary file with marked tweets
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt', encoding='utf-8') as temp_file:
            # Join with newlines, ensuring no empty lines
            temp_file.write('\n'.join(marked_tweets))
            temp_file_path = temp_file.name

        try:
            # Perform batch prediction
            batch_results = sentiment_classifier.batch_predict(
                target_file=temp_file_path,
                print_result=False,
                save_result=False,
                ignore_error=True,
                eval_batch_size=BATCH_SIZE,
            )

            # Process batch results
            results = []
            for i, prediction in enumerate(batch_results):
                if i >= len(tweet_ids):
                    break

                row = tweet_ids[i]
                sentiment = prediction['probs'][0]

                results.append({
                    'id': row['id'],
                    'target': target_name,
                    'date': row['created_at'],
                    'author_id': row['author_id'],
                    'negative': sentiment[0],
                    'neutral': sentiment[1],
                    'positive': sentiment[2]
                })

            print(f"Generated {len(results)} predictions for chunk")

            # Write results immediately to database
            if len(results) > 0:
                results_df = pd.DataFrame(results)
                with engine.connect() as conn:
                    results_df.to_sql('tweet_sentiment_apc', conn, if_exists='append', index=False)
                print(f"Successfully wrote {len(results_df)} records")

                # Clear results to free memory
                del results_df
                del results

        finally:
            # Clean up temporary file
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)

            # Clear variables and force garbage collection
            del marked_tweets
            del tweet_ids
            gc.collect()

        # Increment offset after processing chunk
        offset += CHUNK_SIZE

print("\nProcessing complete!")
