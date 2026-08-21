#!pip install sqlalchemy psycopg2-binary pgvector sentence-transformers
import os
from sqlalchemy import create_engine, text, Integer
from sentence_transformers import SentenceTransformer
from pgvector.sqlalchemy import Vector
from sqlalchemy.orm import mapped_column, DeclarativeBase, Session
from sqlalchemy.exc import IntegrityError

class Base(DeclarativeBase):
    pass

class Item(Base):
    __tablename__ = 'tweet_embeddings'
    id = mapped_column(Integer, primary_key=True)
    embedding = mapped_column(Vector(768))

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
        with engine.connect() as connection:
            # Fetch tweets with text and timestamps
            query = text(f"""
                SELECT t.text, t.created_at, t.id
                FROM public.tweets t
                LEFT JOIN tweet_embeddings e ON CAST(t.id AS bigint) = e.id
                WHERE t.text IS NOT NULL AND LENGTH(t.text) > 10 AND e.id IS NULL
                LIMIT {limit}
            """)
            result = connection.execute(query)
            data = [(row[0], row[1], row[2]) for row in result]

            if not data:
                raise ValueError("No data retrieved from database")

            docs = [row[0] for row in data]
            timestamps = [row[1] for row in data]
            ids = [row[2] for row in data]
            return docs, timestamps, ids

    except Exception as e:
        print(f"Database error: {str(e)}")
        return [], [], []

# Fetch data
docs, _, ids = fetch_data(limit=500)
print(f"Retrieved {len(docs)} documents")

# split the data into smaller chunks
def split_list(lst, chunk_size):
    for i in range(0, len(lst), chunk_size):
        yield lst[i:i + chunk_size]

# Split the documents into smaller chunks
chunk_size = 100000
chunks = list(split_list(docs, chunk_size))
# Split the IDs into smaller chunks
id_chunks = list(split_list(ids, chunk_size))

# Initialize embedding model
embedding_model = SentenceTransformer("sentence-transformers/LaBSE", device='mps')

# Process chunks separately to save memory
for chunk_index, (doc_chunk, id_chunk) in enumerate(zip(chunks, id_chunks)):
    print(f"Processing chunk {chunk_index + 1}/{len(chunks)}")

    # Generate embeddings for this chunk only
    chunk_embeddings = embedding_model.encode(doc_chunk, show_progress_bar=True, batch_size=100)

    # Insert embeddings into database
    with Session(engine) as session:
        # Prepare batch of records for bulk insert
        batch_size = 100000
        items_to_add = []

        # First identify which IDs already exist in the database to avoid duplicates
        # Convert string IDs to integers for comparison
        ids_as_integers = [int(id_str) for id_str in id_chunk]
        existing_ids_query = text("SELECT id FROM tweet_embeddings WHERE id = ANY(:ids)")
        existing_ids = set(row[0] for row in session.execute(
            existing_ids_query, {"ids": ids_as_integers}
        ).fetchall())

        # Process embeddings in batches
        for i, (doc_id, embedding) in enumerate(zip(id_chunk, chunk_embeddings)):
            doc_id_int = int(doc_id)  # Convert string ID to integer
            if doc_id_int not in existing_ids:
                items_to_add.append(Item(id=doc_id_int, embedding=embedding.tolist()))

            # Bulk insert when batch size is reached
            if len(items_to_add) >= batch_size or i == len(id_chunk) - 1:
                if items_to_add:
                    try:
                        session.bulk_save_objects(items_to_add)
                        session.commit()
                        print(f"Bulk inserted {len(items_to_add)} embeddings (processed {i+1}/{len(chunk_embeddings)})")
                        items_to_add = []  # Reset batch
                    except Exception as e:
                        session.rollback()
                        print(f"Error in bulk insert: {str(e)}")
                        # Fallback to individual inserts if bulk fails
                        for item in items_to_add:
                            try:
                                session.add(item)
                                session.commit()
                            except IntegrityError:
                                session.rollback()
                                print(f"Skipping duplicate ID: {item.id}")
                            except Exception as e:
                                session.rollback()
                                print(f"Error processing ID {item.id}: {str(e)}")
                        items_to_add = []

        print(f"Chunk {chunk_index + 1}/{len(chunks)} completed")
print("All embeddings processed")