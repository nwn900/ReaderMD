# Production deployment

The landing page is published as one of the projects on
<https://experiments.frontierslab.ai/readermd/>, hosted on the OVH VPS
(`ovh-vps` in `~/.ssh/config`).

Code reaches the server through GitHub only — nothing is copied by hand.

## Layout on the server

```text
/home/ubuntu/experiments/readermd/                 # git clone
/home/ubuntu/experiments/.data/                     # SQLite, outside the tree
/home/ubuntu/sites/experiments.frontierslab.ai/readermd -> …/readermd/site
```

Only `site/` is symlinked into the docroot, so the Swift sources, tests and
build scripts are never web-reachable.

## Releasing a new version

1. Build and notarize the app (`./scripts/release-app.sh`, see `AGENTS.md`).
2. Drop the new `ReaderMD-<version>-<build>-macOS.dmg` into `site/`, delete the old
   one, and update `DOWNLOAD_FILE` in `site/main.js` plus every literal
   filename in `site/index.html`.
3. Commit and push to `main`.
4. Pull it onto the server:

   ```bash
   ssh ovh-vps 'exp-deploy update readermd'
   ```

`exp-deploy` runs `git pull --ff-only` and re-points the symlink. The download
DMG is tracked in git precisely so this one command is the whole deployment.

## First-time setup (already done — kept for reference)

The original deployment used a read-only deploy key, matching the convention
used by the other experiments. A public clone no longer requires the key, but
the restricted setup remains a reasonable deployment choice:

```bash
ssh ovh-vps 'ssh-keygen -t ed25519 -N "" -C readermd-deploy -f ~/.ssh/readermd_deploy'
# add ~/.ssh/readermd_deploy.pub to the repo as a deploy key (read-only)
gh repo deploy-key add readermd_deploy.pub --repo ashtree74/ReaderMD --title readermd-vps
```

`~/.ssh/config` on the server carries the host alias:

```sshconfig
Host github.com-readermd
    HostName github.com
    User git
    IdentityFile ~/.ssh/readermd_deploy
    IdentitiesOnly yes
```

Then:

```bash
ssh ovh-vps 'exp-deploy git@github.com-readermd:ashtree74/ReaderMD.git readermd --out site --no-install'
```

## Landing API

`site/server.py` runs as a systemd unit bound to `127.0.0.1:8419`; nginx
proxies only the newsletter and download-count paths to it:

- `POST /readermd/api/subscribe`
- `POST /readermd/api/download`

| File | Installed to |
| --- | --- |
| `deploy/readermd-signup.service` | `/etc/systemd/system/readermd-signup.service` |
| `deploy/nginx-readermd.conf` | spliced into `/etc/nginx/sites-available/experiments.frontierslab.ai` |
| rate-limit zone | `/etc/nginx/conf.d/readermd-ratelimit.conf` |

These are copied into place rather than `include`d from the working tree on
purpose: an `include` would let anything that can write to the clone rewrite the
web server's configuration on the next reload.

The page is served under a strict Content-Security-Policy, which is only
possible because it has no inline `<script>`, no inline `<style>` and no `style`
attributes. Keep it that way — see the ruler-stop rules in `site/styles.css` for
the pattern to follow when something needs a computed position.

```bash
sudo systemctl status readermd-signup
sudo journalctl -u readermd-signup -n 50
```

Read the signup list and aggregate download counts:

```bash
ssh ovh-vps "sqlite3 /home/ubuntu/experiments/.data/readermd-subscribers.sqlite3 \
  'SELECT email, created_at FROM subscribers ORDER BY created_at DESC;'"

ssh ovh-vps "sqlite3 /home/ubuntu/experiments/.data/readermd-subscribers.sqlite3 \
  'SELECT file_name, click_count, updated_at FROM downloads ORDER BY updated_at DESC;'"
```

The unit is hardened (`ProtectSystem=strict`, empty `CapabilityBoundingSet`,
`SystemCallFilter=@system-service`) and can write to exactly one directory:
`/home/ubuntu/experiments/.data`. Restart it after a deploy that changes
`server.py`:

```bash
ssh ovh-vps 'sudo systemctl restart readermd-signup'
```
