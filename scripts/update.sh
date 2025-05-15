#!/bin/bash

# Update SpecGen to latest versions
set -e

echo "Updating SpecGen application..."

# Backup current deployment
echo "Creating backup..."
sudo cp -r /opt/specgen-app /opt/specgen-app-backup-$(date +%Y%m%d-%H%M%S)

# Stop services
echo "Stopping services..."
pm2 stop specgen-server

# Navigate to app directory
cd /opt/specgen-app

# Download latest packages
echo "Downloading latest packages..."
npm pack @gv-sh/specgen-server
npm pack @gv-sh/specgen-admin  
npm pack @gv-sh/specgen-user

# Backup existing components
sudo mv server server-backup || true
sudo mv admin admin-backup || true
sudo mv user user-backup || true

# Extract new packages
echo "Extracting new packages..."
tar -xzf gv-sh-specgen-server-*.tgz && mv package server
tar -xzf gv-sh-specgen-admin-*.tgz && mv package admin
tar -xzf gv-sh-specgen-user-*.tgz && mv package user

# Clean up tgz files
rm -f *.tgz

# Patch package.json files to fix scripts
echo "Patching package scripts..."
chmod +x scripts/patch-packages.sh
./scripts/patch-packages.sh

# Copy environment files from backup
echo "Restoring environment files..."
sudo cp server-backup/.env server/.env || echo "No server .env to restore"
sudo cp admin-backup/.env.production admin/.env.production || echo "No admin .env to restore"
sudo cp user-backup/.env.production user/.env.production || echo "No user .env to restore"

# Install dependencies
echo "Installing dependencies..."
cd server && npm install --production
cd ../admin && npm install --production
cd ../user && npm install --production
cd ..

# Build React apps
echo "Building React applications..."
cd admin && NODE_ENV=production npm run build
cd ../user && NODE_ENV=production npm run build
cd ..

# Start services
echo "Starting services..."
pm2 start ecosystem.config.js

# Clean up old backups (keep last 3)
echo "Cleaning up old component backups..."
sudo rm -rf server-backup admin-backup user-backup

echo "Update completed successfully!"
echo "Check logs with: pm2 logs specgen-server"
