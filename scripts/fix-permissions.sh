#!/bin/bash

# Fix permissions for SpecGen directories
set -e

echo "🔧 Fixing permissions..."

# Fix permissions for each directory if it exists
for dir in server admin user; do
    if [ -d "$dir" ]; then
        echo "Fixing permissions for $dir..."
        chmod -R u+w "$dir"
        chmod -R u+r "$dir"
        find "$dir" -type d -exec chmod u+x {} \;
    fi
done

echo "✅ Permissions fixed!"
