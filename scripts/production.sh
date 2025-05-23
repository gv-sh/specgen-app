#!/bin/bash

# SpecGen Production Script - Low Memory, Port 80 with Cleanup
set -e

echo "🚀 Starting SpecGen in production mode on port 80..."
echo "🧹 Cleaning up existing processes..."

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port in use
    else
        return 0  # Port available
    fi
}

# ========================================
# CLEANUP EXISTING PROCESSES
# ========================================

# Stop and cleanup PM2 processes
echo "Stopping existing PM2 processes..."
npx pm2 stop all 2>/dev/null || true
npx pm2 delete all 2>/dev/null || true

# Kill processes on ports we'll use
echo "Freeing ports..."
for port in 80 3000 3001 3002; do
    if ! check_port $port; then
        echo "Port $port is in use. Attempting to free it..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
done

# Stop nginx if it might interfere
if command -v nginx &> /dev/null && systemctl is-active --quiet nginx 2>/dev/null; then
    echo "Nginx is running, checking for conflicts..."
    if nginx -T 2>/dev/null | grep -q ":80"; then
        echo "⚠️ Nginx is configured to use port 80. You may need to reconfigure nginx."
    fi
fi

# ========================================
# VERIFY SETUP
# ========================================

# Verify OpenAI API key
if [ -f "server/.env" ]; then
    # In CI mode, skip API key validation
    if [ "$CI" = "true" ]; then
        echo "CI mode detected - skipping API key validation"
    elif grep -q "OPENAI_API_KEY=your_openai_api_key_here" server/.env; then
        echo "⚠️ No OpenAI API key detected!"
        echo "Enter your OpenAI API key: "
        read -r OPENAI_KEY
        
        if [ -z "$OPENAI_KEY" ]; then
            echo "❌ No API key provided. Cannot start in production mode."
            exit 1
        else
            # Update the API key in the .env file
            sed -i.bak "s/OPENAI_API_KEY=.*/OPENAI_API_KEY=$OPENAI_KEY/" server/.env
            rm -f server/.env.bak
            echo "✅ API key updated in server/.env"
        fi
    fi
else
    echo "❌ server/.env file not found. Run 'npm run setup' first."
    exit 1
fi

# Verify directories exist
for dir in server admin user; do
    if [ ! -d "$dir" ]; then
        echo "❌ $dir directory not found. Run 'npm run setup' first."
        exit 1
    fi
done

# ========================================
# INSTALL DEPENDENCIES
# ========================================

# Make sure node_modules exist in the server directory
if [ ! -d "server/node_modules" ]; then
    echo "Installing server dependencies..."
    cd server
    # Create a .npmrc file that ignores engine requirements
    echo "engine-strict=false" > .npmrc
    npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
    cd ..
fi

# Set production environment
export NODE_ENV=production

# ========================================
# BUILD INTERFACES
# ========================================

# Check if we need to build
if [ ! -d "admin/build" ] || [ ! -d "user/build" ]; then
    echo "Building web interfaces (optimized mode)..."
    
    # Admin build
    if [ ! -d "admin/build" ]; then
        echo "Building admin..."
        cd admin
        echo "engine-strict=false" > .npmrc
        # Install only production dependencies
        npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
        # Set environment for smaller build
        export GENERATE_SOURCEMAP=false
        export SKIP_PREFLIGHT_CHECK=true
        npm run build
        cd ..
    fi
    
    # User build
    if [ ! -d "user/build" ]; then
        echo "Building user..."
        cd user
        echo "engine-strict=false" > .npmrc
        # Install only production dependencies
        npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
        # Set environment for smaller build
        export GENERATE_SOURCEMAP=false
        export SKIP_PREFLIGHT_CHECK=true
        npm run build
        cd ..
    fi
fi

# ========================================
# CONFIGURE ENVIRONMENT
# ========================================

# Update server .env to use port 80
if [ -f "server/.env" ]; then
    # Update or add PORT=80 to .env
    if grep -q "^PORT=" server/.env; then
        sed -i.bak "s/^PORT=.*/PORT=80/" server/.env
    else
        echo "PORT=80" >> server/.env
    fi
    rm -f server/.env.bak
fi

# Create production-ready .env for server
cat > server/.env.production << EOF
$(cat server/.env)
NODE_ENV=production
PORT=80
EOF

# Create logs directory
mkdir -p logs

# ========================================
# START SERVER
# ========================================

# Final port check
echo "Final check for port 80..."
if ! check_port 80; then
    echo "Port 80 is still in use after cleanup. Force killing..."
    lsof -ti:80 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Start production server
echo "Starting production server on port 80..."
if [ "$CI" = "true" ]; then
    echo "CI mode detected - skipping server start"
else
    cd server && NODE_ENV=production PORT=80 npm start
fi