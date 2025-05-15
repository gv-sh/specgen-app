#!/bin/bash

# Show SpecGen application status
set -e

echo "=== SpecGen Application Status ==="

# PM2 processes
echo -e "\nPM2 Processes:"
pm2 list

# Nginx status
echo -e "\nNginx Status:"
sudo systemctl status nginx --no-pager -l

# Server logs (last 20 lines)
echo -e "\nServer Logs (last 20 lines):"
pm2 logs specgen-server --lines 20

# Disk usage of app directory
echo -e "\nDisk Usage:"
du -sh /opt/specgen-app

# Memory usage
echo -e "\nMemory Usage:"
free -h

# Port status
echo -e "\nPort Status:"
sudo netstat -tlpn | grep -E ':80|:3000|:443'
