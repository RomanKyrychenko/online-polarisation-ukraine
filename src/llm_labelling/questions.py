from paperqa import Settings, ask

local_llm_config = {
    "model_list": [
        {
            "model_name": "ollama/gemma3:4b",
            "litellm_params": {
                "model": "ollama/gemma3:4b",
                "api_base": "http://localhost:11434",
            },
        }
    ]
}

local_embedding_config = {
    "model_list": [
        {
            "model_name": "ollama/mxbai-embed-large",
            "litellm_params": {
                "model": "ollama/mxbai-embed-large:335m",
                "api_base": "http://localhost:11434",
            },
        }
    ]
}

answer_response = ask(
    "describe how Telegram clusters are defined",
    settings=Settings(
        llm="ollama/gemma3:4b",
        llm_config=local_llm_config,
        summary_llm="ollama/gemma3:4b",
        summary_llm_config=local_llm_config,
        paper_directory="./Russo-Ukrain Telegram",
        embedding="ollama/mxbai-embed-large:latest"
    ),
)