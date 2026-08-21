import os
import sqlite3
import pandas as pd
from pydantic import BaseModel
from typing import List
from openai import OpenAI
from dotenv import load_dotenv
from tqdm import tqdm

# Load environment variables from .env file
load_dotenv()

class MotivationSentences(BaseModel):
    sentences_in_original_language: List[str]
    english_translations_of_sentences: List[str]
    motivation_summaries: List[str]

def load_messages_from_sqlite(db_path, limit=20):
    conn = sqlite3.connect(db_path)
    query = "SELECT * FROM messages ORDER BY id DESC LIMIT ?"
    df = pd.read_sql_query(query, conn, params=(limit,))
    conn.close()
    return df.iloc[::-1]  # Reverse the order to get oldest to newest

def process_message(client, message_content):
    completion = client.beta.chat.completions.parse(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a text interpreter."},
            {"role": "user", "content": f"In this text, find all the sentences that describe, state, or strongly imply the **reasons, objectives, or intentions** of specific individuals or the government as an organization. Only include sentences that:\n\n\
             - **Directly** describe or **clearly** imply **why** a specific action is being taken (e.g., motivations, goals, or incentives)\n\
             - **Exclude** sentences that only describe **what** someone is doing or **what** the outcome is, without mentioning the underlying **motivation** or **reason**\n\
             - Exclude sentences that describe changes in tactics, external assessments of events, or predictions of outcomes unless these explicitly mention **motivations** behind actions\n\
             - Avoid sentences that talk about general conditions or consequences without pointing to specific **motivations** behind the actions of individuals or the government\n\n\
            For each sentence you return, also provide a 2-5 word summary of the motivation expressed in that sentence.\n\n\
            It's OK to return no sentences at all if there are no motivations clearly expressed. Input text is in Russian or Ukrainian, and return sentences in the original language.\n\n{message_content}"}
        ],
        response_format=MotivationSentences,
    )
    return completion.choices[0].message.parsed

def main():
    db_path = 'channel_archives/rezident_ua/data.sqlite'
    df = load_messages_from_sqlite(db_path, limit=100)

    client = OpenAI()
    client.api_key = os.getenv("OPENAI_API_KEY")

    results = []

    # Add tqdm progress bar
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Processing messages"):
        if row['content']:
            response = process_message(client, row['content'])
            if response and response.sentences_in_original_language:
                results.append({
                    'message_id': row['id'],
                    'date': row['date'],
                    'original_content': row['content'],
                    'motivation_sentences': response.sentences_in_original_language,
                    'english_translations': response.english_translations_of_sentences,
                    'motivation_summaries': response.motivation_summaries
                })

    # Convert results to a DataFrame for easier handling
    results_df = pd.DataFrame(results)

    # You can save this DataFrame to a CSV file or process it further as needed
    results_df.to_csv('motivation_analysis_results.csv', index=False)

    print(f"Processed {len(df)} messages. Found motivations in {len(results)} messages.")

if __name__ == "__main__":
    main()
