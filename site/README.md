# PreviewMD landing page

The landing page, newsletter endpoint, and download counter run from one
dependency-free Python server:

```bash
python3 site/server.py
```

Open <http://127.0.0.1:4173>. Newsletter signups sent to
`POST /api/subscribe` and download clicks sent to `POST /api/download` are
stored in:

```text
.previewmd-data/subscribers.sqlite3
```

The database is outside the public `site/` directory and is ignored by Git.
The `subscribers` table stores only the normalized email address and UTC signup
time; duplicate addresses are ignored. The `downloads` table stores one
aggregate click count per release archive and the UTC time when that count was
last updated. It does not store IP addresses or associate clicks with email
addresses.

Inspect the list and download counts with:

```bash
sqlite3 .previewmd-data/subscribers.sqlite3 \
  'SELECT email, created_at FROM subscribers ORDER BY created_at DESC;'

sqlite3 .previewmd-data/subscribers.sqlite3 \
  'SELECT file_name, click_count, updated_at FROM downloads ORDER BY updated_at DESC;'

sqlite3 .previewmd-data/subscribers.sqlite3 \
  'SELECT COALESCE(SUM(click_count), 0) AS total_download_clicks FROM downloads;'
```

Environment variables:

- `PORT` changes the listening port (default: `4173`).
- `PREVIEWMD_SITE_HOST` changes the bind address (default: `127.0.0.1`).
- `PREVIEWMD_SUBSCRIBERS_DB` changes the SQLite database path.

Both endpoints are requested document-relative, so the page works at the server
root (local development) and under a `/<slug>/` subpath (production). Download
tracking is best-effort and never gates the ZIP download. See
`deploy/README.md` for how the site is published and released.
