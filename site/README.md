# PreviewMD landing page

The landing page and its newsletter endpoint run from one dependency-free
Python server:

```bash
python3 site/server.py
```

Open <http://127.0.0.1:4173>. Newsletter signups sent to
`POST /api/subscribe` are stored in:

```text
.previewmd-data/subscribers.sqlite3
```

The database is outside the public `site/` directory and is ignored by Git.
It stores only the normalized email address and the UTC signup time. Duplicate
addresses are ignored.

Inspect the list with:

```bash
sqlite3 .previewmd-data/subscribers.sqlite3 \
  'SELECT email, created_at FROM subscribers ORDER BY created_at DESC;'
```

Environment variables:

- `PORT` changes the listening port (default: `4173`).
- `PREVIEWMD_SITE_HOST` changes the bind address (default: `127.0.0.1`).
- `PREVIEWMD_SUBSCRIBERS_DB` changes the SQLite database path.
