# Deploy CircuitVerse (Option B – Kamal)

This guide walks you through deploying CircuitVerse to **your own server** using Kamal so students and teachers can use it from any device and location.

**Using DigitalOcean?** See **[DEPLOY-DIGITALOCEAN.md](DEPLOY-DIGITALOCEAN.md)** for Droplet setup, Docker/Redis/PostgreSQL, and a step-by-step checklist. Work is saved on your server, and you can deploy newer versions by pushing to `master` or triggering the workflow manually.

## What you get

- **Web app** at a URL you choose (e.g. `https://circuitverse.yourschool.edu`)
- **Groups & assignments**: teachers create groups, add students, create assignments; students do tasks; teachers grade
- **Persistent data**: PostgreSQL and Redis on your server (or reachable by it)
- **Updates**: push to `master` or run “Deploy to Server” in the Actions tab to deploy a new version

---

## 1. Server requirements

- **OS**: Ubuntu (or another Linux with Docker support)
- **Docker** installed. This deploy config reaches host services from containers via `host.docker.internal`.
- **SSH** access as a user that can run Docker (e.g. `ubuntu`; see `config/deploy.yml` → `ssh.user`)
- **PostgreSQL** and **Redis** running and reachable from the server:
  - Option A: Install PostgreSQL and Redis on the same host; use `POSTGRES_URL` with `host.docker.internal` for PostgreSQL and ensure Redis is reachable at `redis://host.docker.internal:6379/0`
  - Option B: Use managed Postgres (e.g. AWS RDS, DigitalOcean) and set `POSTGRES_URL`; Redis still needs to be on the server or at the URL you set
- **Domain** (optional but recommended): a hostname that points to your server’s public IP (e.g. `circuitverse.yourschool.edu`) for HTTPS and Traefik

---

## 2. One-time setup

### 2.1 GitHub repository

- Use this repo (or your fork).
- Ensure the deploy workflow and Kamal config are in place (`config/deploy.yml`, `.github/workflows/deploy.yml`).

### 2.2 GitHub secrets

In **Settings → Secrets and variables → Actions**, add (see `deploy.env.example` for a full list):

| Secret | Description |
|--------|-------------|
| `SERVER_IP` | Public IP or hostname of your server (e.g. `12.34.56.78` or `circuitverse.yourschool.edu`) |
| `SSH_PRIVATE_KEY` | Private key for SSH as `ubuntu` (or the user in `config/deploy.yml` → `ssh.user`) so GitHub Actions can run Kamal on the server |
| `POSTGRES_URL` | Full PostgreSQL URL, e.g. `postgres://user:password@host:5432/circuitverse_production` |
| `RAILS_MASTER_KEY` | Optional for this repo unless you add Rails encrypted credentials later. |
| `SECRET_KEY_BASE` | Long random string for Rails (e.g. `rails secret`) |
| `RECAPTCHA_SITE_KEY` | Optional; only needed if you enable the reCAPTCHA feature flag. |
| `RECAPTCHA_SECRET_KEY` | Optional; only needed if you enable the reCAPTCHA feature flag. |
| `TRAEFIK_HOST` | Domain for the app (e.g. `circuitverse.yourschool.edu`). Used for Traefik and HTTPS. If omitted, defaults to `staging.circuitverse.org` |
| `AWS_S3_ACCESS_KEY_ID` | If you use S3 for uploads (can be empty if not used) |
| `AWS_S3_SECRET_ACCESS_KEY` | If you use S3 |
| `BUGSNAG_API_KEY` | Optional; can be empty |

For a **fork**, the workflow builds your image and pushes to GitHub Container Registry (GHCR). Registry auth uses the built-in `github.token`; you do not need to add a GHCR secret. The workflow sets `KAMAL_IMAGE` and `KAMAL_REGISTRY_USERNAME` from the repo and actor.

### 2.3 Server: SSH and Docker

- Install Docker on the server.
- Create an SSH key pair; add the **public** key to the server’s `~/.ssh/authorized_keys` for the deploy user (e.g. `ubuntu`).
- Put the **private** key in the GitHub secret `SSH_PRIVATE_KEY` (full PEM content, including `-----BEGIN ... KEY-----` and `-----END ... KEY-----`).

### 2.4 Database

- Create a PostgreSQL database and user for production.
- Set `POSTGRES_URL` in GitHub secrets to that connection URL.
- If PostgreSQL is on the same Docker host, use `host.docker.internal` in `POSTGRES_URL`, not `localhost` or `172.17.0.1`.
- The first deploy will run migrations when the app starts (if you use the default entrypoint that runs migrations).

---

## 3. First deploy

1. **Trigger the workflow**
   - Push to `master`, or  
   - Go to **Actions → “Deploy to Server” → Run workflow**.

2. The workflow will:
   - Build the Docker image from this repo and push it to GHCR.
   - Run Kamal on the server: start Traefik (reverse proxy), start the app and Sidekiq, start the `yosys2digitaljs-server` accessory.

3. **Open the app**
   - If you set `TRAEFIK_HOST`: open `https://<TRAEFIK_HOST>` (ensure DNS points to your server and, if needed, ports 80/443 are open).
   - If not using Traefik/domain: access the server on port 3000 (e.g. `http://<SERVER_IP>:3000`) if your firewall allows it.

---

## 4. Deploying a newer version

- **Option A**: Push your changes to `master`. The “Deploy to Server” workflow will run and redeploy.
- **Option B**: Go to **Actions → “Deploy to Server” → Run workflow** to redeploy the current `master` without new commits.

Data in PostgreSQL and Redis is kept across deploys; only the app and Sidekiq containers are updated.

---

## 5. Optional: Run Kamal from your machine

If you prefer to deploy from your laptop instead of GitHub Actions:

1. Install Ruby and Kamal: `gem install kamal`.
2. Set the same environment variables (or use a `.env` file Kamal can load). See `deploy.env.example`. You can run `./bin/kamal-deploy-check` to verify required vars are set before running Kamal.
3. Run:
   ```bash
   kamal deploy
   ```
   Or build locally and push the image, then:
   ```bash
   kamal redeploy --skip_push
   ```

---

## 6. Troubleshooting

- **“Permission denied” on SSH**: Check `SSH_PRIVATE_KEY` and that the deploy user (e.g. `ubuntu`) can use Docker.
- **App not reachable**: Check firewall (80, 443 or 3000), DNS, and that Traefik is running (`kamal traefik details` or SSH and `docker ps`).
- **DB connection errors**: Check `POSTGRES_URL` and that the server can reach the database (security groups / firewall). For host-local PostgreSQL, use `host.docker.internal` and allow Docker bridge ranges to reach port `5432`.
- **Redis**: Default is `redis://host.docker.internal:6379/0`. If Redis is elsewhere, set `REDIS_URL` in `config/deploy.yml` under `env.clear`.

For more on Kamal, see [kamal-deploy.org](https://kamal-deploy.org).

**Reference:** `deploy.env.example` lists all env vars. Run `./bin/kamal-deploy-check` locally to verify required vars before a manual Kamal deploy.
