# %%
import pickle
import numpy as np
import pandas as pd
from tqdm import tqdm
import umap
import hdbscan
import plotly.express as px
from plotly.subplots import make_subplots
import plotly.graph_objects as go

# %%
# Load the embeddings with strings
with open('motivation_summary_embeddings_with_strings.pkl', 'rb') as f:
    embeddings_with_strings = pickle.load(f)

# %%
# Flatten the list of lists and separate strings and embeddings
all_strings = []
all_embeddings = []
for row in embeddings_with_strings:
    for string, embedding in row:
        all_strings.append(string)
        all_embeddings.append(embedding)

# Convert to numpy array for faster processing
all_embeddings = np.array(all_embeddings)

# %%
# Perform UMAP dimensionality reduction
print("Performing UMAP dimensionality reduction...")
umap_reducer = umap.UMAP(n_components=20, random_state=42)
umap_embeddings = umap_reducer.fit_transform(all_embeddings)

# %%
# Perform HDBSCAN clustering
print("Performing HDBSCAN clustering...")
clusterer = hdbscan.HDBSCAN(
    min_cluster_size=2,        # Reduced to the minimum possible value
    min_samples=1,             # Reduced to the minimum possible value
    cluster_selection_epsilon=0.1,  # Reduced to allow for tighter clusters
    cluster_selection_method='eom',  # 'eom' tends to produce more clusters than 'leaf'
    metric='euclidean',        # Explicitly set the metric
    cluster_selection_epsilon=0.0,  # Set to 0 to disable single linkage pruning
    allow_single_cluster=True  # Allow the algorithm to find a single cluster if that's the best fit
)
cluster_labels = clusterer.fit_predict(umap_embeddings)

# Print cluster information
unique_clusters = np.unique(cluster_labels)
print(f"Number of clusters: {len(unique_clusters[unique_clusters != -1])}")
print(f"Number of noise points: {np.sum(cluster_labels == -1)}")

# Print the distribution of points in clusters
cluster_sizes = pd.Series(cluster_labels).value_counts().sort_index()
print("Cluster distribution:")
print(cluster_sizes)

# %%
# Prepare data for visualization
umap_2d = umap.UMAP(n_components=2, random_state=42).fit_transform(umap_embeddings)

df_viz = pd.DataFrame({
    'UMAP1': umap_2d[:, 0],
    'UMAP2': umap_2d[:, 1],
    'Cluster': cluster_labels,
    'Text': all_strings
})

# %%
# Create an interactive scatter plot
fig = px.scatter(
    df_viz, x='UMAP1', y='UMAP2', color='Cluster', hover_data=['Text'],
    title='Clustered Motivation Summaries',
    labels={'Cluster': 'Cluster Label'},
    color_discrete_sequence=px.colors.qualitative.Set1,  # Use a discrete color scale
    category_orders={'Cluster': sorted(df_viz['Cluster'].unique())}  # Sort cluster labels
)

# Update hover template to show full text
fig.update_traces(
    hovertemplate='<b>Cluster:</b> %{marker.color}<br><b>Text:</b> %{customdata[0]}<extra></extra>'
)

# Update layout for better readability
fig.update_layout(
    legend_title_text='Cluster',
    legend=dict(itemsizing='constant', title_font=dict(size=14), font=dict(size=12))
)

# %%
# Save the interactive plot as an HTML file
fig.write_html("motivation_clusters_visualization.html")
print("Interactive visualization saved as motivation_clusters_visualization.html")

# %%
# Optionally, save the clustered data for further analysis
df_viz.to_csv('clustered_motivation_summaries.csv', index=False)
print("Clustered data saved as clustered_motivation_summaries.csv")