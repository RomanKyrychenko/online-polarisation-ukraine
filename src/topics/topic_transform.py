from bertopic import BERTopic
import os
from sqlalchemy import create_engine, Integer, String, ARRAY, ForeignKeyConstraint, bindparam, insert
from sqlalchemy.orm import mapped_column, DeclarativeBase, Session
from pgvector.sqlalchemy import Vector
import numpy as np
from tqdm import tqdm

user = 'propaganda_tutkija'
password = os.environ['PGPASSWORD']|p)urra.'
host = '18.188.52.15'
port = 5432
database = 'twitter'
# Create a connection string with connection pooling
connection_string = f'postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}'
# Create database connection with pooling
engine = create_engine(connection_string, pool_size=10, max_overflow=20)


class Base(DeclarativeBase):
    pass


class TweetEmbedding(Base):
    __tablename__ = 'tweet_embeddings'
    id = mapped_column(Integer, primary_key=True)
    embedding = mapped_column(Vector(768))


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


# Load model once
model = BERTopic.load("../bertopic_model_safe")
topic_info = model.get_topic_info()


def process_batch(batch):
    """Process a batch of embeddings"""
    ids, embeddings = batch
    # Use a placeholder text since we're using embeddings for prediction
    placeholder_docs = ["placeholder"] * len(embeddings)
    topics, _ = model.transform(placeholder_docs, np.array(embeddings))
    # Return list of (tweet_id, topic_id) pairs
    return [(int(i), int(t)) for i, t in zip(ids, topics)]


# Clean the TweetTopic table
#with Session(engine) as session:
#    if session.query(TweetTopic).count() > 0:
#        session.execute(TweetTopic.__table__.delete())
#        session.commit()
#        print("TweetTopic table cleaned.")

# Process embeddings in batches
batch_size = 100000
with Session(engine) as session:
    # Process in batches with a more efficient approach
    with tqdm(desc="Processing embeddings") as pbar:
        offset = 0
        while True:
            # Use an anti-join pattern instead of notin_
            query = (
                session.query(TweetEmbedding.id, TweetEmbedding.embedding)
                .outerjoin(
                    TweetTopic,
                    TweetEmbedding.id == TweetTopic.tweet_id
                )
                .filter(TweetTopic.tweet_id.is_(None))
                .limit(batch_size)
                .offset(offset)
            )
            results = query.all()

            if not results:
                break

            ids = [r[0] for r in results]
            embeddings = [r[1] for r in results]

            # Process batch directly
            batch_data = (ids, embeddings)
            tweet_topics = process_batch(batch_data)

            # Bulk insert results
            if tweet_topics:
                # Faster bulk insert with SQLAlchemy's core API
                session.execute(
                    insert(TweetTopic),
                    [{"tweet_id": tt[0], "topic_id": tt[1]} for tt in tweet_topics]
                )

                try:
                    session.commit()
                except Exception as e:
                    session.rollback()
                    print(f"Error inserting data: {e}")

            offset += len(ids)
            pbar.update(len(ids))
            pbar.set_postfix({"processed": offset})