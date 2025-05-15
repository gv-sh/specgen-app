#!/bin/bash

# Backup SpecGen application and database
set -e

BACKUP_DIR="/opt/backups/specgen"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="specgen-backup-$DATE"

echo "Creating backup: $BACKUP_NAME"

# Create backup directory
sudo mkdir -p $BACKUP_DIR

# Stop services for consistent backup
pm2 stop specgen-server

# Create backup
echo "Backing up application files..."
sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" -C /opt specgen-app

# Backup database separately if it exists
if [ -f /opt/specgen-app/server/data/database.json ]; then
    echo "Backing up database..."
    sudo cp /opt/specgen-app/server/data/database.json "$BACKUP_DIR/database-$DATE.json"
fi

# Restart services
pm2 start ecosystem.config.js

# Clean old backups (keep last 5)
echo "Cleaning old backups..."
cd $BACKUP_DIR
sudo ls -t *.tar.gz | tail -n +6 | sudo xargs rm -f || true
sudo ls -t database-*.json | tail -n +6 | sudo xargs rm -f || true

echo "Backup completed: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
