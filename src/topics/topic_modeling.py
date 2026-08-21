#! sudo apt update && sudo apt install pciutils lshw
import os
#!curl -fsSL https://ollama.com/install.sh | sh
#!nohup ollama serve > ollama.log 2>&1 &
#! ollama run gemma3:1b “What is the capital of the Netherlands? Return only one word”
#! pip install ollama
#!pip install bertopic
#!pip install cudf-cu11 dask-cudf-cu11 --extra-index-url=https://pypi.nvidia.com
#!pip install cuml-cu11 --extra-index-url=https://pypi.nvidia.com
#!pip install cugraph-cu11 --extra-index-url=https://pypi.nvidia.com
#!pip install --upgrade cupy-cuda11x -f https://pip.cupy.dev/aarch64
import numpy as np
from bertopic import BERTopic
import openai
from sqlalchemy import create_engine, func, ForeignKeyConstraint, Integer, String, ARRAY
from bertopic.representation import OpenAI
from sklearn.feature_extraction.text import CountVectorizer
from stop_words import get_stop_words
import gc
import pandas as pd
from sqlalchemy.orm import mapped_column, DeclarativeBase, Session
from pgvector.sqlalchemy import Vector


class Base(DeclarativeBase):
    pass

class TweetEmbedding(Base):
    __tablename__ = 'tweet_embeddings'
    id = mapped_column(Integer, primary_key=True)
    embedding = mapped_column(Vector(768))

class Tweet(Base):
    __tablename__ = 'tweets'
    id = mapped_column(String, primary_key=True)
    lang = mapped_column(String)
    conversation_id = mapped_column(String)
    text = mapped_column(String)
    possibly_sensitive = mapped_column(String)
    in_reply_to_user_id = mapped_column(String)
    created_at = mapped_column(String)
    author_id = mapped_column(String)
    retweet_count = mapped_column(Integer)
    reply_count = mapped_column(Integer)
    like_count = mapped_column(Integer)
    quote_count = mapped_column(Integer)
    impression_count = mapped_column(Integer)
    source = mapped_column(String)


user = 'propaganda_tutkija'
password = os.environ['PGPASSWORD']|p)urra.'
host = '3.144.131.235'
port = 5432
database = 'twitter'
# Create a connection string
connection_string = f'postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}'
# Create database connection
engine = create_engine(connection_string)

# Fetch data with proper error handling
def fetch_data(limit=10000):
    try:
        query = (
            Session(engine)
            .query(
                Tweet.text,
                Tweet.created_at,
                Tweet.id,
                TweetEmbedding.embedding
            )
            .outerjoin(TweetEmbedding, Tweet.id == func.cast(TweetEmbedding.id, String))
            .filter(Tweet.text.isnot(None))
            .filter(func.length(Tweet.text) > 10)
            .filter(TweetEmbedding.embedding.isnot(None))
            .limit(limit)
        )

        with Session(engine) as session:
            result = query.with_session(session).all()
            data = [(row.text, row.created_at, row.id, row.embedding) for row in result]

        if not data:
            raise ValueError("No data retrieved from database")

        docs = [row[0] for row in data]
        timestamps = [row[1] for row in data]
        ids = [row[2] for row in data]
        embeddings = [row[3] for row in data]
        return docs, timestamps, ids, embeddings

    except Exception as e:
        print(f"Database error: {str(e)}")
        return [], [], [], []

# Fetch data
docs, timestamps, ids, embeddings = fetch_data(limit=50000)
print(f"Retrieved {len(docs)} documents")

# Configure OpenAI client (using local Ollama)
client = openai.OpenAI(
    base_url='http://localhost:11434/v1',
    api_key='ollama',
)

# Create a custom representation model with better prompting
representation_model = OpenAI(
    client=client,
    model="gemma3:1b",
    #topic_dim=10,
    prompt="""
    I have a list of documents related to these keywords: [KEYWORDS].
    
    Also I have a list of documents related to these keywords: [DOCUMENTS].

    Based on these keywords, provide a clear, concise topic label that
    represents the overall theme. The topic label should be 1-5 words.
    
    Return results in English, and do not include any other text or formatting.
    Return only the topic label, without any additional information.
    """,
    diversity=0.8,
    nr_docs=5
)

# Define more comprehensive zero-shot topics
zeroshot_topic_list = [
    "Ukrainian Politics",
    "Elections",
    "COVID-19",
    "Russian Invasion",
    "Poroshenko",
    "Zelensky",
    "Economy",
    "Putin",
    "Medvedchuk",
    "Vaccination"
]

stop_words = get_stop_words('en')
stop_words.extend(get_stop_words('ru'))
stop_words.extend(get_stop_words('uk'))

# Configure better vectorizer for improved topic representation
vectorizer_model = CountVectorizer(
    stop_words=stop_words,
    max_features=10_000
)

# Use GPU-accelerated UMAP if CUDA is available
try:
    from cuml.manifold import UMAP
    print("Using CUDA-accelerated UMAP")
    umap_model = UMAP(n_neighbors=15, n_components=2, min_dist=0.5, metric='cosine')
except (ImportError, ModuleNotFoundError):
    print("CUDA not available for UMAP, using CPU UMAP")
    from umap import UMAP
    umap_model = UMAP(n_neighbors=15, n_components=2, min_dist=0.5, metric='cosine')
