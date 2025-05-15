#!/bin/bash

# Copy config files from local source repositories
set -e

echo "📁 Copying config files from local source repositories..."

# Define source paths
SERVER_SOURCE="/Users/gvsh/workspace/specgen/specgen-server"
ADMIN_SOURCE="/Users/gvsh/workspace/specgen/specgen-admin"
USER_SOURCE="/Users/gvsh/workspace/specgen/specgen-user"

# Function to copy file if it exists
copy_if_exists() {
    local source=$1
    local dest=$2
    if [ -f "$source" ]; then
        echo "Copying $(basename $source)..."
        cp "$source" "$dest"
    else
        echo "Warning: $source not found"
    fi
}

# Copy admin configs and CSS
if [ -d "admin" ] && [ -d "$ADMIN_SOURCE" ]; then
    echo "=== Copying admin files ==="
    
    # Config files
    copy_if_exists "$ADMIN_SOURCE/tailwind.config.js" "admin/tailwind.config.js"
    copy_if_exists "$ADMIN_SOURCE/postcss.config.js" "admin/postcss.config.js"
    
    # CSS files
    mkdir -p admin/src
    copy_if_exists "$ADMIN_SOURCE/src/index.css" "admin/src/index.css"
    copy_if_exists "$ADMIN_SOURCE/src/App.css" "admin/src/App.css"
    
    # Copy src files (excluding env)
    if [ -f "$ADMIN_SOURCE/src/index.js" ]; then
        cp "$ADMIN_SOURCE/src/index.js" "admin/src/index.js"
    fi
fi

# Copy user configs and CSS
if [ -d "user" ] && [ -d "$USER_SOURCE" ]; then
    echo "=== Copying user files ==="
    
    # Config files
    copy_if_exists "$USER_SOURCE/tailwind.config.js" "user/tailwind.config.js"
    copy_if_exists "$USER_SOURCE/postcss.config.js" "user/postcss.config.js"
    
    # CSS files
    mkdir -p user/src
    copy_if_exists "$USER_SOURCE/src/index.css" "user/src/index.css"
    copy_if_exists "$USER_SOURCE/src/App.css" "user/src/App.css"
    
    # Copy src files (excluding env)
    if [ -f "$USER_SOURCE/src/index.js" ]; then
        cp "$USER_SOURCE/src/index.js" "user/src/index.js"
    fi
fi

echo "✅ Config files copied from local repositories!"
