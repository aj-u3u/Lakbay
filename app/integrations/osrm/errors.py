class OSRMClientError(Exception):
    def __init__(
        self,
        message: str,
        *,
        status_code: int | None = None,
        provider_code: str | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.provider_code = provider_code


class OSRMConfigurationError(OSRMClientError):
    pass


class OSRMRouteNotFoundError(OSRMClientError):
    pass
