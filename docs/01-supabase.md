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


# 🚀 Installation Steps

## 1. Create Non-Root User for Supabase

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

## 2 Install Docker and Docker Compose
You can follow the official Docker docs here: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

Update system packages:

```bash
sudo apt update
```

Add Docker's official GPG key and add the repository to Apt sources:

```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

Install Docker:

```bash
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Enable Docker for non-root user:

```bash
sudo usermod -aG docker api
newgrp docker
```

Verify that the installation is successful by running the hello-world image:

```bash
docker run hello-world
```

You should see a "Hello from Docker!" message.

---

Also verify if Docker Compose is installed:

```bash
docker compose version
```

Expected output: `Docker Compose version v5.x.x`



## 3. Clone Supabase Repository

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

## 4. Configure Environment Variables

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

**Security Warning before continuing!**
---

**Never use:**
- Common passwords (password123, admin, etc.)
- Short passwords (less than 20 characters)
- Passwords from examples or documentation

**Best practices:**
- Use at least 32 characters
- Mix letters, numbers, special characters
- Store securely (password manager, secrets vault)
- Never commit to Git

There are multiple ways to do this:
---

<details>
  <summary>Automatically</summary>

  Generate the secrets and JWT tokens using the official Supabase Quick setup (experimental) script:
  ```bash
  sh ./utils/generate-keys.sh
  ```
</details>

<details>
  <summary>Manually</summary>
  ### Generate Secrets:

**For JWT_SECRET and POSTGRES_PASSWORD:**

```bash
openssl rand -hex 32
```
Run this command twice to get two different secrets.

JWT generation
---
  <details>
    <summary>Online</summary>
    Generate JWT_SECRET, ANON_KEY and SERVICE_ROLE_KEY:

    in the official Supabase docs: https://supabase.com/docs/guides/self-hosting/docker#installing-supabase¸

    OR on other websites (e.g. www.jwt.io) with this payload:
    
    ```bash
    {"role":"anon","iss":"supabase","iat":1700000000,"exp":1900000000}
    ```

  </details>


  <details>
    <summary>Locally, with a script</summary>
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
  </details>




</details>


## 5. Pull Docker Images

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

## 6. Fix PostgreSQL Port Conflict

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

## 7. Start Supabase

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

## 8. Test Supabase Locally (Optional)

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




