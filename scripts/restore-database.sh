#!/bin/bash

# SpecGen Database Restore Script
# Restores database from local or remote backup

set -e

# Configuration
EC2_HOST="ubuntu@ec2-52-66-251-12.ap-south-1.compute.amazonaws.com"
EC2_KEY="debanshu.pem"
APP_DIR="/home/ubuntu/specgen-app"
LOCAL_BACKUP_DIR="backups"

echo "🔄 SpecGen Database Restore Starting..."
echo "📡 Target: $EC2_HOST"

# Check if key file exists
if [ ! -f "$EC2_KEY" ]; then
    echo "❌ SSH key file '$EC2_KEY' not found!"
    echo "Please ensure the key file is in the current directory."
    exit 1
fi

# Function to run commands on EC2
run_on_ec2() {
    ssh -i "$EC2_KEY" "$EC2_HOST" "$1"
}

# Check if remote app directory exists
echo "🔍 Checking remote application..."
if ! run_on_ec2 "[ -d '$APP_DIR' ]"; then
    echo "❌ Remote application directory not found: $APP_DIR"
    echo "Please ensure SpecGen is deployed on the EC2 instance."
    exit 1
fi

# Function to list local backups
list_local_backups() {
    if [ -d "$LOCAL_BACKUP_DIR" ]; then
        local_backups=($(ls -1 "$LOCAL_BACKUP_DIR"/*.tar.gz 2>/dev/null | sort -r | head -10))
        if [ ${#local_backups[@]} -gt 0 ]; then
            echo "📁 Local backups available:"
            for i in "${!local_backups[@]}"; do
                backup_file=$(basename "${local_backups[$i]}")
                size=$(du -h "${local_backups[$i]}" | cut -f1)
                echo "  $((i+1)). $backup_file ($size)"
            done
            return 0
        fi
    fi
    echo "📁 No local backups found"
    return 1
}

# Function to list remote backups
list_remote_backups() {
    remote_list=$(run_on_ec2 "
        if [ -d '$APP_DIR/backups' ]; then
            cd '$APP_DIR/backups'
            ls -1 *.tar.gz 2>/dev/null | sort -r | head -10
        fi
    " 2>/dev/null)
    
    if [ ! -z "$remote_list" ]; then
        echo "☁️  Remote backups available:"
        echo "$remote_list" | nl -w2 -s'. '
        return 0
    else
        echo "☁️  No remote backups found"
        return 1
    fi
}

# Show available backups
echo ""
has_local=$(list_local_backups && echo "true" || echo "false")
echo ""
has_remote=$(list_remote_backups && echo "true" || echo "false")
echo ""

if [ "$has_local" = "false" ] && [ "$has_remote" = "false" ]; then
    echo "❌ No backups found locally or remotely!"
    echo "Please create a backup first using: ./scripts/backup-database.sh"
    exit 1
fi

# Choose backup source
echo "Select backup source:"
if [ "$has_local" = "true" ]; then
    echo "  1. Local backup"
fi
if [ "$has_remote" = "true" ]; then
    echo "  2. Remote backup"
fi
echo "  0. Cancel"

read -p "Choice: " source_choice

case $source_choice in
    1)
        if [ "$has_local" = "false" ]; then
            echo "❌ No local backups available"
            exit 1
        fi
        source_type="local"
        ;;
    2)
        if [ "$has_remote" = "false" ]; then
            echo "❌ No remote backups available"
            exit 1
        fi
        source_type="remote"
        ;;
    0)
        echo "❌ Restore cancelled"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Select specific backup
if [ "$source_type" = "local" ]; then
    echo ""
    list_local_backups
    echo ""
    read -p "Select backup number (1-10): " backup_choice
    
    local_backups=($(ls -1 "$LOCAL_BACKUP_DIR"/*.tar.gz 2>/dev/null | sort -r | head -10))
    if [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#local_backups[@]} ]; then
        selected_backup="${local_backups[$((backup_choice-1))]}"
        backup_name=$(basename "$selected_backup")
    else
        echo "❌ Invalid backup selection"
        exit 1
    fi
else
    echo ""
    list_remote_backups
    echo ""
    read -p "Select backup number (1-10): " backup_choice
    
    remote_backups=($(run_on_ec2 "cd '$APP_DIR/backups' && ls -1 *.tar.gz 2>/dev/null | sort -r | head -10"))
    if [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#remote_backups[@]} ]; then
        backup_name="${remote_backups[$((backup_choice-1))]}"
    else
        echo "❌ Invalid backup selection"
        exit 1
    fi
fi

echo "📋 Selected backup: $backup_name"
echo ""

# Confirm restore
echo "⚠️  WARNING: This will replace the current database files on EC2!"
read -p "Are you sure you want to restore? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Restore cancelled"
    exit 0
fi

# Create safety backup of current state
echo "🛡️  Creating safety backup of current state..."
SAFETY_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SAFETY_BACKUP="safety-backup-$SAFETY_TIMESTAMP"

run_on_ec2 "
    cd '$APP_DIR'
    mkdir -p backups/'$SAFETY_BACKUP'
    
    # Copy current database files
    cp server/data/database.json backups/'$SAFETY_BACKUP'/ 2>/dev/null || echo 'database.json not found'
    cp server/data/generated-content.db backups/'$SAFETY_BACKUP'/ 2>/dev/null || echo 'generated-content.db not found'  
    cp server/data/settings.json backups/'$SAFETY_BACKUP'/ 2>/dev/null || echo 'settings.json not found'
    
    # Create safety backup archive
    cd backups
    tar -czf '$SAFETY_BACKUP.tar.gz' '$SAFETY_BACKUP'/
    rm -rf '$SAFETY_BACKUP'
    
    echo '✅ Safety backup created: $SAFETY_BACKUP.tar.gz'
"

# Handle local backup upload if needed
if [ "$source_type" = "local" ]; then
    echo "⬆️  Uploading backup to EC2..."
    if ! scp -i "$EC2_KEY" "$selected_backup" "$EC2_HOST:$APP_DIR/backups/"; then
        echo "❌ Failed to upload backup to EC2"
        exit 1
    fi
    echo "✅ Backup uploaded successfully"
fi

# Stop PM2 service
echo "🛑 Stopping SpecGen service..."
run_on_ec2 "
    cd '$APP_DIR/server'
    npx pm2 stop specgen 2>/dev/null || echo 'Service not running'
"

# Restore database files
echo "🔄 Restoring database files..."
run_on_ec2 "
    cd '$APP_DIR/backups'
    
    # Extract backup
    if [ ! -f '$backup_name' ]; then
        echo '❌ Backup file not found: $backup_name'
        exit 1
    fi
    
    # Create temporary extraction directory
    temp_dir='restore_temp_$(date +%s)'
    mkdir -p \"\$temp_dir\"
    
    # Extract archive
    if ! tar -xzf '$backup_name' -C \"\$temp_dir\"; then
        echo '❌ Failed to extract backup archive'
        rm -rf \"\$temp_dir\"
        exit 1
    fi
    
    # Find the backup directory inside extracted content
    backup_dir=\$(ls -1 \"\$temp_dir\" | head -1)
    
    if [ -z \"\$backup_dir\" ]; then
        echo '❌ No backup directory found in archive'
        rm -rf \"\$temp_dir\"
        exit 1
    fi
    
    # Restore files
    echo 'Restoring database files...'
    cp \"\$temp_dir/\$backup_dir/database.json\" '$APP_DIR/server/data/' 2>/dev/null || echo 'database.json not in backup'
    cp \"\$temp_dir/\$backup_dir/generated-content.db\" '$APP_DIR/server/data/' 2>/dev/null || echo 'generated-content.db not in backup'
    cp \"\$temp_dir/\$backup_dir/settings.json\" '$APP_DIR/server/data/' 2>/dev/null || echo 'settings.json not in backup'
    
    # Cleanup
    rm -rf \"\$temp_dir\"
    
    echo '✅ Database files restored successfully'
"

# Clean up uploaded backup if it was local
if [ "$source_type" = "local" ]; then
    run_on_ec2 "rm -f '$APP_DIR/backups/$backup_name'"
fi

# Restart PM2 service
echo "🚀 Starting SpecGen service..."
run_on_ec2 "
    cd '$APP_DIR/server'
    
    # Start service
    if [ -f deploy/ecosystem.config.js ]; then
        npx pm2 start deploy/ecosystem.config.js
    else
        npx pm2 start index.js --name specgen
    fi
"

# Wait for service to start
echo "⏳ Waiting for service to start..."
sleep 5

# Verify restore
echo "🧪 Verifying restore..."
HEALTH_CHECK=$(run_on_ec2 "curl -s http://localhost:80/api/health | jq -r '.status' 2>/dev/null || echo 'failed'")

if [ "$HEALTH_CHECK" = "healthy" ]; then
    echo "✅ Database restore completed successfully!"
    echo ""
    echo "📋 Restored from: $backup_name"
    echo "🛡️  Safety backup: $SAFETY_BACKUP.tar.gz"
    echo "🌐 Service status: Healthy"
    echo ""
    echo "📊 PM2 Status:"
    run_on_ec2 "cd '$APP_DIR/server' && npx pm2 status"
else
    echo "❌ Service health check failed after restore!"
    echo "🔄 Rolling back to safety backup..."
    
    # Rollback using safety backup
    run_on_ec2 "
        cd '$APP_DIR/server'
        npx pm2 stop specgen 2>/dev/null || true
        
        cd '$APP_DIR/backups'
        temp_dir='rollback_temp_$(date +%s)'
        mkdir -p \"\$temp_dir\"
        tar -xzf '$SAFETY_BACKUP.tar.gz' -C \"\$temp_dir\"
        backup_dir=\$(ls -1 \"\$temp_dir\" | head -1)
        
        cp \"\$temp_dir/\$backup_dir/\"* '$APP_DIR/server/data/'
        rm -rf \"\$temp_dir\"
        
        cd '$APP_DIR/server'
        if [ -f deploy/ecosystem.config.js ]; then
            npx pm2 start deploy/ecosystem.config.js
        else
            npx pm2 start index.js --name specgen
        fi
        
        echo 'Rollback completed'
    "
    
    echo "🔄 Rolled back to previous state"
    exit 1
fi