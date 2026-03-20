# ⚛️ Angular Client Setup

This guide covers implementing Angular in Apache.

Original guide:https://businesscompassllc.com/deploying-your-angular-application-on-apache-a-step-by-step-guide/

---
## 1. Install NVM (Node version manager)
Node Version Manager (NVM) helps manage multiple versions of Node.js on your server. To install NVM, use the following command:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

```
and verify the installation:
```bash
nvm –version

```
## 2.Installing Node.js and npm
nvm install 20
node -v
npm -v

## 3.Installing Angular CLI
npm install -g @angular/cli
ng version

## 4.Installing Git for Repository Access
To clone your repository on the server, Git needs to be installed. If Git is not already installed, you can do so using:

sudo apt-get install git

Verify Git installation with:

git –version



---

## 🛠️ Coming Soon:
- Local development setup
- Supabase client integration
- Production build and deployment