# Use GPU-accelerated HDBSCAN if CUDA is available
try:
    import cuml
    from cuml.cluster import HDBSCAN
    print("Using CUDA-accelerated HDBSCAN")
    hdbscan_model = HDBSCAN(min_cluster_size=15, metric='euclidean',
                           cluster_selection_method='leaf', prediction_data=True)
except (ImportError, ModuleNotFoundError):
    print("CUDA not available, using CPU HDBSCAN")
    from hdbscan import HDBSCAN
    hdbscan_model = HDBSCAN(min_cluster_size=15, metric='euclidean',
                           cluster_selection_method='leaf', prediction_data=True)

# Create topic model with improved parameters
topic_model = BERTopic(
    vectorizer_model=vectorizer_model,
    umap_model=umap_model,
    hdbscan_model = hdbscan_model,
    min_topic_size=20,
    #nr_topics="auto",
    calculate_probabilities=True,
    zeroshot_topic_list=zeroshot_topic_list,
    zeroshot_min_similarity=0.7,
    representation_model=representation_model,
    top_n_words=15,
    verbose=True
)

embeddings = np.array(embeddings)

# Fit the model
topics, probs = topic_model.fit_transform(docs, embeddings=embeddings)

# garbage collection
gc.collect()

print("\n--- Topic Model Results ---")
print(f"Found {len(topic_model.get_topic_info())} topics")

# Display topic info
topic_info = topic_model.get_topic_info()
print("\nTop 10 Topics by Size:")
print(topic_info.head(10)[["Topic", "Name", "Count"]])

class Topic(Base):
    __tablename__ = 'topics'
    topic_id = mapped_column(Integer, primary_key=True, autoincrement=True)
    topic_name = mapped_column(String, nullable=False)
    topic_description = mapped_column(String, nullable=True)
    topic_keywords = mapped_column(ARRAY(String), nullable=True)

class TweetTopic(Base):
    __tablename__ = 'tweet_topics'
    tweet_id = mapped_column(Integer, primary_key=True)
    topic_id = mapped_column(Integer, primary_key=True)
    __table_args__ = (
        ForeignKeyConstraint(['tweet_id'], ['tweet_embeddings.id']),
        ForeignKeyConstraint(['topic_id'], ['topics.topic_id']),
    )

# write topics to database, use these models
with Session(engine) as session:
    for index, row in topic_info.iterrows():
        topic = Topic(
            topic_id=row['Topic'],
            topic_name=row['Name'],
            topic_description=topic_model.get_topic(row['Topic']),
            topic_keywords=topic_model.get_topic(row['Topic'])
        )
        session.add(topic)
    session.commit()







# Generate hierarchical topics with better parameters
hierarchical_topics = topic_model.hierarchical_topics(
    docs
)

# Visualize hierarchical topics
topic_model.visualize_hierarchy(hierarchical_topics=hierarchical_topics)
# hierarchical_viz.write_html("hierarchical_topics.html")  # Uncomment to save visualization

tree = topic_model.get_topic_tree(hierarchical_topics)
print(tree)

# Convert timestamps to numeric format (e.g., Unix timestamps)
numeric_timestamps = pd.to_datetime(timestamps, utc=True)

topics_over_time = topic_model.topics_over_time(
    docs,
    numeric_timestamps,
    nr_bins=15,
    global_tuning=True,
    evolution_tuning=True,
)

# Visualize topics over time
time_viz = topic_model.visualize_topics_over_time(
    topics_over_time,
    top_n_topics=10,
    width=1200,
    height=600
)

time_viz.write_html("topics_over_time.html")  # Uncomment to save visualization

# Create topic similarity network for better topic relationship understanding
similarity_viz = topic_model.visualize_topics(
    topics=topic_model.get_topic_info()["Topic"].tolist()[1:11],
    width=800,
    height=800
)

similarity_viz.write_html("topic_similarity.html")  # Uncomment to save visualization

# Extract insights from the model
print("\n--- Topic Analysis ---")

# Top documents per topic
print("\nExample document for top topics:")
for topic_id in topic_info.head(5)["Topic"].tolist():
    if topic_id == -1:  # Skip outlier topic
        continue
    docs_for_topic = topic_model.get_representative_docs(topic_id)
    if docs_for_topic:
        print(
            f"Topic {topic_id} ({topic_model.get_topic_info().loc[topic_model.get_topic_info()['Topic'] == topic_id, 'Name'].values[0]}):")
        print(f"  - {docs_for_topic[0][:100]}...")

print("\nTopic Distribution:")
topic_distribution = topic_model.get_topic_info()["Count"] / len(docs) * 100
print(f"Classified Topics: {sum(topic_distribution[1:]):.1f}%")
print(f"Outliers: {topic_distribution[0]:.1f}%")

# Save model if needed
topic_model.save("twitter_topic_model")

# save topics to database
topic_info.to_csv("topics.csv", index=False)

# document probabilities
# for every document, get the topic with the highest probability
doc_probs = pd.DataFrame({
    "document": ids,
    "topic": [topic_model.get_topic_info().loc[topic_model.get_topic_info()["Topic"] == topic_id, "Topic"].values[0] for topic_id in topics],
    "probability": [max(prob) for prob in probs]
})

doc_probs.to_csv("document_probabilities.csv", index=False)