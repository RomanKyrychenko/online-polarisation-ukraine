# %%
import pandas as pd
import numpy as np
from sentence_transformers import SentenceTransformer
from tqdm import tqdm
import pickle

# %%
# Load the CSV file
df = pd.read_csv('motivation_analysis_results.csv')
print(f"Loaded {len(df)} rows from motivation_analysis_results.csv")

# %%
# Load the BERT model
model = SentenceTransformer('all-mpnet-base-v2')
print("Loaded SentenceTransformer model: all-mpnet-base-v2")

# %%
# Embed the motivation summaries
embeddings_with_strings = []
for summary in tqdm(df['motivation_summaries'], desc="Processing summaries"):
    # Check if the summary is a string (some might be NaN)
    if isinstance(summary, str):
        # Split the summary string into a list of summaries
        summary_list = eval(summary)
        # Embed each summary in the list with a nested tqdm
        summary_embeddings = [model.encode(s) for s in tqdm(summary_list, desc="Encoding sentences", leave=False)]
        # Store both the original strings and their embeddings
        embeddings_with_strings.append(list(zip(summary_list, summary_embeddings)))
    else:
        # If the summary is NaN, append an empty list
        embeddings_with_strings.append([])

print(f"Created embeddings for {len(embeddings_with_strings)} rows")

# %%
# Save the embeddings with their corresponding strings
with open('motivation_summary_embeddings_with_strings.pkl', 'wb') as f:
    pickle.dump(embeddings_with_strings, f)
print("Saved embeddings with strings to motivation_summary_embeddings_with_strings.pkl")

# %%
# Optionally, you can also save the embeddings back to the CSV file
df['embeddings_with_strings'] = embeddings_with_strings
df.to_csv('motivation_analysis_results_with_embeddings.csv', index=False)
print("Saved results with embeddings to motivation_analysis_results_with_embeddings.csv")