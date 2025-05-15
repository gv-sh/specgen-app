#!/bin/bash

# Stop SpecGen services
set -e

echo "Stopping SpecGen services..."

# Stop PM2 processes
pm2 stop specgen-server || echo "Server not running"

# Stop Nginx (optional - uncomment if needed)
# sudo systemctl stop nginx

echo "SpecGen stopped successfully"
