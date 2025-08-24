#!/bin/bash

# SpecGen Database Backup Script
# Creates remote backup and downloads to local machine

set -e

# Configuration
EC2_HOST="ubuntu@ec2-52-66-251-12.ap-south-1.compute.amazonaws.com"
EC2_KEY="debanshu.pem"
APP_DIR="/home/ubuntu/specgen-app"
LOCAL_BACKUP_DIR="backups"

# Create timestamp for backup
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="specgen-backup-$TIMESTAMP"
BACKUP_ARCHIVE="$BACKUP_NAME.tar.gz"

echo "🗄️  SpecGen Database Backup Starting..."
echo "📅 Timestamp: $TIMESTAMP"
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

# Check if database files exist
echo "🔍 Verifying database files..."
run_on_ec2 "
    missing_files=''
    for file in '$APP_DIR/server/data/database.json' '$APP_DIR/server/data/generated-content.db' '$APP_DIR/server/data/settings.json'; do
        if [ ! -f \"\$file\" ]; then
            missing_files=\"\$missing_files \$(basename \$file)\"
        fi
    done
    
    if [ ! -z \"\$missing_files\" ]; then
        echo \"❌ Missing database files:\$missing_files\"
        exit 1
    fi
    
    echo \"✅ All database files found\"
"

# Create remote backup directory and archive
echo "📦 Creating backup on EC2..."
run_on_ec2 "
    cd '$APP_DIR'
    
    # Create backup directory
    mkdir -p backups/'$BACKUP_NAME'
    
    # Copy database files to backup directory
    echo 'Copying database files...'
    cp server/data/database.json backups/'$BACKUP_NAME'/
    cp server/data/generated-content.db backups/'$BACKUP_NAME'/
    cp server/data/settings.json backups/'$BACKUP_NAME'/
    
    # Create metadata file
    cat > backups/'$BACKUP_NAME'/backup-info.txt << 'EOF'
Backup Created: $TIMESTAMP
Source: $APP_DIR/server/data/
Files:
  - database.json (categories and parameters)
  - generated-content.db (SQLite database)
  - settings.json (system configuration)
EOF
    
    # Create compressed archive
    echo 'Creating compressed archive...'
    cd backups
    tar -czf '$BACKUP_ARCHIVE' '$BACKUP_NAME'/
    
    # Verify archive
    if [ -f '$BACKUP_ARCHIVE' ]; then
        size=\$(du -h '$BACKUP_ARCHIVE' | cut -f1)
        echo \"✅ Backup archive created: '$BACKUP_ARCHIVE' (\$size)\"
    else
        echo \"❌ Failed to create backup archive\"
        exit 1
    fi
"

# Create local backup directory
echo "📁 Preparing local backup directory..."
mkdir -p "$LOCAL_BACKUP_DIR"

# Download backup from EC2
echo "⬇️  Downloading backup to local machine..."
if scp -i "$EC2_KEY" "$EC2_HOST:$APP_DIR/backups/$BACKUP_ARCHIVE" "$LOCAL_BACKUP_DIR/"; then
    echo "✅ Backup downloaded successfully to: $LOCAL_BACKUP_DIR/$BACKUP_ARCHIVE"
    
    # Verify local backup
    if [ -f "$LOCAL_BACKUP_DIR/$BACKUP_ARCHIVE" ]; then
        local_size=$(du -h "$LOCAL_BACKUP_DIR/$BACKUP_ARCHIVE" | cut -f1)
        echo "📊 Local backup size: $local_size"
    fi
else
    echo "❌ Failed to download backup from EC2"
    exit 1
fi

# Ask if user wants to keep remote backup
echo ""
read -p "🗑️  Keep backup on EC2? (y/n, default: n): " keep_remote
keep_remote=${keep_remote:-n}

if [[ "$keep_remote" =~ ^[Yy]$ ]]; then
    echo "✅ Remote backup preserved on EC2"
else
    echo "🧹 Cleaning up remote backup..."
    run_on_ec2 "
        cd '$APP_DIR/backups'
        rm -rf '$BACKUP_NAME' '$BACKUP_ARCHIVE'
        echo 'Remote backup files removed'
    "
fi

# List local backups
echo ""
echo "📋 Local backups available:"
ls -lh "$LOCAL_BACKUP_DIR"/ 2>/dev/null || echo "No previous backups found"

echo ""
echo "✅ Database backup completed successfully!"
echo ""
echo "📁 Backup location: $LOCAL_BACKUP_DIR/$BACKUP_ARCHIVE"
echo "🕐 Timestamp: $TIMESTAMP"
echo ""
echo "To restore this backup, use:"
echo "  ./scripts/restore-database.sh"