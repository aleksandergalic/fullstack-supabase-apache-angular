# 🚀 Supabase Self-Hosting on Ubuntu 24.04
## Apache + Virtualmin + Docker (Production-Ready Guide)

---

## 📌 Overview

This comprehensive guide walks you through self-hosting Supabase on **Ubuntu 24.04** using:

- **Docker** (non-root user)
- **Apache** (Virtualmin managed)
- **Reverse Proxy** (SSL/HTTPS)
- **Let's Encrypt** (Free SSL)

### ✅ Key Features
- No system PostgreSQL dependency
- No Supabase files inside `public_html`
- Production-safe architecture
- Non-root Docker setup
- Complete security hardening

---

## 🧱 Architecture

```
Browser
  ↓
Apache (80 → 443 SSL)
  ↓
Reverse Proxy
  ↓
Supabase Kong Gateway (Docker, port 8000)
  ↓
├─ Auth Service
├─ REST API (PostgREST)
├─ Realtime
├─ Storage
└─ PostgreSQL (Docker internal)
```

---

## 📋 Requirements

- **OS**: Ubuntu 24.04 LTS (fresh installation recommended)
- **Access**: Root SSH access
- **Control Panel**: Virtualmin installed and configured
- **Domain**: A valid domain or subdomain (e.g., `supabase.example.com`)
- **Hardware**:
  - Minimum: 4 GB RAM, 2 CPU cores, 50 GB SSD
  - Recommended: 8 GB RAM, 4 CPU cores, 100 GB SSD
- **Network**: Ports 80 and 443 accessible

---

## 📚 Table of Contents

