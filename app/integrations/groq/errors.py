class GroqClientError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class GroqConfigurationError(GroqClientError):
    pass


class GroqModelUnavailableError(GroqClientError):
    pass
