# DigitalOcean deploy — what to do from your side

The repo is **ready** for DigitalOcean deployment. Follow these steps in order. Full details are in [DEPLOY-DIGITALOCEAN.md](../DEPLOY-DIGITALOCEAN.md).

---

## 1. DigitalOcean

- [ ] Create a **Droplet**: Ubuntu 22.04, 2 GB+ RAM, add your SSH key. Note the **public IP**.
- [ ] (Optional) Create a **Managed PostgreSQL** database; add the Droplet to Trusted Sources. Note host, port, user, password, database.

---

## 2. Prepare the Droplet (SSH as `ubuntu`)

- [ ] Install **Docker** and add `ubuntu` to the `docker` group (log out and back in after).
- [ ] Install **Redis** and set `bind 0.0.0.0` (see [DEPLOY-DIGITALOCEAN.md](../DEPLOY-DIGITALOCEAN.md#22-install-redis)).
- [ ] **PostgreSQL**: use Managed DB (no install) **or** install on the Droplet and allow `172.17.0.1` (see doc).
- [ ] Enable **firewall**: `ufw allow 22,80,443` and enable.

---

## 3. Deploy SSH key

- [ ] On your machine: `ssh-keygen -t ed25519 -C "deploy" -f ~/.ssh/circuitverse_deploy -N ""`
- [ ] Copy **public** key to Droplet: `ssh-copy-id -i ~/.ssh/circuitverse_deploy.pub ubuntu@YOUR_DROPLET_IP`
- [ ] Test: `ssh -i ~/.ssh/circuitverse_deploy ubuntu@YOUR_DROPLET_IP`

---

## 4. GitHub Actions secrets

In the repo: **Settings → Secrets and variables → Actions**. Add:

- [ ] `SERVER_IP` — Droplet public IP
- [ ] `SSH_PRIVATE_KEY` — full contents of `~/.ssh/circuitverse_deploy` (private key)
- [ ] `POSTGRES_URL` — connection URL (managed DB with `?sslmode=require` or `postgres://circuitverse:PASSWORD@172.17.0.1:5432/circuitverse_production`)
- [ ] `RAILS_MASTER_KEY` — from `config/master.key` or generate (see [DEPLOY.md](../DEPLOY.md))
- [ ] `SECRET_KEY_BASE` — output of `bundle exec rails secret`
- [ ] `RECAPTCHA_SITE_KEY` — your key (or placeholder for private use)
- [ ] `RECAPTCHA_SECRET_KEY` — your key (or placeholder)
- [ ] `TRAEFIK_HOST` — (optional) domain pointing to Droplet, for HTTPS

---

## 5. Domain (optional)

- [ ] Add DNS **A record** → Droplet IP.
- [ ] Set secret **`TRAEFIK_HOST`** to that hostname.

---

## 6. Deploy

- [ ] Push to `master` **or** run **Actions → “Deploy to Server” → Run workflow**.
- [ ] Open **https://&lt;TRAEFIK_HOST&gt;** or **http://&lt;SERVER_IP&gt;:3000**.

---

**Need more detail?** See [DEPLOY-DIGITALOCEAN.md](../DEPLOY-DIGITALOCEAN.md).
