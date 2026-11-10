# Profile Photos

Profile photo uploads use the shared Cloudinary image service. The URL is saved
to the existing `users.avatar_url` column and is returned in the standard user
response; no migration is required.

## Endpoint

```text
POST /api/v1/users/me/avatar
```

Send an authenticated `multipart/form-data` request with one image in the
`file` field. The response is the updated user profile, including `avatar_url`.

Allowed content types, image signature checks, and the maximum size use the
shared `UPLOAD_ALLOWED_IMAGE_TYPES` and `UPLOAD_MAX_IMAGE_BYTES` settings. The
upload is stored under the configured Cloudinary folder in
`users/{user_id}/profile/`. Per-user and app-wide daily upload limits are shared
with trip memory uploads.

## Cloudinary configuration

Set these environment variables on the API service:

```env
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CLOUDINARY_UPLOAD_FOLDER=lakbay
```

Keep the API secret in the deployment's secret environment settings and out of
source control. The existing trip memory upload flow uses the same credentials.

## Client behavior

The traveler app uploads the selected gallery image through this endpoint and
uses the returned `avatar_url` in the profile. The URL is available after login
on other devices. Curated avatar choices continue to use the profile update
endpoint.
