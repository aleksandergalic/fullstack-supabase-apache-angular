#!/bin/bash

# --- CONFIGURATION ---
SOURCE_DIR="/home/api/fluffy-potato-master" # Path to your source code
TARGET_DIR="/home/powman/domains/app.powman.site/public_html" # Path to Virtualmin public_html
TARGET_USER="powman" # The owner of the website folder in Virtualmin
PROJECT_NAME="Modernize"
# --------------------

echo "🚀 Starting Secure Local Deployment..."

# 1. Navigate to Source Directory
cd "$SOURCE_DIR" || { echo "❌ Could not find source directory $SOURCE_DIR"; exit 1; }

# 2. Update Dependencies
echo "📦 Updating dependencies with Bun..."
bun install --silent

# 3. Build the Angular Project
echo "🏗️ Building project with Bun..."
bun run build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed. Aborting deployment."
    exit 1
fi

# 4. Deploy files using sudo rsync
echo "📤 Synchronizing files to $TARGET_DIR..."
# -a: archive, -v: verbose, -z: compress, --delete: remove old files
# We use sudo here to bypass the permission denied error
sudo rsync -avz --delete dist/"$PROJECT_NAME"/ "$TARGET_DIR"/

# 5. Fix ownership so Virtualmin/Apache can read the files
echo "🔑 Setting permissions to $TARGET_USER..."
sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_DIR"

# 6. Done
if [ $? -eq 0 ]; then
    echo "🎉 Deployment Successful! Your app is now live."
    echo "📍 Path: $TARGET_DIR"
else
    echo "❌ Failed to complete synchronization."
fi
