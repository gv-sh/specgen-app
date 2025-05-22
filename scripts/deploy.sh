#!/bin/bash

# SpecGen Deploy Script - Self-Contained Deployment on Port 8080
set -e

echo "🚀 Deploying SpecGen to production on port 8080..."
echo "📦 This is a complete deployment - no separate setup needed!"

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
# FULL CLEANUP
# ========================================

echo "🧹 Cleaning up existing installations..."

# Stop and remove all PM2 processes
npx pm2 stop all 2>/dev/null || true
npx pm2 delete all 2>/dev/null || true
npx pm2 kill 2>/dev/null || true

# Remove old PM2 config files
rm -f ecosystem.config.js 2>/dev/null || true

# Kill processes on all relevant ports
for port in 8080 3000 3001 3002; do
    if ! check_port $port; then
        echo "Killing processes on port $port..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
done

# Clean up old files
rm -rf logs/* 2>/dev/null || true

# ========================================
# VERIFY PREREQUISITES
# ========================================

echo "🔍 Checking prerequisites..."

# Check Node.js version
NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo "❌ Node.js 20+ required. Current version: $(node --version)"
    echo "Install with: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
fi

# Check if we have the required directories and files
echo "📂 Checking project structure..."
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found. This script must be run from the SpecGen project directory."
    echo "💡 Create a directory and run this script from there:"
    echo "   mkdir specgen && cd specgen"
    echo "   npx @gv-sh/specgen-app deploy"
    exit 1
fi

# ========================================
# SETUP OPENAI API KEY
# ========================================

echo "🔑 Setting up OpenAI API key..."

# Check if .env exists and has API key
if [ ! -f "server/.env" ] || grep -q "your_openai_api_key_here" server/.env 2>/dev/null; then
    if [ "$CI" = "true" ]; then
        echo "CI mode - using test API key"
        mkdir -p server
        echo "OPENAI_API_KEY=sk-test1234" > server/.env
        echo "NODE_ENV=production" >> server/.env
        echo "PORT=8080" >> server/.env
    else
        echo "⚠️ OpenAI API key required for SpecGen to work."
        echo "Enter your OpenAI API key: "
        read -r OPENAI_KEY
        
        if [ -z "$OPENAI_KEY" ]; then
            echo "❌ No API key provided. SpecGen needs an OpenAI API key to function."
            exit 1
        fi
        
        mkdir -p server
        echo "OPENAI_API_KEY=$OPENAI_KEY" > server/.env
        echo "NODE_ENV=production" >> server/.env
        echo "PORT=8080" >> server/.env
        echo "✅ API key saved"
    fi
fi

# ========================================
# BUILD APPLICATION
# ========================================

echo "🏗️ Building application components..."

# Install and build server
if [ ! -d "server" ] || [ ! -d "server/node_modules" ]; then
    echo "📦 Setting up server..."
    npm pack @gv-sh/specgen-server
    tar -xzf gv-sh-specgen-server-*.tgz
    mv package server
    rm gv-sh-specgen-server-*.tgz
    
    cd server
    echo "engine-strict=false" > .npmrc
    npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
    cd ..
fi

# Install and build admin
if [ ! -d "admin/build" ]; then
    echo "📱 Building admin interface..."
    if [ ! -d "admin" ]; then
        npm pack @gv-sh/specgen-admin
        tar -xzf gv-sh-specgen-admin-*.tgz
        mv package admin
        rm gv-sh-specgen-admin-*.tgz
    fi
    
    cd admin
    echo "engine-strict=false" > .npmrc
    npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
    GENERATE_SOURCEMAP=false SKIP_PREFLIGHT_CHECK=true PUBLIC_URL=/admin npm run build
    cd ..
fi

# Install and build user
if [ ! -d "user/build" ]; then
    echo "👤 Building user interface..."
    if [ ! -d "user" ]; then
        npm pack @gv-sh/specgen-user
        tar -xzf gv-sh-specgen-user-*.tgz
        mv package user
        rm gv-sh-specgen-user-*.tgz
    fi
    
    cd user
    echo "engine-strict=false" > .npmrc
    npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
    GENERATE_SOURCEMAP=false SKIP_PREFLIGHT_CHECK=true REACT_APP_API_URL=/api PUBLIC_URL=/app npm run build
    cd ..
fi

# ========================================
# VERIFY BUILDS
# ========================================

echo "✅ Verifying builds..."
if [ ! -d "admin/build" ]; then
    echo "❌ Admin build failed"
    exit 1
fi

if [ ! -d "user/build" ]; then
    echo "❌ User build failed"
    exit 1
fi

echo "📁 Build verification:"
echo "   Admin build: $(ls -la admin/build/ | wc -l) files"
echo "   User build: $(ls -la user/build/ | wc -l) files"
echo "   Server: $(ls -la server/ | wc -l) files"

# ========================================
# PM2 DEPLOYMENT
# ========================================

echo "🚀 Starting PM2 deployment..."

# Create PM2 ecosystem configuration
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'specgen',
    script: './server/index.js',
    cwd: process.cwd(),
    env: {
      NODE_ENV: 'production',
      PORT: 8080
    },
    instances: 1,
    exec_mode: 'fork',
    max_memory_restart: '500M',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    watch: false,
    ignore_watch: ['node_modules', 'logs', '*.log'],
    restart_delay: 1000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
}
EOF

# Create logs directory
mkdir -p logs

# Final port check
if ! check_port 8080; then
    echo "Port 8080 occupied, force cleaning..."
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Start with PM2
echo "▶️ Starting SpecGen with PM2..."
NODE_ENV=production PORT=8080 npx pm2 start ecosystem.config.js

# Wait for startup and verify
sleep 5

# ========================================
# DEPLOYMENT VERIFICATION
# ========================================

echo "🔍 Verifying deployment..."

if npx pm2 list | grep -q "online"; then
    # Test endpoints
    echo "Testing endpoints:"
    
    # Test health endpoint
    if curl -s http://localhost:8080/api/health >/dev/null 2>&1; then
        echo "✅ Health endpoint: OK"
    else
        echo "❌ Health endpoint: FAILED"
    fi
    
    # Test main page
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ | grep -q "200"; then
        echo "✅ Main page: OK"
    else
        echo "⚠️ Main page: Check logs"
    fi
    
    # Test admin
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/admin | grep -q "200"; then
        echo "✅ Admin page: OK"
    else
        echo "⚠️ Admin page: Check logs"
    fi
    
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null || echo 'your-server')
    
    echo ""
    echo "🎉 SpecGen deployment completed successfully!"
    echo ""
    echo "🌐 Access your application at:"
    echo "   - Main page: http://$PUBLIC_IP:8080/"
    echo "   - User app: http://$PUBLIC_IP:8080/app"
    echo "   - Admin panel: http://$PUBLIC_IP:8080/admin"
    echo "   - API docs: http://$PUBLIC_IP:8080/api-docs"
    echo "   - Health check: http://$PUBLIC_IP:8080/api/health"
    echo ""
    echo "📊 Management:"
    echo "   npx pm2 status     # Check status"
    echo "   npx pm2 logs       # View logs"
    echo "   npx pm2 restart specgen  # Restart"
    echo ""
    
else
    echo ""
    echo "❌ Deployment failed!"
    echo "📝 Check logs: npx pm2 logs specgen"
    echo "📊 Check status: npx pm2 status"
    npx pm2 logs specgen --lines 10
    exit 1
fi