# 🌐 Apache & Virtualmin Configuration

This guide covers setting up a domain and reverse proxy for your self-hosted services using Virtualmin and Apache.

---
## 1. Install Virtualmin
Original guide: https://www.virtualmin.com/download/

Run this command:
```bash
sudo sh -c "$(curl -fsSL https://download.virtualmin.com/virtualmin-install)" -- --bundle LAMP

```
And accept everything.

If you get an error like this and you have a domain, just type the domain like shown here:

```bash
Phase 2 of 4: Setup
[ERROR] Your system hostname ubuntu is not fully qualified.
Please enter a fully qualified hostname (e.g.: host.example.com):

host.your-domain.com
```
After, that, wait 5-10 min for the server to install.

You should get something like this:
```bash
[SUCCESS] Installation Complete!
[SUCCESS] If there were no errors above, Virtualmin is ready to be configured
[SUCCESS] at https://host.powman.site:10000 (or
[SUCCESS] https://your-ip:10000).
[WARNING] You will see a security warning in the browser on your first visit.
```

### 1.1 The dashboard is available only locally, so we will install and configure Dante server to be able to access it.
Original guide: https://www.digitalocean.com/community/tutorials/how-to-set-up-dante-proxy-on-ubuntu-20-04

```bash
sudo apt update
sudo apt install dante-server
```
Before running, we need to change the configuration, but it's best to delete the automatic generated one:
```bash
sudo rm /etc/danted.conf
sudo nano /etc/danted.conf
```
Add this configuration, changing the external proxying network interface to yours.

```bash
logoutput: syslog
user.privileged: root
user.unprivileged: nobody

# The listening network interface or address.
internal: 0.0.0.0 port=1080

# The proxying network interface or address.
external: eth0 #change this to your network interface

# socks-rules determine what is proxied through the external interface.
socksmethod: username

# client-rules determine who can connect to the internal interface.
clientmethod: none

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
```

You can check for your default network route with this:

```bash
ip r | grep default
```
Output (217.154.119.1 being your gateway and 217.154.119.x your ip)
```bash
default via 217.154.119.1 dev ens6 proto dhcp src 217.154.119.x metric 100
```

You can also restrict what ip addresses can connect to the proxy:
```bash
…
client pass {
    from: your_ip_address/0 to: 0.0.0.0/0
}
```
... and add multiple IP addresses with CIDR notation or just add another client pass {} configuration block:
```bash
client pass {
    from: your_ip_address/0 to: 0.0.0.0/0
}

client pass {
    from: another_ip_address/0 to: 0.0.0.0/0
}
```


Now you can try to start the server:
```bash
sudo systemctl enable danted.service
sudo systemctl start danted.service
sudo systemctl status danted.service
```

You should see an output like this:
```bash
● danted.service - SOCKS (v4 and v5) proxy daemon (danted)
     Loaded: loaded (/usr/lib/systemd/system/danted.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-03-09 07:51:38 UTC; 15s ago
       Docs: man:danted(8)
             man:danted.conf(5)
   Main PID: 1799021 (danted)
      Tasks: 20 (limit: 14250)
     Memory: 7.7M (peak: 8.3M)
        CPU: 363ms
     CGroup: /system.slice/danted.service
             ├─1799021 /usr/sbin/danted
             ├─1799097 "danted: monitor"
             ├─1799098 "danted: negotia"
             ├─1799099 "danted: request"
             ├─1799100 "danted: request"
             ├─1799101 "danted: request"
             ├─1799102 "danted: request"
             ├─1799103 "danted: request"
             ├─1799104 "danted: request"
             ├─1799105 "danted: request"
             ├─1799106 "danted: request"
             ├─1799107 "danted: request"
             ├─1799108 "danted: request"
             ├─1799109 "danted: request"
             ├─1799110 "danted: request"
             ├─1799111 "danted: request"
             ├─1799112 "danted: request"
             ├─1799113 "danted: request"
             ├─1799114 "danted: request"
             └─1799115 "danted: io-chil"

Mar 09 07:51:38 host.your-domain.site systemd[1]: Starting danted.service - SOCKS (v4 and v5) proxy daemon (danted)...
Mar 09 07:51:38 host.your-domain.site systemd[1]: Started danted.service - SOCKS (v4 and v5) proxy daemon (danted).
Mar 09 07:51:39 host.your-domain.site danted[1799021]: info: Dante/server[1/1] v1.4.3 running
```
As we can see, it works :) ! But to connect, we just need to allow the port 1080 in the firewall.

```bash
sudo ufw status
```
But when running this command, we find out that Virtualmin replaced the ufw firewall with Firewalld at installation. So, we must run these commands:

```bash
sudo firewall-cmd --permanent --add-port=1080/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

We can see it worked:

```bash
public (default, active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces:
  sources:
  services: dhcpv6-client dns dns-over-tls ftp http https imap imaps mdns pop3 pop3s smtp smtp-submission smtps ssh
  ports: 20/tcp 2222/tcp 10000-10100/tcp 20000/tcp 49152-65535/tcp 1080/tcp
  protocols:
  forward: yes
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
```

For better security, we will add a new user with no other login privileges.
```bash
sudo useradd -r -s /bin/false your_dante_user
sudo passwd your_dante_user
```
You can generate a secure password with this command:
```bash
openssl rand -hex 32
```

You’ll also want to avoid logging into this account over an unsecured wireless connection or sharing the server too widely. Otherwise, malicious actors can and will make repeated efforts to log in.

---

Now, we can connect to the proxy. I recommend connecting to the proxy with the extension FoxyProxy in Firefox browser. If you can't connect to the proxy, check if your router firewall is blocking the port 1080.


## 2. Create domain and subdomains in Virtualmin
We will split the services to these subdomains:
- mydomain.com (Marketing/presentation website,)
    - app.mydomain.com (Actual app)
    - api.mydomain.com (for Supabase APIs)
    - dashboard.mydomain.com (For the Supabase Studio dashboard)


### Main domain:
1. Log into Virtualmin web interface (usually at `https://your-server-ip:10000` Or `https://localhost:10000` if you have Dante proxy enabled)
2. Click **Create Virtual Server**
3. Configure:
   - **Domain name**: `mydomain.com`
   - **Administration username**: any name
   - **Administration password**: (set a password)
4. **Enable**:
   - ✅ Apache website
   - ✅ SSL website (via Let's Encrypt)
   - ✅ MariaDB (for a CMS like Wordpress)
5. Click **Create Server**
6. Go to **Manage Web Apps** --> **Available Web Apps**
7. Select **Wordpress**, scroll down and select **Install Options**
8. At **Install sub-directory under public_html**, select `At top level`. This will install Wordpress in the top folder (public_html).


Wait for Virtualmin to create the virtual server.

### Subdomains:
1. Click **Create Virtual Sub-Server**
3. Configure:
   - **Domain name**: `app.example.com`
   - **Administration username**: `supabase` (or any name)
   - **Administration password**: (set a password)
4. **Enable**:
   - ✅ Apache website
   - ✅ SSL website (via Let's Encrypt)
6. Click **Create Server**

Also do this for api.mydomain.com and dashboard.mydomain.com
---

## 2.1 Enable Apache Proxy Modules

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
You're gonna need to configure proxies like this:
```
mydomain.com --> No proxy
├─ app.mydomain.com --> 
├─ api.mydomain.com -->
├─ dashboard.mydomain.com --> http://127.0.0.1:8000/
```
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
