from pgvector.sqlalchemy import Vector
import os
from sqlalchemy import create_engine, text, Column, Integer, String
from sqlalchemy.orm import declarative_base, Session
from sentence_transformers import SentenceTransformer

# Database connection details
user = 'propaganda_tutkija'
password = os.environ['PGPASSWORD']|p)urra.'
host = '18.188.52.15'
port = 5432
database = 'twitter'

# Create a connection string
connection_string = f'postgresql://{user}:{password}@{host}:{port}/{database}'
engine = create_engine(connection_string)

# Define base and model
Base = declarative_base()


class Document(Base):
    __tablename__ = 'documents'

    id = Column(Integer, primary_key=True)
    content = Column(String)
    embedding = Column(Vector(768))


# Initialize embedding model
model = SentenceTransformer("sentence-transformers/LaBSE")


def hybrid_search(query_text, limit=5):
    """
    Perform hybrid search combining semantic and keyword search using RRF

    Args:
        query_text: The search query text
        limit: Number of results to return

    Returns:
        List of (document_id, score) tuples
    """
    # Generate embedding for the query
    query_embedding = model.encode(query_text)

    # Execute hybrid search
    with engine.connect() as conn:
        sql = """
        SELECT id FROM tweet_embeddings ORDER BY embedding <=> :embedding LIMIT :limit
        """

        result = conn.execute(
            text(sql),
            {
                "embedding": str(query_embedding.tolist()),
                "limit": limit
            }
        ).fetchall()

        return [row[0] for row in result]


def main():
    # Uncomment to create tables and sample data
    # create_tables()
    # insert_sample_documents()

    # Perform a search
    query = 'growling bear'
    results = hybrid_search(query)

    # Fetch the actual documents to display content
    with Session(engine) as session:
        for doc_id, score in results:
            doc = session.query(Document).filter(Document.id == doc_id).first()
            print(f"Document ID: {doc_id}, Score: {score}")
            print(f"Content: {doc.content[:100]}...")
            print("-" * 50)


if __name__ == "__main__":
    main()