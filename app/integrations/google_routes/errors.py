class GoogleRoutesClientError(Exception):
    def __init__(
        self,
        message: str,
        *,
        status_code: int | None = None,
        provider_code: str | None = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.provider_code = provider_code


class GoogleRoutesConfigurationError(GoogleRoutesClientError):
    pass


class GoogleRoutesQuotaError(GoogleRoutesClientError):
    pass


class GoogleRoutesRouteNotFoundError(GoogleRoutesClientError):
    pass
