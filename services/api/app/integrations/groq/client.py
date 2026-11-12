import asyncio

import httpx

from app.core.config import Settings, get_settings
from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import ProviderLimiter
from app.integrations.groq.errors import (
    GroqClientError,
    GroqConfigurationError,
    GroqModelUnavailableError,
    GroqRateLimitError,
)


_groq_model_limiter = ProviderLimiter()
from app.integrations.groq.schemas import GroqChatCompletion


class GroqClient:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def create_chat_completion(
        self,
        *,
        model: str,
        messages: list[dict[str, str]],
        response_format: dict | None = None,
        provider: str = "groq",
    ) -> GroqChatCompletion:
        if provider == "fallback_llm":
            api_key = self.settings.fallback_llm_api_key
            base_url = self.settings.fallback_llm_base_url
            per_minute = self.settings.fallback_llm_requests_per_minute
            per_day = self.settings.fallback_llm_requests_per_day
            missing_key_message = "FALLBACK_LLM_API_KEY is required."
        else:
            api_key = self.settings.groq_api_key
            base_url = self.settings.groq_base_url
            per_minute = self.settings.groq_model_requests_per_minute
            per_day = self.settings.groq_model_requests_per_day
            missing_key_message = "GROQ_API_KEY is required."
        if not api_key:
            raise GroqConfigurationError(missing_key_message)

        payload = {
            "model": model,
            "messages": messages,
            "temperature": self.settings.groq_temperature,
            "max_tokens": self.settings.groq_max_tokens,
        }
        if response_format is not None:
            payload["response_format"] = response_format
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        attempts = self.settings.groq_max_retries + 1

        async with httpx.AsyncClient(
            base_url=base_url.rstrip("/"),
            timeout=self.settings.groq_request_timeout_seconds,
        ) as client:
            for attempt in range(attempts):
                try:
                    try:
                        _groq_model_limiter.reserve_many(
                            [
                                (f"{provider}:model:{model}:minute", per_minute, 60, 1),
                                (f"{provider}:model:{model}:day", per_day, 86400, 1),
                            ],
                            code="groq_model_rate_limit_exceeded",
                            message="Groq model is busy. Please try again shortly.",
                        )
                    except LakbayAPIError as exc:
                        raise GroqRateLimitError(
                            exc.message,
                            retry_after_seconds=exc.details["retry_after_seconds"],
                        ) from exc
                    response = await client.post(
                        "/chat/completions",
                        headers=headers,
                        json=payload,
                    )
                    return self._parse_response(response)
                except GroqModelUnavailableError:
                    raise
                except GroqRateLimitError as exc:
                    # Sleep through short waits so brief bursts don't surface as errors.
                    if (
                        exc.retry_after_seconds <= self.settings.groq_rate_limit_max_wait_seconds
                        and attempt < attempts - 1
                    ):
                        await asyncio.sleep(exc.retry_after_seconds)
                        continue
                    raise
                except GroqClientError as exc:
                    if exc.status_code is not None and exc.status_code < 500:
                        raise
                    if attempt == attempts - 1:
                        raise
                except httpx.RequestError as exc:
                    if attempt == attempts - 1:
                        raise GroqClientError(
                            "Groq request failed.",
                        ) from exc

        raise GroqClientError("Groq request failed.")

    def _parse_response(self, response: httpx.Response) -> GroqChatCompletion:
        if response.status_code == 429:
            raw_retry_after = response.headers.get("retry-after", "60")
            try:
                retry_after = max(1, int(raw_retry_after))
            except ValueError:
                retry_after = 60
            raise GroqRateLimitError(
                "Groq rate limit reached. Please try again shortly.",
                retry_after_seconds=retry_after,
            )
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
