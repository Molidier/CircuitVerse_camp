# Deploy on DigitalOcean (Option B – Kamal)

This guide covers **DigitalOcean-specific** setup for deploying CircuitVerse with Kamal. For the general deploy flow and GitHub secrets, see [DEPLOY.md](DEPLOY.md).

**Quick list of what you do:** [docs/YOUR-DEPLOY-CHECKLIST.md](docs/YOUR-DEPLOY-CHECKLIST.md)

---

## 1. Create a Droplet

1. Log in to [DigitalOcean](https://cloud.digitalocean.com).
2. **Droplets → Create Droplet**.
3. **Image**: **Ubuntu 22.04 LTS** (required for the `ubuntu` user used by Kamal).
4. **Plan**: **Basic**, **2 GB RAM / 1 vCPU** minimum; **4 GB** is better for production.
5. **Region**: Choose one near you or your users.
6. **Authentication**: **SSH key** — add your public key so you can log in as `ubuntu`.
7. **Hostname**: e.g. `circuitverse` (optional).
8. Create the Droplet and note its **public IP** (this is your `SERVER_IP`).

---

## 2. Prepare the Droplet (run as `ubuntu` over SSH)

SSH in: `ssh ubuntu@YOUR_DROPLET_IP`

### 2.1 Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
```

Log out and SSH back in so the `docker` group applies. Then verify:

```bash
docker run hello-world
```

### 2.2 Install Redis

The app expects Redis at `redis://172.17.0.1:6379/0` (Docker host). Install Redis on the Droplet and allow connections from containers:

```bash
sudo apt update && sudo apt install -y redis-server
sudo sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

### 2.3 PostgreSQL (choose one)

**Option A – Managed Database (recommended)**

1. In DigitalOcean: **Databases → Create Database Cluster → PostgreSQL**.
2. Pick a small plan and the same region as your Droplet.
3. Add the Droplet under **Trusted Sources** (or allow the Droplet’s private IP if in the same VPC).
4. After creation, note **host**, **port** (often 25060), **user**, **password**, and **database**.
5. Build the URL (use `sslmode=require` for managed DB):
   ```
   postgres://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require
   ```
   Use this as `POSTGRES_URL` in GitHub secrets.

**Option B – PostgreSQL on the same Droplet**

```bash
sudo apt install -y postgresql postgresql-contrib
sudo -u postgres createuser -s circuitverse
sudo -u postgres createdb -O circuitverse circuitverse_production
sudo -u postgres psql -c "ALTER USER circuitverse PASSWORD 'CHOOSE_A_STRONG_PASSWORD';"
```

From app containers, the host is the Docker bridge: `172.17.0.1`. Allow connections from local/Docker:

```bash
sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = 'localhost, 172.17.0.1';"
sudo systemctl restart postgresql
```

Use this as `POSTGRES_URL` (replace with your password):

```
postgres://circuitverse:CHOOSE_A_STRONG_PASSWORD@172.17.0.1:5432/circuitverse_production
```

### 2.4 Firewall

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable
```

---

## 3. SSH key for GitHub Actions

Use a **dedicated key** for deploys (do not use your main SSH key).

On your **local machine**:

```bash
ssh-keygen -t ed25519 -C "github-deploy-circuitverse" -f ~/.ssh/circuitverse_deploy -N ""
```

Add the public key to the Droplet:

```bash
ssh-copy-id -i ~/.ssh/circuitverse_deploy.pub ubuntu@YOUR_DROPLET_IP
```

Test login:

```bash
ssh -i ~/.ssh/circuitverse_deploy ubuntu@YOUR_DROPLET_IP
```

Copy the **private** key (entire contents, including `-----BEGIN ... KEY-----` and `-----END ... KEY-----`) for the GitHub secret `SSH_PRIVATE_KEY`:

```bash
cat ~/.ssh/circuitverse_deploy
```

---

## 4. GitHub Actions secrets

In the repo: **Settings → Secrets and variables → Actions**. Add:

| Secret | Value (DigitalOcean) |
|--------|----------------------|
| `SERVER_IP` | Droplet public IP (e.g. `164.92.xxx.xxx`) |
| `SSH_PRIVATE_KEY` | Full contents of `~/.ssh/circuitverse_deploy` (private key) |
| `POSTGRES_URL` | Managed DB URL with `?sslmode=require`, or `postgres://circuitverse:PASSWORD@172.17.0.1:5432/circuitverse_production` if Postgres is on the Droplet |
| `RAILS_MASTER_KEY` | From `config/master.key` or generate (see [DEPLOY.md](DEPLOY.md)) |
| `SECRET_KEY_BASE` | Output of `bundle exec rails secret` |
| `RECAPTCHA_SITE_KEY` | Your reCAPTCHA site key |
| `RECAPTCHA_SECRET_KEY` | Your reCAPTCHA secret key |
| `TRAEFIK_HOST` | Domain pointing to the Droplet (e.g. `circuitverse.example.com`), or omit to use default |

Optional: `AWS_S3_ACCESS_KEY_ID`, `AWS_S3_SECRET_ACCESS_KEY`, `BUGSNAG_API_KEY`.

---

## 5. Domain (optional)

- In your DNS provider, add an **A record**: host (e.g. `circuitverse` or `@`) → Droplet **public IP**.
- Set the GitHub secret **`TRAEFIK_HOST`** to that hostname (e.g. `circuitverse.yourschool.edu`).
- Traefik will obtain HTTPS via Let’s Encrypt.

Without a domain, you can use `http://YOUR_DROPLET_IP:3000` (ensure port 3000 is not blocked; Traefik may still serve on 80/443 if configured).

---

## 6. Deploy

- Push to `master`, or go to **Actions → “Deploy to Server” → Run workflow**.
- Open **https://&lt;TRAEFIK_HOST&gt;** or **http://&lt;SERVER_IP&gt;:3000**.

---

## Quick checklist

- [ ] Droplet: Ubuntu 22.04, 2 GB+ RAM, SSH key added
- [ ] Docker installed, `ubuntu` in `docker` group
- [ ] Redis installed and bound to `0.0.0.0`
- [ ] PostgreSQL: managed DB or on Droplet; `POSTGRES_URL` uses correct host (managed host or `172.17.0.1`)
- [ ] UFW: 22, 80, 443 allowed
- [ ] Deploy SSH key: public on Droplet, private in `SSH_PRIVATE_KEY`
- [ ] All [DEPLOY.md](DEPLOY.md) secrets set in GitHub
- [ ] Optional: DNS A record and `TRAEFIK_HOST` set
