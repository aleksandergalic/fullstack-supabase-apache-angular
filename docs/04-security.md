# 🛡️ Security & Best Practices

This guide covers firewall setup and general security principles for your self-hosted stack.

---

## 🧱 Firewall Configuration (UFW)

Configure your firewall to allow only essential traffic:

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable
```

### 🚫 Restricted Ports

Do NOT expose these ports publicly:
- `5432` (PostgreSQL)
- `8000` (Kong Gateway)
- `54321` (PostgREST)

---

## 🔒 Security Best Practices

### 1. Strong Secrets

Use long, unique strings for all passwords and secrets:

```bash
openssl rand -hex 32
```

### 2. SSH Hardening

- Use SSH keys instead of passwords.
- Disable root login: `PermitRootLogin no`.
- Disable password authentication: `PasswordAuthentication no`.

### 3. Regular Updates

Keep your system and Docker images updated:

```bash
sudo apt update && sudo apt upgrade -y
docker compose pull && docker compose up -d
```
