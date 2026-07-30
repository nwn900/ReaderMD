# Production deployment

The landing page is published as one of the projects on
<https://experiments.frontierslab.ai/previewmd/>, hosted on the OVH VPS
(`ovh-vps` in `~/.ssh/config`).

Code reaches the server through GitHub only — nothing is copied by hand.

## Layout on the server

```text
/home/ubuntu/experiments/previewmd/                 # git clone (private repo)
/home/ubuntu/experiments/.data/                     # SQLite, outside the tree
/home/ubuntu/sites/experiments.frontierslab.ai/previewmd -> …/previewmd/site
```

Only `site/` is symlinked into the docroot, so the Swift sources, tests and
build scripts are never web-reachable.

## Releasing a new version

1. Build and notarize the app (`./scripts/release-app.sh`, see `AGENTS.md`).
2. Drop the new `PreviewMD-<version>-macOS.zip` into `site/`, delete the old
   one, and update `DOWNLOAD_FILE` in `site/main.js` plus every literal
   filename in `site/index.html`.
3. Commit and push to `main`.
4. Pull it onto the server:

   ```bash
   ssh ovh-vps 'exp-deploy update previewmd'
   ```

`exp-deploy` runs `git pull --ff-only` and re-points the symlink. The download
ZIP is tracked in git precisely so this one command is the whole deployment.

## First-time setup (already done — kept for reference)

Cloning a private repo needs a read-only deploy key, matching the convention
used by the other experiments:

```bash
ssh ovh-vps 'ssh-keygen -t ed25519 -N "" -C previewmd-deploy -f ~/.ssh/previewmd_deploy'
# add ~/.ssh/previewmd_deploy.pub to the repo as a deploy key (read-only)
gh repo deploy-key add previewmd_deploy.pub --repo ashtree74/PreviewMD --title previewmd-vps
```

`~/.ssh/config` on the server carries the host alias:

```sshconfig
Host github.com-previewmd
    HostName github.com
    User git
    IdentityFile ~/.ssh/previewmd_deploy
    IdentitiesOnly yes
```

Then:

```bash
ssh ovh-vps 'exp-deploy git@github.com-previewmd:ashtree74/PreviewMD.git previewmd --out site --no-install'
```

## Landing API

`site/server.py` runs as a systemd unit bound to `127.0.0.1:8419`; nginx
proxies only the newsletter and download-count paths to it:

- `POST /previewmd/api/subscribe`
- `POST /previewmd/api/download`

| File | Installed to |
| --- | --- |
| `deploy/previewmd-signup.service` | `/etc/systemd/system/previewmd-signup.service` |
| `deploy/nginx-previewmd.conf` | spliced into `/etc/nginx/sites-available/experiments.frontierslab.ai` |
| rate-limit zone | `/etc/nginx/conf.d/previewmd-ratelimit.conf` |

These are copied into place rather than `include`d from the working tree on
purpose: an `include` would let anything that can write to the clone rewrite the
web server's configuration on the next reload.

The page is served under a strict Content-Security-Policy, which is only
possible because it has no inline `<script>`, no inline `<style>` and no `style`
attributes. Keep it that way — see the ruler-stop rules in `site/styles.css` for
the pattern to follow when something needs a computed position.

```bash
sudo systemctl status previewmd-signup
sudo journalctl -u previewmd-signup -n 50
```

Read the signup list and aggregate download counts:

```bash
ssh ovh-vps "sqlite3 /home/ubuntu/experiments/.data/previewmd-subscribers.sqlite3 \
  'SELECT email, created_at FROM subscribers ORDER BY created_at DESC;'"

ssh ovh-vps "sqlite3 /home/ubuntu/experiments/.data/previewmd-subscribers.sqlite3 \
  'SELECT file_name, click_count, updated_at FROM downloads ORDER BY updated_at DESC;'"
```

The unit is hardened (`ProtectSystem=strict`, empty `CapabilityBoundingSet`,
`SystemCallFilter=@system-service`) and can write to exactly one directory:
`/home/ubuntu/experiments/.data`. Restart it after a deploy that changes
`server.py`:

```bash
ssh ovh-vps 'sudo systemctl restart previewmd-signup'
```
