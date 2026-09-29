# Memories And Photo Uploads API Guide

This guide covers Phase 10: Memories And Photo Uploads.

Phase 10 lets active trip members upload images to Cloudinary and save those
image URLs as trip memories with captions, location tags, and optional
destination links.

## Endpoints

```text
POST   /api/v1/trips/{trip_id}/memories/upload
POST   /api/v1/trips/{trip_id}/memories
GET    /api/v1/trips/{trip_id}/memories
GET    /api/v1/trips/{trip_id}/memories/{memory_id}
PATCH  /api/v1/trips/{trip_id}/memories/{memory_id}
DELETE /api/v1/trips/{trip_id}/memories/{memory_id}
```

All endpoints require a bearer access token.

## Migration

Phase 10 adds the trip memory table:

```text
0010_trip_memories
```

After receiving the Phase 10 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0010_trip_memories (head)
```

## Environment Variables

```env
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
CLOUDINARY_UPLOAD_FOLDER=lakbay
UPLOAD_MAX_IMAGE_BYTES=5242880
UPLOAD_ALLOWED_IMAGE_TYPES=image/jpeg,image/png,image/webp
```

Cloudinary values come from the Cloudinary dashboard. Keep the API secret out of
Git.

## Upload Flow

First upload the image using `multipart/form-data`:

```text
POST /api/v1/trips/{trip_id}/memories/upload
```

The field name is:

```text
file
```

The response returns:

```json
{
  "image_url": "https://res.cloudinary.com/demo/image/upload/example.jpg",
  "cloudinary_public_id": "lakbay/trips/1/memories/example",
  "original_filename": "beach.jpg",
  "content_type": "image/jpeg",
  "bytes": 120000,
  "width": 1200,
  "height": 800,
  "format": "jpg",
  "resource_type": "image"
}
```

Then save the memory using JSON:

```text
POST /api/v1/trips/{trip_id}/memories
```

```json
{
  "image_url": "https://res.cloudinary.com/demo/image/upload/example.jpg",
  "cloudinary_public_id": "lakbay/trips/1/memories/example",
  "destination_id": 1,
  "caption": "Sunset after the hike",
  "location_tag": "Davao City",
  "taken_at": "2026-10-10T17:30:00Z"
}
```

## Validation

- Allowed image types: JPEG, PNG, and WebP by default.
- Default maximum upload size: 5 MB.
- Upload validation checks the actual file bytes, not only the browser-provided
  content type.
- Saved memory URLs must be secure Cloudinary URLs.
- `destination_id`, when provided, must belong to the trip.
- Captions are limited to 500 characters.
- Location tags are limited to 255 characters.

## Permissions

- Active trip members can upload, create, view, and list memories.
- Removed members and outsiders cannot access memories.
- The uploader, trip owner, or organizer can update or delete a memory.
- Only trip owners and organizers can list deleted memories with
  `include_deleted=true`.
- Archived trips are read-only for memory writes.

## Delete Behavior

Delete is a soft delete. The memory remains in the database with:

```text
status = deleted
```

Deleted memories are hidden from normal list and detail endpoints.

The Cloudinary asset is not deleted in Phase 10. Asset cleanup can be added in a
future admin/storage maintenance phase.

## Testing

Run the Phase 10 tests:

```bash
python -m pytest tests/test_phase10_memories.py -q
```

Then run the full test suite:

```bash
python -m pytest -q
```
