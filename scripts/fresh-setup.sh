#!/bin/bash

# Clean and fresh setup for Mac (handles permissions)
set -e

echo "🧹 Cleaning previous setup..."

# Function to safely remove directories with permission issues
safe_remove() {
    if [ -d "$1" ]; then
        echo "Removing $1..."
        chmod -R u+w "$1" 2>/dev/null || true
        rm -rf "$1" 2>/dev/null || true
    fi
}

# Remove extracted packages with proper permission handling
safe_remove "server"
safe_remove "admin" 
safe_remove "user"

# Remove any tgz files
rm -f *.tgz

echo "✨ Starting fresh setup..."

# Make sure we're not in root mode
if [ "$EUID" -eq 0 ]; then
    echo "Don't run this as root/sudo!"
    exit 1
fi

npm run setup:mac
