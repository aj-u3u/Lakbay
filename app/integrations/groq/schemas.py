from pydantic import BaseModel


class GroqChatMessage(BaseModel):
    role: str
    content: str


class GroqChatCompletion(BaseModel):
    content: str
    model: str
    prompt_tokens: int | None = None
    completion_tokens: int | None = None
    total_tokens: int | None = None
