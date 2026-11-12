# Provider usage controls

Lakbay applies conservative controls before calling OpenWeather, Groq, and
Cloudinary. They run locally with one worker or use Redis as a shared store when
`PROVIDER_USAGE_REDIS_URL` is configured. They are not a mirror of each
provider's complete billing system. API keys stay on the server.

## Current behavior

| Provider | Guard | Default | Where it runs |
| --- | --- | --- | --- |
| OpenWeather | Outbound calls per minute | 45 | `WeatherService._openweather_get` |
| OpenWeather | Outbound calls per rolling 30 days | 100000 | `WeatherService._openweather_get` |
| OpenWeather | Successful current-weather cache | 600 seconds | `WeatherService._openweather_get` |
| OpenWeather | Successful forecast cache | 3600 seconds | `WeatherService._openweather_get` |
| Groq | AI attempts per user per minute | 20 | `AIItineraryService` before each model run |
| Groq | Outbound attempts per model per minute | 2 | `GroqClient` before each HTTP attempt |
| Groq | Outbound attempts per model per rolling day | 100 | `GroqClient` before each HTTP attempt |
| Cloudinary | Valid upload attempts per user per 24 hours | 10 | `MemoryService.upload_image` |
| Cloudinary | Valid upload attempts app-wide per 24 hours | 50 | `MemoryService.upload_image` |

Configure the values in `.env` using `OPENWEATHER_REQUESTS_PER_MINUTE`,
`OPENWEATHER_REQUESTS_PER_30_DAYS`, `OPENWEATHER_CURRENT_CACHE_SECONDS`,
`OPENWEATHER_FORECAST_CACHE_SECONDS`, `GROQ_USER_REQUESTS_PER_MINUTE`,
`GROQ_MODEL_REQUESTS_PER_MINUTE`, `GROQ_MODEL_REQUESTS_PER_DAY`,
`CLOUDINARY_UPLOADS_PER_USER_DAY`, and `CLOUDINARY_UPLOADS_PER_APP_DAY`. See
`.env.example` for defaults. Restart the API after changing `.env`.

Weather cache keys include the provider base URL, endpoint, exact coordinates,
units, language, and forecast count. A forecast request uses current weather and
forecast data, so an uncached forecast normally costs two OpenWeather calls.
Only successful JSON responses are cached. A cache hit makes no provider call
and does not consume the outbound call allowance.

Groq comparisons count each selected model attempt separately. An HTTP 429 from
Groq is returned to the API caller as HTTP 429 with `Retry-After`; it is not
retried immediately. Other transient server or network errors still follow
`GROQ_MAX_RETRIES`, and each retry counts toward the model call guard. Existing
`ai_generation_runs` records model and token usage returned by Groq.

Memory upload authorization and file validation run before the upload guard.
The user and app allowances are reserved together, so rejection by one does not
consume the other. The existing image size limit is 5 MB. A rejected request
returns HTTP 429 with `Retry-After` and never calls Cloudinary.

## Shared store and billing limits

With `PROVIDER_USAGE_REDIS_URL` blank, counters and cache entries live in one
Python process, reset on restart, and cannot coordinate workers. Set that URL
to a reachable Redis service before running multiple workers or replicas. The
Redis mode uses an atomic script to check and reserve every relevant limit
together, and shares weather cache entries across workers. If Redis is
configured but unavailable, provider calls fail with HTTP 503 rather than
silently bypassing the guards. Redis credentials belong only in `.env` or the
deployment secret store. Concurrent identical cache misses can still each
make a provider call, within the shared outbound limit.

The rolling 30-day weather limit is an application budget, not necessarily the
same reset period as OpenWeather's account month. Groq token-per-minute/day
quotas and Cloudinary's combined storage, transformation, and bandwidth credits
are still provider-defined. Check their dashboards and keep application limits
below account-specific ceilings. Cloudinary upload counts and file size are
not the same as credits.

## Read-only usage check and photo cleanup

Run `.venv\Scripts\python.exe scripts/check_provider_usage.py --live` from the
repository root for a read-only snapshot. It makes one Groq model-list request,
two OpenWeather calls, and one Cloudinary usage request. It prints statuses,
configured-model availability, and available quota fields, without printing
keys or full provider responses. Cloudinary reports may lag; an 80% usage
alert is a prompt to check the Cloudinary console. Groq's exact token and
request limits are in its console; the model-list response may omit quota
headers. The existing admin evaluation summary reports Groq token usage from
saved AI generation runs.

Soft-deleting a memory does not automatically delete its Cloudinary image. An
operator can preview one candidate with
`.venv\Scripts\python.exe scripts/cleanup_cloudinary_memory.py --memory-id ID`.
The command checks the deleted status, the trip-specific Lakbay folder, and
whether an active memory still references that public ID. It only deletes when
run with both `--purge` and `--confirm-public-id EXACT_ID`. Review the preview
and run purge only during a maintenance window; it permanently deletes that
single Cloudinary image. No existing assets are deleted during installation or
tests.

See the current provider documentation for [Groq rate limits](https://console.groq.com/docs/rate-limits),
[OpenWeather pricing](https://openweathermap.org/price), and
[Cloudinary billing](https://cloudinary.com/documentation/billing_and_plans).

## Verification

Run the focused controls and existing feature tests with:

```powershell
.venv\Scripts\python.exe -m pytest tests/test_provider_usage_guards.py tests/test_provider_weather_usage.py tests/test_provider_groq_usage.py tests/test_phase10_memories.py tests/test_phase5_ai_itineraries.py tests/test_planning_chat.py -q
```

These tests mock providers and do not consume live API usage. Use provider
dashboards and a controlled live smoke test separately when deploying.
