import httpx

from app.core.config import Settings, get_settings
from app.integrations.groq.errors import (
    GroqClientError,
    GroqConfigurationError,
    GroqModelUnavailableError,
)
from app.integrations.groq.schemas import GroqChatCompletion


class GroqClient:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def create_chat_completion(
        self,
        *,
        model: str,
        messages: list[dict[str, str]],
    ) -> GroqChatCompletion:
        if not self.settings.groq_api_key:
            raise GroqConfigurationError("GROQ_API_KEY is required.")

        payload = {
            "model": model,
            "messages": messages,
            "temperature": self.settings.groq_temperature,
            "max_tokens": self.settings.groq_max_tokens,
        }
        headers = {
            "Authorization": f"Bearer {self.settings.groq_api_key}",
            "Content-Type": "application/json",
        }
        attempts = self.settings.groq_max_retries + 1

        async with httpx.AsyncClient(
            base_url=self.settings.groq_base_url.rstrip("/"),
            timeout=self.settings.groq_request_timeout_seconds,
        ) as client:
            for attempt in range(attempts):
                try:
                    response = await client.post(
                        "/chat/completions",
                        headers=headers,
                        json=payload,
                    )
                    return self._parse_response(response)
                except GroqModelUnavailableError:
                    raise
                except GroqClientError:
                    if attempt == attempts - 1:
                        raise
                except httpx.RequestError as exc:
                    if attempt == attempts - 1:
                        raise GroqClientError(
                            "Groq request failed.",
                        ) from exc

        raise GroqClientError("Groq request failed.")

    def _parse_response(self, response: httpx.Response) -> GroqChatCompletion:
        if response.status_code in {400, 404}:
            raise GroqModelUnavailableError(
                "Configured Groq model is unavailable or rejected the request.",
                status_code=response.status_code,
            )

        if response.status_code >= 500:
            raise GroqClientError(
                "Groq service returned a server error.",
                status_code=response.status_code,
            )

        if response.status_code >= 400:
            raise GroqClientError(
                "Groq service rejected the request.",
                status_code=response.status_code,
            )

        try:
            body = response.json()
            choice = body["choices"][0]
            content = choice["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise GroqClientError("Groq response shape was not recognized.") from exc

        usage = body.get("usage") or {}

        return GroqChatCompletion(
            content=content,
            model=body.get("model") or "",
            prompt_tokens=usage.get("prompt_tokens"),
            completion_tokens=usage.get("completion_tokens"),
            total_tokens=usage.get("total_tokens"),
        )


def get_groq_client() -> GroqClient:
    return GroqClient()
