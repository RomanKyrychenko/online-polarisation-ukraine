import ollama
import os
import pandas as pd
from langchain_ollama import ChatOllama
from pydantic import BaseModel, Field
from enum import Enum, IntEnum
from sqlalchemy import create_engine, text

db_url = f"postgresql://{os.environ['PGUSER']}:{os.environ['PGPASSWORD']}@{os.environ.get('PGHOST','localhost')}:{os.environ.get('PGPORT','5432')}/{os.environ.get('PGDATABASE','twitter')}"
engine = create_engine(db_url)

class Sentiment(IntEnum):
    POSITIVE = 1
    NEGATIVE = -1
    NEUTRAL = 0

class Category(Enum):
    POLITICS = "politics"  # politicians names (e.g. Zelensky, Poroshenko, etc.)
    PARTIES = "parties"  # political parties (e.g. Servant of the People, Opposition Platform - For Life, etc.)
    GEOPOL = "geopol"  # geopolitical entities (e.g. Russia, Ukraine, etc.)
    ORG = "org"  # organizations (except political parties and geopolitical entities)
    GEOPHYS = "geophys"  # geopolitical physical entities (e.g. Crimea, Donbas, etc.)
    SOCGROUPS = "socgroups"  # social groups (antivaxxers, LGBT, etc.)
    POLGROUPS = "polgroups"  # political groups (e.g. opposition, coalition, etc.)
    POLSTATUS = "polstatus"  # political status (e.g. president, prime minister, etc.)

class ABSANERResponse(BaseModel):
    category: Category = Field(
        ...,
        description=(
            "Category of the named entity. One of: "
            "POLITICS - politicians' names (e.g. Zelensky, Poroshenko, etc.); "
            "PARTIES - political parties (e.g. Servant of the People, Opposition Platform - For Life, etc.); "
            "GEOPOL - geopolitical entities (e.g. Russia, Ukraine, etc.); "
            "ORG - organizations (except political parties and geopolitical entities); "
            "GEOPHYS - geopolitical physical entities (e.g. Crimea, Donbas, etc.); "
            "SOCGROUPS - social groups (e.g. antivaxxers, LGBT, etc.); "
            "POLGROUPS - political groups (e.g. opposition, coalition, etc.); "
            "POLSTATUS - political status (e.g. president, prime minister, etc.)."
        )
    )
    mention: str = Field(..., description="Mentioned entity in the tweet (exact text)")
    label: str = Field(..., description="A short standardized name for the entity (e.g. 'Zelensky', 'Servant of the People', etc.)")
    sentiment: Sentiment = Field(..., description="Sentiment of the aspect (positive, negative, neutral)")

class Response(BaseModel):
    entities: list[ABSANERResponse] = Field(
        ...,
        description="List of named entities extracted from the tweet, each with category, mention, label, and sentiment."
                    "If there are no entities that meat the criteria for extraction, "
                    "this list will be empty."
    )

llm = ChatOllama(model="gemma3")
structured_llm = llm.with_structured_output(Response)

with engine.connect() as conn:
    df = pd.read_sql("SELECT * FROM tweets ORDER BY RANDOM() LIMIT 1000;", conn)

from tqdm import tqdm

result_list = []

for i, row in tqdm(df.iterrows(), total=len(df)):
    input_text = row['text']  # Extract the tweet text for analysis
    output = structured_llm.invoke(input=input_text)
    output = output.model_dump()
    output['input'] = input_text  # Store the original input text for position calculations

    # for every mention in output.entities define start and end position in the original text
    for entity in output['entities']:
        start = output['input'].find(entity['mention'])
        end = start + len(entity['mention'])
        if start == -1 or end == -1:
            # remove entity if mention not found in input text
            output['entities'].remove(entity)
        else:
            entity['start'] = start
            entity['end'] = end

    result_df = pd.DataFrame(output['entities'])
    result_df['id'] = row['id']  # Add the tweet ID to the result DataFrame
    result_df['input'] = output['input']  # Add the original input text to the result DataFrame

    result_list.append(result_df)

result_df = pd.concat(result_list, ignore_index=True)



# Example usage
if __name__ == "__main__":
    pass