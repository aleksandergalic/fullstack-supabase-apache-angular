# 🗄️ Supabase Self-Hosting on Ubuntu 24.04

This guide covers the installation and management of Supabase using Docker on a fresh Ubuntu 24.04 server.

---

## 📋 Prerequisites

- **OS**: Ubuntu 24.04 LTS
- **Access**: Root SSH access
- **Hardware**: 
  - Minimum: 4 GB RAM, 2 CPU cores, 50 GB SSD
  - Recommended: 8 GB RAM, 4 CPU cores, 100 GB SSD

---

## 🚀 Installation Steps

### 1. Create Non-Root User for Supabase

```bash
sudo adduser api
sudo usermod -aG sudo api
su - api
```

### 2. Install Docker & Docker Compose

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg git
# [Add Docker GPG key and repo as per official docs...]
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker api
newgrp docker
```

### 3. Clone Supabase Repository

```bash
mkdir -p ~/supabase-project
cd ~/supabase-project
git clone --depth 1 https://github.com/supabase/supabase.git
cp -r supabase/docker/* .
cp supabase/docker/.env.example .env
```

### 4. Configure Environment Variables

Edit the `.env` file and set your `POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, and `SERVICE_ROLE_KEY`.

### 5. Start Supabase

```bash
docker compose pull
docker compose up -d
```

---

## 💾 Database Management

### Backup PostgreSQL Database

```bash
docker exec -t supabase-db pg_dumpall -c -U postgres > ~/backups/supabase_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore Database

```bash
docker exec -i supabase-db psql -U postgres < ~/backups/your_backup_file.sql
```

---

## 🆙 Upgrading Supabase

1. Backup your database.
2. Pull latest changes from the official Supabase repo.
3. Update Docker images: `docker compose pull`.
4. Restart containers: `docker compose down && docker compose up -d`.