1. [Create Non-Root User](#1-create-non-root-user-for-supabase)
2. [Install Docker](#2-install-docker-non-root)
3. [Install Docker Compose Plugin](#3-install-docker-compose-plugin)
4. [Clone Supabase Repository](#4-clone-supabase-repository)
5. [Configure Environment Variables](#5-configure-environment-variables)
6. [Pull Docker Images](#6-pull-docker-images)
7. [Fix PostgreSQL Port Conflict](#7-fix-postgresql-port-conflict)
8. [Start Supabase](#8-start-supabase)
9. [Test Supabase Locally](#9-test-supabase-locally-optional)
10. [Create Domain in Virtualmin](#10-create-domain-in-virtualmin)
11. [Enable Apache Proxy Modules](#11-enable-apache-proxy-modules)
12. [Configure Apache Reverse Proxy](#12-configure-apache-reverse-proxy)
13. [Update Supabase URLs](#13-update-supabase-urls)
14. [Access Supabase](#14-access-supabase)
15. [Firewall Configuration](#15-firewall-configuration)
16. [Database Backup & Restore](#16-database-backup--restore)
17. [Monitoring & Health Checks](#17-monitoring--health-checks)
18. [Upgrading Supabase](#18-upgrading-supabase)
19. [Troubleshooting](#19-troubleshooting)
20. [Security Best Practices](#20-security-best-practices)

---

## 1️⃣ Create Non-Root User for Supabase

Create a dedicated user for running Supabase (security best practice):

```bash
sudo adduser api
sudo usermod -aG sudo api
```

Switch to the new user:

```bash
su - api
```

All subsequent commands should be run as the `api` user unless specified otherwise.

---

## 2️⃣ Install Docker (Non-Root)

Update system packages:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg git
```

Add Docker's official GPG key:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Add Docker repository:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install Docker:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```

Enable Docker for non-root user:

```bash
sudo usermod -aG docker api
newgrp docker
```

Verify installation:

```bash
docker run hello-world
```

You should see a "Hello from Docker!" message.

---

## 3️⃣ Install Docker Compose Plugin

```bash
sudo apt install -y docker-compose-plugin
```

Verify:

```bash
docker compose version
```

Expected output: `Docker Compose version v2.x.x`

---

## 4️⃣ Clone Supabase Repository

Create a project directory (outside of any web-accessible folders):

```bash
mkdir -p ~/supabase-project
cd ~/supabase-project
```

Clone the official Supabase repository:

```bash
git clone --depth 1 https://github.com/supabase/supabase.git
```

Copy Docker files to your project directory:

```bash
cp -r supabase/docker/* .
cp supabase/docker/.env.example .env
```

Your directory structure should now look like:

```
~/supabase-project/
├── docker-compose.yml
├── .env
├── volumes/
└── ...
```

---

## 5️⃣ Configure Environment Variables

Edit the `.env` file:

```bash
nano .env
```

### Required Changes:

```bash
############
# Secrets
############
POSTGRES_PASSWORD=your-super-secret-postgres-password-here
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
ANON_KEY=generate-using-instructions-below
SERVICE_ROLE_KEY=generate-using-instructions-below

############
# Dashboard Credentials
############
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=your-strong-dashboard-password

############
# Database
############
POSTGRES_HOST=db
POSTGRES_DB=postgres
POSTGRES_PORT=5432

############
# API URLs
############
SITE_URL=https://supabase.example.com
API_EXTERNAL_URL=https://supabase.example.com
SUPABASE_PUBLIC_URL=https://supabase.example.com

############
# Studio
############
STUDIO_DEFAULT_ORGANIZATION=My Organization
STUDIO_DEFAULT_PROJECT=My Project
```

### Generate Secrets:

**For JWT_SECRET and POSTGRES_PASSWORD:**

```bash
openssl rand -hex 32
```

Run this command twice to get two different secrets.

**For ANON_KEY and SERVICE_ROLE_KEY:**

You need to generate JWT tokens. Here's a manual method using online tools or local scripts:

Method 1 - Using Python:

```bash
# Install PyJWT if not available
pip3 install pyjwt

# Create a script
cat > generate_keys.py << 'EOF'
import jwt
import sys

if len(sys.argv) < 2:
    print("Usage: python3 generate_keys.py <JWT_SECRET>")
    sys.exit(1)

secret = sys.argv[1]
payload_anon = {"role": "anon", "iss": "supabase", "iat": 1700000000, "exp": 1900000000}
payload_service = {"role": "service_role", "iss": "supabase", "iat": 1700000000, "exp": 1900000000}

anon_key = jwt.encode(payload_anon, secret, algorithm="HS256")
service_key = jwt.encode(payload_service, secret, algorithm="HS256")

print(f"ANON_KEY={anon_key}")
print(f"SERVICE_ROLE_KEY={service_key}")
EOF

# Run it with your JWT_SECRET
python3 generate_keys.py "your-jwt-secret-from-above"
```

Method 2 - Using Node.js:

```bash
# Install jsonwebtoken
npm install -g jsonwebtoken-cli

# Generate ANON_KEY
jwt sign '{"role":"anon","iss":"supabase","iat":1700000000,"exp":1900000000}' "your-jwt-secret"

# Generate SERVICE_ROLE_KEY
jwt sign '{"role":"service_role","iss":"supabase","iat":1700000000,"exp":1900000000}' "your-jwt-secret"
```

Copy the generated keys into your `.env` file.

**Important Notes:**
- Use strong, unique passwords
- Never commit `.env` to version control
- Store secrets securely

---

## 6️⃣ Pull Docker Images

Pull all required Supabase images:

```bash
docker compose pull
```

This downloads:
- PostgreSQL (with extensions)
- Kong (API Gateway)
- PostgREST
- GoTrue (Auth)
- Realtime
- Storage
- Studio
- Imgproxy
- Analytics

Wait for all images to download (may take 5-10 minutes).

---

## 7️⃣ Fix PostgreSQL Port Conflict

**IMPORTANT**: If Virtualmin has PostgreSQL installed, port 5432 will conflict.

Edit `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Find the `db` service section (around line 20-40) and **comment out or remove** the ports mapping:

**Before:**
```yaml
db:
  container_name: supabase-db
  image: supabase/postgres:15.1.0.117
  ports:
    - "5432:5432"  # ← Remove this line
```

**After:**
```yaml
db:
  container_name: supabase-db
  image: supabase/postgres:15.1.0.117
  # ports:
  #   - "5432:5432"  # Commented out to avoid conflicts
```

**Alternative**: If you need external PostgreSQL access, map to a different port:

```yaml
ports:
  - "54322:5432"  # Host port 54322 → Container port 5432
```

Also check for the `pooler` service and comment out or change its port:

```yaml
pooler:
  container_name: supabase-pooler
  image: pgbouncer/pgbouncer:1.20.1
  # ports:
  #   - "5432:5432"  # Comment this out
  # OR change to:
  # ports:
  #   - "54321:5432"
```

Save and exit (`Ctrl + X`, then `Y`, then `Enter`).

---

## 8️⃣ Start Supabase

Start all services in detached mode:

```bash
docker compose up -d
```

Wait 30-60 seconds for all services to initialize.

Verify all containers are healthy:

```bash
docker compose ps
```

Expected output:

```
NAME                          STATUS
supabase-db                   Up (healthy)
supabase-auth                 Up (healthy)
supabase-rest                 Up (healthy)
supabase-realtime             Up (healthy)
supabase-storage              Up (healthy)
supabase-kong                 Up (healthy)
supabase-studio               Up (healthy)
supabase-meta                 Up (healthy)
supabase-analytics            Up (healthy)
supabase-imgproxy             Up
supabase-edge-functions       Up
supabase-vector               Up (healthy)
```

If any service shows "unhealthy", check logs:

```bash
docker compose logs <service-name>
```

Example:
```bash
docker compose logs kong
docker compose logs auth
```

---

## 9️⃣ Test Supabase Locally (Optional)

Before configuring Apache, test that Supabase is running:

```bash
curl http://localhost:8000
```

You should get a response like:
```json
{"msg":"Supabase API is running"}
```

Or open in browser (from your local machine via SSH tunnel):

```
http://YOUR_SERVER_IP:8000
```

⚠️ **Security Warning**: This is for testing only. Do NOT expose port 8000 publicly.

---

## 🔟 Create Domain in Virtualmin

1. Log into Virtualmin web interface (usually at `https://your-server-ip:10000`)
2. Click **Create Virtual Server**
3. Configure:
   - **Domain name**: `supabase.example.com`
   - **Administration username**: `supabase` (or any name)
   - **Administration password**: (set a password)
4. **Enable**:
   - ✅ Apache website
   - ✅ SSL website (via Let's Encrypt)
5. **Disable**:
   - ❌ MySQL database
   - ❌ PostgreSQL database
   - ❌ Mail for domain
6. Click **Create Server**

Wait for Virtualmin to create the virtual server.

---

## 1️⃣1️⃣ Enable Apache Proxy Modules

Enable required Apache modules:

```bash
sudo a2enmod proxy proxy_http proxy_wstunnel headers ssl rewrite
sudo systemctl restart apache2
```

Verify modules are loaded:

```bash
apache2ctl -M | grep proxy
```

Expected output:
```
proxy_module (shared)
proxy_http_module (shared)
proxy_wstunnel_module (shared)
```

---

## 1️⃣2️⃣ Configure Apache Reverse Proxy

### Method 1: Using Virtualmin GUI (Recommended)

1. In Virtualmin, select your domain (`supabase.example.com`)
2. Go to **Server Configuration** → **Website Options**
3. Scroll down and enable **Proxy website?** checkbox
4. Set **Proxy URL** to: `http://127.0.0.1:8000`
5. Click **Save**

**OR** use **Proxy Paths** (better for WebSocket support):

1. Go to **Services** → **Configure Website** → **Proxy Paths**
2. Click **Add a new proxy path**
3. Configure:
   - **Path**: `/`
   - **Proxy to URL**: `http://127.0.0.1:8000`
   - **Proxy WebSockets**: ✅ Check this (Important for Realtime)
4. Click **Create**

### Method 2: Manual Configuration

Find your Apache configuration file:

```bash
sudo nano /etc/apache2/sites-available/supabase.example.com.conf
```

Inside the `<VirtualHost *:443>` block, add these lines:

```apache
<VirtualHost *:443>
    ServerName supabase.example.com
    ServerAdmin admin@example.com

    DocumentRoot /home/supabase/public_html

    # SSL Configuration (managed by Virtualmin/Certbot)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/supabase.example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/supabase.example.com/privkey.pem

    # Proxy Configuration
    ProxyPreserveHost On
    ProxyRequests Off

    # Forward to Supabase Kong Gateway
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    # WebSocket Support (for Realtime)
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*)           ws://127.0.0.1:8000/$1 [P,L]
    RewriteCond %{HTTP:Upgrade} !=websocket [NC]
    RewriteRule /(.*)           http://127.0.0.1:8000/$1 [P,L]

    # Headers for proper forwarding
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s

    # Logging
    ErrorLog ${APACHE_LOG_DIR}/supabase_error.log
    CustomLog ${APACHE_LOG_DIR}/supabase_access.log combined
</VirtualHost>
```

Also configure HTTP (port 80) to redirect to HTTPS:

```apache
<VirtualHost *:80>
    ServerName supabase.example.com

    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
```

Test Apache configuration:

```bash
sudo apache2ctl configtest
```

If "Syntax OK", restart Apache:

```bash
sudo systemctl restart apache2
```

---

## 1️⃣3️⃣ Update Supabase URLs

Now that Apache is configured, update Supabase to use your domain:

```bash
cd ~/supabase-project
nano .env
```

Ensure these values match your domain:

```bash
SITE_URL=https://supabase.example.com
API_EXTERNAL_URL=https://supabase.example.com
SUPABASE_PUBLIC_URL=https://supabase.example.com
```

Save the file.

Restart Supabase to apply changes:

```bash
docker compose down
docker compose up -d
```

Wait 30 seconds for services to restart.

---

## 1️⃣4️⃣ Access Supabase 🎉

Open your browser and navigate to:

```
https://supabase.example.com
```

You should see the **Supabase Studio** login page.

### Login Credentials:

- **Email/Username**: Value from `DASHBOARD_USERNAME` in `.env` (default: `admin`)
- **Password**: Value from `DASHBOARD_PASSWORD` in `.env`

### Test API Endpoints:

Open these URLs in your browser or use curl:

**Auth Health Check:**
```bash
curl https://supabase.example.com/auth/v1/health
```

Expected response:
```json
{"version":"...","health":"ok"}
```

**REST API:**
```bash
curl https://supabase.example.com/rest/v1/
```

**Storage:**
```bash
curl https://supabase.example.com/storage/v1/status
```

All should return JSON responses.

---

## 1️⃣5️⃣ Firewall Configuration

Configure UFW (Uncomplicated Firewall):

```bash
# Allow SSH (IMPORTANT: Do this first!)
sudo ufw allow 22/tcp

# Allow HTTP
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

Expected output:
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

**❌ DO NOT expose these ports publicly:**
- `8000` (Kong - proxied through Apache)
- `5432` (PostgreSQL - internal only)
- `54321` (PostgREST - internal only)
- `54322` (GoTrue - internal only)

---

## 1️⃣6️⃣ Database Backup & Restore

### Create Backup Directory

```bash
mkdir -p ~/backups
```

### Backup PostgreSQL Database

```bash
docker exec -t supabase-db pg_dumpall -c -U postgres > ~/backups/supabase_backup_$(date +%Y%m%d_%H%M%S).sql
```

This creates a timestamped backup file like: `supabase_backup_20260105_143000.sql`

### Restore Database

```bash
docker exec -i supabase-db psql -U postgres < ~/backups/supabase_backup_20260105_143000.sql
```

Replace the filename with your actual backup file.

### Automated Backup Script

Create a backup script:

```bash
nano ~/backup_supabase.sh
```

Add this content:

```bash
#!/bin/bash

# Configuration
BACKUP_DIR=~/backups
RETENTION_DAYS=7

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup database
docker exec -t supabase-db pg_dumpall -c -U postgres > $BACKUP_DIR/supabase_$TIMESTAMP.sql

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Backup completed successfully: supabase_$TIMESTAMP.sql"

    # Delete backups older than retention period
    find $BACKUP_DIR -name "supabase_*.sql" -mtime +$RETENTION_DAYS -delete
    echo "Old backups removed (older than $RETENTION_DAYS days)"
else
    echo "Backup failed!"
    exit 1
fi
```

Make executable:

```bash
chmod +x ~/backup_supabase.sh
```

Test it:

```bash
~/backup_supabase.sh
```

### Schedule Automatic Backups

Add to crontab (daily at 2 AM):

```bash
crontab -e
```

Add this line:

```
0 2 * * * /home/api/backup_supabase.sh >> /home/api/backup.log 2>&1
```

This will:
- Run backup every day at 2:00 AM
- Log output to `~/backup.log`
- Keep last 7 days of backups

---

## 1️⃣7️⃣ Monitoring & Health Checks

### Check Container Status

```bash
docker compose ps
```

All services should show "Up (healthy)" status.

### View Logs

**All services:**
```bash
docker compose logs -f
```

**Specific service:**
```bash
docker compose logs -f kong
docker compose logs -f auth
docker compose logs -f rest
docker compose logs -f realtime
docker compose logs -f storage
docker compose logs -f db
```

Press `Ctrl+C` to exit logs.

**Last 100 lines:**
```bash
docker compose logs --tail=100 kong
```

### Health Check Endpoints

Test all services:

```bash
# Kong Gateway (main entry point)
curl https://supabase.example.com/

# Auth Service
curl https://supabase.example.com/auth/v1/health

# REST API
curl https://supabase.example.com/rest/v1/

# Realtime
curl https://supabase.example.com/realtime/v1/health

# Storage
curl https://supabase.example.com/storage/v1/status
```

### Resource Monitoring

**CPU and Memory usage:**
```bash
docker stats
```

Output shows real-time resource usage for each container.

**Disk usage:**
```bash
docker system df
```

**Volume inspection:**
```bash
docker volume ls
du -sh ~/supabase-project/volumes/*
```

### Apache Logs

```bash
# Error log
sudo tail -f /var/log/apache2/supabase_error.log

# Access log
sudo tail -f /var/log/apache2/supabase_access.log
```

---

## 1️⃣8️⃣ Upgrading Supabase

### Before Upgrading

1. **Backup your database** (see section 16)
2. **Review release notes** on GitHub
3. **Test in staging** if possible

### Update Process

```bash
cd ~/supabase-project

# Backup current configuration
cp .env .env.backup
cp docker-compose.yml docker-compose.yml.backup

# Pull latest changes
cd supabase
git pull origin master
cd ..

# Copy new files (this will overwrite docker-compose.yml)
cp -r supabase/docker/* .

# IMPORTANT: Restore your custom configurations
# Compare .env with .env.backup and merge any new variables
nano .env

# If you made custom changes to docker-compose.yml, restore them
# (like commented out ports, etc.)
nano docker-compose.yml

# Pull new Docker images
docker compose pull

# Stop current containers
docker compose down

# Start with new images
docker compose up -d

# Check health
docker compose ps
docker compose logs -f
```

### Check for Breaking Changes

Always review:
- Release notes at: github.com/supabase/supabase/releases
- Migration guides
- Environment variable changes

### Rollback if Needed

```bash
# Stop services
docker compose down

# Restore old configuration
cp .env.backup .env
cp docker-compose.yml.backup docker-compose.yml

# Start old version
docker compose up -d

# Restore database if needed
docker exec -i supabase-db psql -U postgres < ~/backups/supabase_backup_TIMESTAMP.sql
```

---

## 1️⃣9️⃣ Troubleshooting

### Issue: 502 Bad Gateway

**Symptoms**: Browser shows "502 Bad Gateway" when accessing Supabase

**Possible Causes**:
- Kong container not healthy
- Apache misconfigured
- Services not started

**Solutions**:

```bash
# Check Kong logs
docker compose logs kong

# Check Kong health
docker exec -it supabase-kong kong health

# Restart Kong
docker compose restart kong

# Verify Kong is listening
docker exec -it supabase-kong netstat -tlnp | grep 8000

# Check Apache proxy configuration
sudo apache2ctl configtest
sudo systemctl status apache2

# Restart Apache
sudo systemctl restart apache2
```

---

### Issue: WebSocket Connection Failed (Realtime)

**Symptoms**: Realtime subscriptions don't work

**Possible Causes**:
- Missing `proxy_wstunnel` module
- WebSocket proxy not configured

**Solutions**:

```bash
# Enable WebSocket module
sudo a2enmod proxy_wstunnel
sudo systemctl restart apache2

# Verify Realtime is running
docker compose logs realtime

# Test Realtime endpoint
curl https://supabase.example.com/realtime/v1/health

# Check Apache config includes WebSocket rewrite rules
sudo nano /etc/apache2/sites-available/supabase.example.com.conf
```

Ensure these lines are present:

```apache
RewriteEngine On
RewriteCond %{HTTP:Upgrade} =websocket [NC]
RewriteRule /(.*)           ws://127.0.0.1:8000/$1 [P,L]
```

---

### Issue: Auth Redirect Loops

**Symptoms**: After login, browser keeps redirecting

**Possible Causes**:
- Incorrect `SITE_URL`
- Missing forwarding headers
- SSL not configured properly

**Solutions**:

```bash
# Check .env URLs
cd ~/supabase-project
grep -E "SITE_URL|API_EXTERNAL_URL" .env
```

All should be `https://supabase.example.com`

```bash
# Verify Apache passes HTTPS headers
sudo nano /etc/apache2/sites-available/supabase.example.com.conf
```

Ensure these headers exist:

```apache
RequestHeader set X-Forwarded-Proto "https"
RequestHeader set X-Forwarded-Port "443"
```

Restart services:

```bash
docker compose down
docker compose up -d
sudo systemctl restart apache2
```

---

### Issue: Port 5432 Already in Use

**Symptoms**: Error when starting containers: "port 5432 already in use"

**Possible Causes**:
- System PostgreSQL running
- Another container using port 5432

**Solutions**:

```bash
# Check what's using port 5432
sudo netstat -tlnp | grep 5432

# Option 1: Stop system PostgreSQL
sudo systemctl stop postgresql
sudo systemctl disable postgresql

# Option 2: Change Supabase port
nano docker-compose.yml
```

In `db` service, change:

```yaml
ports:
  - "54322:5432"  # Use different host port
```

Or comment out entirely:

```yaml
# ports:
#   - "5432:5432"
```

Restart:

```bash
docker compose down
docker compose up -d
```

---

### Issue: Studio Not Loading

**Symptoms**: Studio page shows errors or won't load

**Possible Causes**:
- Invalid ANON_KEY or SERVICE_ROLE_KEY
- JWT_SECRET mismatch
- Studio container not healthy

**Solutions**:

```bash
# Check Studio logs
docker compose logs studio

# Verify environment variables
grep -E "ANON_KEY|SERVICE_ROLE_KEY|JWT_SECRET" .env

# Regenerate keys if needed
# Use the Python script from section 5
python3 generate_keys.py "your-jwt-secret"

# Update .env with new keys
nano .env

# Restart services
docker compose down
docker compose up -d

# Wait 30 seconds and check
docker compose ps
```

---

### Issue: Storage Not Working

**Symptoms**: File uploads fail

**Possible Causes**:
- Volume permissions
- S3 configuration
- Storage container not healthy

**Solutions**:

```bash
# Check storage logs
docker compose logs storage

# Check volumes
docker volume ls
ls -la ~/supabase-project/volumes/storage

# Fix permissions if needed
sudo chown -R $(whoami):$(whoami) ~/supabase-project/volumes/storage

# Restart storage
docker compose restart storage
```

---

### Issue: Database Connection Errors

**Symptoms**: "Could not connect to database" errors

**Possible Causes**:
- PostgreSQL not healthy
- Wrong POSTGRES_PASSWORD
- Database initialization failed

**Solutions**:

```bash
# Check database health
docker compose ps db

# Check database logs
docker compose logs db

# Connect to database manually
docker exec -it supabase-db psql -U postgres

# If connection works, verify POSTGRES_PASSWORD in .env matches
grep POSTGRES_PASSWORD .env

# Restart database
docker compose restart db
```

---

### Issue: High Memory Usage

**Symptoms**: Server running out of memory

**Solutions**:

```bash
# Check resource usage
docker stats

# Restart services to free memory
docker compose restart

# If persistent, increase server RAM or optimize:
# Edit docker-compose.yml and add memory limits

# Example for db service:
deploy:
  resources:
    limits:
      memory: 2G
```

---

### Issue: SSL Certificate Errors

**Symptoms**: Browser shows "Not Secure" or certificate errors

**Solutions**:

```bash
# Renew Let's Encrypt certificate
sudo certbot renew

# Or request new certificate
sudo certbot --apache -d supabase.example.com

# Verify certificate files exist
sudo ls -la /etc/letsencrypt/live/supabase.example.com/

# Restart Apache
sudo systemctl restart apache2
```

---

## 2️⃣0️⃣ Security Best Practices

### 1. Strong Secrets

**Generate strong passwords:**

```bash
# For JWT_SECRET, POSTGRES_PASSWORD
openssl rand -hex 32
```

**Never use:**
- Common passwords (password123, admin, etc.)
- Short passwords (less than 20 characters)
- Passwords from examples or documentation

**Best practices:**
- Use at least 32 characters
- Mix letters, numbers, special characters
- Store securely (password manager, secrets vault)
- Never commit to Git

---

### 2. Network Security

**Firewall rules:**

```bash
# Only expose necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   # SSH only from trusted IPs
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

**Restrict SSH access:**

```bash
sudo nano /etc/ssh/sshd_config
```

Add:

```
PermitRootLogin no
PasswordAuthentication no
AllowUsers api
```

**Block internal ports:**

Never expose these publicly:
- 8000 (Kong)
- 5432 (PostgreSQL)
- 54321 (PostgREST)
- All other Docker internal ports

---

### 3. Regular Updates

**System updates:**

```bash
# Weekly
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
```

**Docker updates:**

```bash
# Monthly
docker compose pull
docker compose down
docker compose up -d
```

**Monitor security advisories:**
- Ubuntu security notices
- Supabase GitHub releases
- Docker security bulletins

---

### 4. Database Security

**Enable Row Level Security (RLS):**

In Supabase Studio:
1. Go to Database → Tables
2. For each table, click Settings
3. Enable "Row Level Security"
4. Create appropriate policies

**Best practices:**
- Enable RLS on all tables
- Use `service_role` key only in backend
- Never expose `service_role` in frontend
- Use `anon` key with RLS for public access

**Password policy:**

```bash
# Connect to database
docker exec -it supabase-db psql -U postgres

# Set password requirements (optional)
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
```

---

### 5. SSL/TLS Configuration

**Force HTTPS:**

Already configured in Apache (redirect from HTTP to HTTPS).

**Strong cipher suites:**

```bash
sudo nano /etc/apache2/sites-available/supabase.example.com-ssl.conf
```

Add:

```apache
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
SSLHonorCipherOrder on
```

**Auto-renewal:**

Let's Encrypt auto-renews. Verify:

```bash
sudo certbot renew --dry-run
```

---

### 6. Backup Strategy

**Automated backups:**
- Daily at 2 AM (already configured)
- Keep 7 days locally
- Copy critical backups off-server

**Off-site backup:**

```bash
# Example: SCP to another server
scp ~/backups/supabase_backup_*.sql user@backup-server:/backups/

# Or use rsync
rsync -avz ~/backups/ user@backup-server:/backups/
```

**Test restores monthly:**

```bash
# Create test environment
# Restore backup
# Verify data integrity
```

---

### 7. Monitoring & Alerts

**Disk space monitoring:**

```bash
# Check disk usage
df -h

# Set up alert (cron job)
echo '0 * * * * [ $(df / | tail -1 | awk "{print \$5}" | sed "s/%//") -gt 80 ] && echo "Disk space alert" | mail -s "Server Alert" admin@example.com' | crontab -
```

**Container health:**

```bash
# Create health check script
cat > ~/health_check.sh << 'EOF'
#!/bin/bash
cd ~/supabase-project
UNHEALTHY=$(docker compose ps | grep -c "unhealthy")
if [ $UNHEALTHY -gt 0 ]; then
    echo "Unhealthy containers detected!" | mail -s "Supabase Alert" admin@example.com
fi
EOF

chmod +x ~/health_check.sh

# Run every hour
echo '0 * * * * ~/health_check.sh' | crontab -
```

---

### 8. Access Control

**SSH keys only:**

```bash
# On your local machine
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to server
ssh-copy-id api@your-server-ip

# Disable password authentication (already shown above)
```

**Fail2ban for brute force protection:**

```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

**Sudo access:**

```bash
# Only give sudo to trusted users
# Log all sudo commands
echo 'Defaults logfile=/var/log/sudo.log' | sudo tee -a /etc/sudoers
```

---

### 9. Logging

**Enable detailed logging:**

```bash
# Apache logs already configured
# Docker logs retention
docker compose logs --tail=1000 > ~/logs/docker_$(date +%Y%m%d).log
```

**Log rotation:**

```bash
sudo nano /etc/logrotate.d/supabase
```

Add:

```
/home/api/logs/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
}
```

---

### 10. Regular Security Audits

**Monthly checklist:**
- [ ] Review user access
- [ ] Check firewall rules
- [ ] Verify SSL certificates
- [ ] Test backup restores
- [ ] Review logs for anomalies
- [ ] Update all software
- [ ] Check for exposed secrets
- [ ] Verify RLS policies
- [ ] Test disaster recovery plan

---

## 📊 Resource Requirements

### Minimum (Development/Testing)
- **RAM**: 4 GB
- **CPU**: 2 cores
- **Storage**: 50 GB SSD
- **Network**: 100 Mbps
- **Concurrent users**: 10-50

### Recommended (Small Production)
- **RAM**: 8 GB
- **CPU**: 4 cores
- **Storage**: 100 GB SSD
- **Network**: 1 Gbps
- **Concurrent users**: 100-500

### High Traffic (Large Production)
- **RAM**: 16+ GB
- **CPU**: 8+ cores
- **Storage**: 250+ GB SSD (NVMe)
- **Network**: 10 Gbps
- **Concurrent users**: 1000+
- **Additional**: Load balancer, separate database server

---

## 🔗 Useful Resources

### Official Documentation
- Supabase Docs: supabase.com/docs
- Self-Hosting Guide: supabase.com/docs/guides/self-hosting
- GitHub Repository: github.com/supabase/supabase
- Docker Reference: supabase.com/docs/guides/self-hosting/docker

### Community Support
- Supabase Discord: discord.supabase.com
- GitHub Issues: github.com/supabase/supabase/issues
- GitHub Discussions: github.com/supabase/supabase/discussions
- Stack Overflow: Tag `supabase`

### Server Management
- Virtualmin Docs: virtualmin.com/docs
- Virtualmin Forum: forum.virtualmin.com
- Apache Docs: httpd.apache.org/docs
- Docker Docs: docs.docker.com

### Learning Resources
- Supabase YouTube Channel
- Database Best Practices
- PostgreSQL Documentation
- Row Level Security Guide

---

## ❌ Common Mistakes to Avoid

### Configuration Mistakes

1. ❌ **Installing Supabase in `public_html`**
   - ✅ Use `~/supabase-project` instead

2. ❌ **Running Docker as root**
   - ✅ Create non-root user with Docker group

3. ❌ **Exposing port 5432 publicly**
   - ✅ Comment out port mapping in docker-compose.yml

4. ❌ **Using system PostgreSQL alongside Supabase**
   - ✅ Disable system PostgreSQL or change ports

5. ❌ **Skipping reverse proxy headers**
   - ✅ Always set X-Forwarded-Proto and X-Forwarded-Port

### Security Mistakes

6. ❌ **Not setting up SSL/HTTPS**
   - ✅ Always use Let's Encrypt

7. ❌ **Using weak passwords**
   - ✅ Generate 32+ character random strings

8. ❌ **Committing `.env` to Git**
   - ✅ Add `.env` to `.gitignore`

9. ❌ **Exposing `service_role` key in frontend**
   - ✅ Use only in backend, use `anon` key with RLS

10. ❌ **Not enabling Row Level Security**
    - ✅ Enable RLS on all tables

### Operational Mistakes

11. ❌ **Not backing up database**
    - ✅ Set up automated daily backups

12. ❌ **Forgetting to update `SITE_URL` after domain setup**
    - ✅ Update all URLs in `.env` to use your domain

13. ❌ **Not enabling WebSocket support**
    - ✅ Enable proxy_wstunnel for Realtime

14. ❌ **Ignoring container health checks**
    - ✅ Monitor `docker compose ps` regularly

15. ❌ **Not testing before upgrading**
    - ✅ Always backup and test in staging

---

## 🎯 Next Steps

### Essential (Do Immediately)

- ✅ Set up automated backups (Section 16)
- ✅ Configure firewall properly (Section 15)
- ✅ Review security settings (Section 20)
- ✅ Test all API endpoints (Section 14)
- ✅ Document your configuration

### Important (This Week)

- 📧 **Configure SMTP for email auth**
  - Add SMTP settings to `.env`
  - Test email delivery

- 🔒 **Implement Row Level Security**
  - Enable on all tables
  - Create appropriate policies
  - Test with `anon` key

- 📊 **Set up monitoring**
  - Health check scripts
  - Disk space alerts
  - Log monitoring

- 🔑 **Secure API keys**
  - Store securely
  - Rotate regularly
  - Document usage

### Optional (Future Enhancements)

- 🌐 **CDN Integration**
  - CloudFlare for static assets
  - DDoS protection
  - Global edge network

- 📦 **External S3 Storage**
  - AWS S3, DigitalOcean Spaces
  - Reduce local storage usage
  - Better file management

- 🔄 **CI/CD Pipeline**
  - GitHub Actions
  - Automated deployments
  - Testing automation

- 📈 **Advanced Monitoring**
  - Prometheus for metrics
  - Grafana for dashboards
  - Alerting system

- 🚀 **Horizontal Scaling**
  - Multiple API servers
  - Load balancer
  - Database replication

- 🔗 **Application Integration**
  - Next.js frontend
  - React Native with Capacitor
  - REST API clients

- 🧪 **Staging Environment**
  - Separate server for testing
  - Mirror production setup
  - Test upgrades safely

---

## 🆘 Getting Help

### Before Asking for Help

1. Check container logs: `docker compose logs -f`
2. Verify all containers healthy: `docker compose ps`
3. Test endpoints individually
4. Review this troubleshooting section
5. Search existing issues on GitHub

### Where to Get Help

**Supabase Community:**
- Discord: discord.supabase.com
- GitHub Issues: github.com/supabase/supabase/issues
- GitHub Discussions: github.com/supabase/supabase/discussions

**Virtualmin Support:**
- Forum: forum.virtualmin.com
- Documentation: virtualmin.com/docs

**General Support:**
- Stack Overflow: Tag `supabase` or `virtualmin`
- Reddit: r/selfhosted, r/Supabase

### When Reporting Issues

Include:
- Ubuntu version: `lsb_release -a`
- Docker version: `docker --version`
- Supabase version: `git rev-parse HEAD` in supabase directory
- Container status: `docker compose ps`
- Relevant logs: `docker compose logs <service>`
- Configuration (redact secrets!)

---

## 📝 License & Credits

### Supabase License

Supabase is licensed under Apache License 2.0
Full license: github.com/supabase/supabase/blob/master/LICENSE

### This Guide

This guide is provided as-is for educational purposes.
Feel free to modify and share.

### Credits

- **Supabase Team**: For creating an amazing open-source Firebase alternative
- **Virtualmin Team**: For the excellent server management panel
- **Community Contributors**: For testing and feedback
- **You**: For self-hosting and supporting open source!

---

## 📚 Version History

**Version 1.0** (January 2026)
- Initial comprehensive guide
- Ubuntu 24.04 support
- Apache + Virtualmin integration
- Complete security hardening
- Troubleshooting section
- Automated backup scripts

---

## ✅ Deployment Checklist

Use this checklist to ensure everything is set up correctly:

### Pre-Installation
- [ ] Ubuntu 24.04 LTS installed
- [ ] Virtualmin installed and configured
- [ ] Domain DNS pointing to server IP (A record)
- [ ] Server meets hardware requirements (4GB+ RAM)
- [ ] Root SSH access available

### User & Docker Setup
- [ ] Non-root user created (`api`)
- [ ] User added to sudo group
- [ ] Docker installed
- [ ] User added to docker group
- [ ] Docker Compose plugin installed
- [ ] Docker working: `docker run hello-world`

### Supabase Installation
- [ ] Repository cloned to `~/supabase-project`
- [ ] `.env` file configured
- [ ] Strong secrets generated (32+ chars)
- [ ] ANON_KEY and SERVICE_ROLE_KEY generated
- [ ] Dashboard credentials set
- [ ] Docker images pulled

### Configuration
- [ ] Port conflicts resolved (5432)
- [ ] docker-compose.yml edited if needed
- [ ] Containers started: `docker compose up -d`
- [ ] All containers healthy: `docker compose ps`
- [ ] Local test successful: `curl http://localhost:8000`

### Virtualmin & Apache
- [ ] Virtual server created in Virtualmin
- [ ] Domain configured
- [ ] Apache proxy modules enabled
- [ ] Reverse proxy configured
- [ ] WebSocket support enabled (proxy_wstunnel)
- [ ] SSL certificate installed (Let's Encrypt)
- [ ] Apache configuration tested: `apache2ctl configtest`
- [ ] Apache restarted

### Supabase Domain Configuration
- [ ] SITE_URL updated to https://yourdomain.com
- [ ] API_EXTERNAL_URL updated
- [ ] SUPABASE_PUBLIC_URL updated
- [ ] Containers restarted with new config

### Security
- [ ] Firewall configured (UFW)
- [ ] Only ports 22, 80, 443 open
- [ ] Port 8000 NOT exposed
- [ ] Port 5432 NOT exposed
- [ ] SSH keys configured
- [ ] Password authentication disabled
- [ ] Root login disabled

### Testing
- [ ] Studio accessible: https://yourdomain.com
- [ ] Studio login works
- [ ] Auth endpoint: /auth/v1/health
- [ ] REST endpoint: /rest/v1/
- [ ] Realtime endpoint: /realtime/v1/health
- [ ] Storage endpoint: /storage/v1/status
- [ ] WebSocket connections work

### Backups & Monitoring
- [ ] Backup directory created
- [ ] Manual backup tested
- [ ] Backup script created and executable
- [ ] Cron job scheduled (daily 2 AM)
- [ ] Health check scripts in place
- [ ] Log monitoring configured

### Documentation
- [ ] Configuration documented
- [ ] Secrets stored securely (password manager)
- [ ] Emergency contacts noted
- [ ] Backup locations documented
- [ ] Custom configurations saved

### Final Steps
- [ ] All services running smoothly
- [ ] No errors in logs
- [ ] Performance acceptable
- [ ] Users can access Supabase
- [ ] README reviewed
- [ ] Team trained (if applicable)

---

## 🎉 Congratulations!

Your Supabase instance is now live and production-ready!

### What You've Accomplished

✅ Self-hosted Supabase on your own infrastructure
✅ Secured with HTTPS and proper firewall rules
✅ Configured with Apache reverse proxy
✅ Set up automated backups
✅ Implemented monitoring and health checks
✅ Following security best practices

### Immediate Next Steps

1. **Create your first project** in Supabase Studio
2. **Set up Row Level Security** on your tables
3. **Test authentication** with a sample app
4. **Configure SMTP** for email auth (if needed)
5. **Monitor logs** for the first few days

### Remember

- Keep secrets secure
- Back up regularly
- Monitor health checks
- Update software monthly
- Test before upgrading
- Document changes

### Support This Project

If this guide helped you:
- ⭐ Star Supabase on GitHub
- 📢 Share with your team
- 🐛 Report issues or improvements
- 💬 Help others in the community

---

**Happy Building! 🚀**

---
