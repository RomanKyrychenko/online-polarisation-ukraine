import os
import sys
from pydantic import BaseModel
from typing import Literal, List
from openai import OpenAI


class Entity(BaseModel):
    entity_name: str
    entity_type: Literal['Organisation', 'Person', 'Location']

class NERResponse(BaseModel):
    entities: list[Entity]

input =	sys.stdin.read()

client = OpenAI()
client.api_key = os.getenv("OPENAI_API_KEY")

completion = client.beta.chat.completions.parse(
    model="gpt-4o-2024-08-06",
    messages=[
        {"role": "system", "content": "You are a text interpreter."},
        {"role": "user", "content": f"Could you make a list of all the locations, named individuals and organisations in this text?\n\n{input}"},
    ],
    response_format=NERResponse,
)

message = completion.choices[0].message
import pdb;pdb.set_trace()
#if message.parsed:
#    print(message.parsed.steps)
#    print(message.parsed.final_answer)
#else:
#    print(message.refusal)
