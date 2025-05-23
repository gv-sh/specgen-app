#!/bin/bash

# SpecGen App Setup Script - Low Memory Default with Full Cleanup
set -e

echo "🚀 Setting up SpecGen App (Low Memory Mode)..."
echo "🧹 This will clean up any existing installations..."

# Check Node.js
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Function to safely remove directories with permission handling
safe_remove() {
    if [ -d "$1" ]; then
        echo "Removing $1..."
        chmod -R u+w "$1" 2>/dev/null || true
        rm -rf "$1" 2>/dev/null || true
        # If still exists, try with sudo
        if [ -d "$1" ]; then
            echo "Using elevated permissions to remove $1..."
            sudo rm -rf "$1" 2>/dev/null || true
        fi
    fi
}

# ========================================
# CLEANUP EXISTING INSTALLATIONS
# ========================================

echo "🧹 Cleaning up existing installations..."

# 1. Stop and remove all PM2 processes
echo "Stopping PM2 processes..."
npx pm2 stop all 2>/dev/null || true
npx pm2 delete all 2>/dev/null || true
npx pm2 kill 2>/dev/null || true

# Remove PM2 configuration files
rm -f ecosystem.config.js 2>/dev/null || true
rm -f pm2.config.js 2>/dev/null || true
rm -rf ~/.pm2/logs/* 2>/dev/null || true

# 2. Kill processes on ports we'll use
echo "Freeing up ports..."
for port in 80 3000 3001 3002; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "Killing processes on port $port..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
done

# 3. Stop nginx if running and remove specgen configs
echo "Cleaning up nginx..."
if command -v nginx &> /dev/null; then
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Remove any specgen-related nginx configs
    sudo rm -f /etc/nginx/sites-available/specgen* 2>/dev/null || true
    sudo rm -f /etc/nginx/sites-enabled/specgen* 2>/dev/null || true
    sudo rm -f /etc/nginx/conf.d/specgen* 2>/dev/null || true
    
    # Test nginx config and restart if valid
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl start nginx 2>/dev/null || true
    else
        echo "⚠️ Nginx config has issues, leaving it stopped"
    fi
fi

# 4. Clean up any systemd services
echo "Cleaning up systemd services..."
if systemctl list-units --type=service | grep -q specgen; then
    sudo systemctl stop specgen* 2>/dev/null || true
    sudo systemctl disable specgen* 2>/dev/null || true
    sudo rm -f /etc/systemd/system/specgen* 2>/dev/null || true
    sudo systemctl daemon-reload 2>/dev/null || true
fi

# 5. Clean up Docker containers if any
if command -v docker &> /dev/null; then
    echo "Cleaning up Docker containers..."
    docker stop $(docker ps -q --filter "name=specgen") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=specgen") 2>/dev/null || true
fi

# ========================================
# CLEAN PROJECT DIRECTORIES
# ========================================

echo "Cleaning existing project directories..."
safe_remove "server"
safe_remove "admin" 
safe_remove "user"
safe_remove "logs"
safe_remove "node_modules"
rm -f *.tgz package 2>/dev/null || true
rm -f *.log 2>/dev/null || true
rm -f ecosystem.config.js 2>/dev/null || true

# ========================================
# FRESH INSTALLATION
# ========================================

# Install dependencies to get latest versions
echo "📦 Installing dependencies (low memory mode)..."
npm install --no-fund --no-audit --maxsockets=2 --loglevel=warn

# Download npm packages
echo "📦 Downloading packages..."
npm pack @gv-sh/specgen-server
npm pack @gv-sh/specgen-admin
npm pack @gv-sh/specgen-user

# Extract packages
echo "📁 Extracting packages..."

# Extract server
if [ -f "gv-sh-specgen-server-"*.tgz ]; then
    echo "Extracting server..."
    tar -xzf gv-sh-specgen-server-*.tgz
    mv package server
    rm gv-sh-specgen-server-*.tgz
fi

# Extract admin
if [ -f "gv-sh-specgen-admin-"*.tgz ]; then
    echo "Extracting admin..."
    tar -xzf gv-sh-specgen-admin-*.tgz
    mv package admin
    rm gv-sh-specgen-admin-*.tgz
fi

# Extract user
if [ -f "gv-sh-specgen-user-"*.tgz ]; then
    echo "Extracting user..."
    tar -xzf gv-sh-specgen-user-*.tgz
    mv package user
    rm gv-sh-specgen-user-*.tgz
fi

# Install dependencies for each component (low memory)
echo "📚 Installing dependencies (low memory mode)..."
for dir in server admin user; do
    if [ -d "$dir" ]; then
        echo "Installing $dir dependencies..."
        cd "$dir"
        # Create .npmrc for low memory mode
        echo "engine-strict=false" > .npmrc
        npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
        cd ..
    else
        echo "⚠️  Warning: $dir directory not found"
    fi
done

# ========================================
# SETUP ENVIRONMENT FILES
# ========================================

echo "🔧 Setting up environment files..."

# Server .env (default to port 80)
if [ ! -f server/.env ] || [ "$CI" = "true" ]; then
    # If in CI mode, use a dummy key
    if [ "$CI" = "true" ]; then
        if [ -f server/.env ]; then
            echo "Using existing .env file for CI environment"
        else
            cat > server/.env << EOF
OPENAI_API_KEY=sk-test1234
NODE_ENV=test
PORT=80
EOF
            echo "Created test .env file for CI environment"
        fi
        KEY_PROVIDED=true
    else
        # Normal interactive mode
        echo "To use SpecGen, you need an OpenAI API key."
        echo "Enter your OpenAI API key (or press enter to set it later): "
        read -r OPENAI_KEY
        
        # If key is provided, use it, otherwise use placeholder
        if [ -z "$OPENAI_KEY" ]; then
            OPENAI_KEY="your_openai_api_key_here"
            KEY_PROVIDED=false
        else
            KEY_PROVIDED=true
        fi
        
        cat > server/.env << EOF
# OpenAI API key
OPENAI_API_KEY=$OPENAI_KEY
NODE_ENV=development
PORT=80
EOF
        
        if [ "$KEY_PROVIDED" = true ]; then
            echo "✅ OpenAI API key saved to server/.env"
        else
            echo "⚠️ No OpenAI API key provided. You'll need to add it later to server/.env"
        fi
    fi
fi

# Admin .env.development  
if [ -d admin ]; then
    cat > admin/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:80
PORT=3001
SKIP_PREFLIGHT_CHECK=true
GENERATE_SOURCEMAP=false
EOF
fi

# User .env.development
if [ -d user ]; then
    cat > user/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:80
PORT=3002
SKIP_PREFLIGHT_CHECK=true
GENERATE_SOURCEMAP=false
EOF
fi

# Create logs directory
mkdir -p logs

echo ""
echo "✅ Setup complete! All previous installations cleaned up."
echo ""
echo "🧹 Cleaned up:"
echo "  - PM2 processes and configurations"
echo "  - Nginx specgen configurations"
echo "  - Systemd services"
echo "  - Docker containers"
echo "  - Old project files"
echo "  - Freed ports: 80, 3000, 3001, 3002"
echo ""
echo "Next steps:"
if [ "$KEY_PROVIDED" = false ]; then
    echo "1. Add your OpenAI API key to server/.env"
    echo "2. Run 'npm run dev' to start all services"
    echo "3. Or run 'npm run production' for production mode on port 80"
else
    echo "1. Run 'npm run dev' to start all services"
    echo "2. Or run 'npm run production' for production mode on port 80"
fi
echo ""
echo "Access URLs:"
echo "  🌐 Production: http://localhost:80 (main app)"
echo "  📱 Production User: http://localhost:80/app"
echo "  ⚙️ Production Admin: http://localhost:80/admin"
echo "  📚 API Docs: http://localhost:80/api-docs"
echo ""
echo "Development URLs:"
echo "  🌐 User Interface: http://localhost:3002"
echo "  ⚙️ Admin Interface: http://localhost:3001"  
echo "  🔧 API: http://localhost:80"