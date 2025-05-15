#!/bin/bash

# Restart SpecGen services
set -e

echo "Restarting SpecGen services..."

# Restart PM2 processes
pm2 restart specgen-server || echo "Starting server..."
pm2 start ecosystem.config.js || echo "Server started"

# Restart Nginx
sudo systemctl restart nginx

# Show status
pm2 status
sudo systemctl status nginx --no-pager -l

echo "SpecGen restarted successfully"
