# 🌐 Apache & Virtualmin Configuration

This guide covers setting up a domain and reverse proxy for your self-hosted services using Virtualmin and Apache.

---

## 🏗️ Create Virtual Server in Virtualmin

1. Log in to Virtualmin (`https://your-server-ip:10000`).
2. Click **Create Virtual Server**.
3. Fill in your **Domain name** (e.g., `api.example.com`).
4. Enable:
   - ✅ Apache website
   - ✅ SSL website (Let's Encrypt)
5. Click **Create Server**.

---

## 🛠️ Configure Apache Reverse Proxy

### Enable Modules

```bash
sudo a2enmod proxy proxy_http proxy_wstunnel headers ssl rewrite
sudo systemctl restart apache2
```

### Manual Configuration

Find your configuration file (usually in `/etc/apache2/sites-available/your-domain.conf`) and add:

```apache
<VirtualHost *:443>
    ServerName your-domain.com

    ProxyPreserveHost On
    ProxyRequests Off

    # Forward to your local service (e.g., Supabase on port 8000)
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    # WebSocket Support (for Realtime)
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*)           ws://127.0.0.1:8000/$1 [P,L]

    # Headers for proper forwarding
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Port "443"
</VirtualHost>
```

---

## 🔄 Update Service URLs

Once your domain is live, ensure your service is configured with the correct public URLs. For example, in Supabase `.env`:

```bash
SITE_URL=https://your-domain.com
API_EXTERNAL_URL=https://your-domain.com
```
