#!/bin/bash

# Quick CSS fix for development
set -e

echo "🎨 Fixing CSS and styling issues..."

# Clear any cached builds
echo "Clearing cache..."
rm -rf admin/build admin/.eslintcache admin/node_modules/.cache || true
rm -rf user/build user/.eslintcache user/node_modules/.cache || true

# Reinstall dependencies to ensure CSS loaders are properly configured
echo "Reinstalling dependencies..."
cd admin && rm -rf node_modules && npm install
cd ../user && rm -rf node_modules && npm install
cd ..

echo "CSS fix applied! Now restart the dev servers."
