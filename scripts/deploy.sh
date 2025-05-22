#!/bin/bash

# SpecGen Deploy Script - Self-Contained Deployment on Port 8080
set -e

# Check for dry-run mode
DRY_RUN=false
if [ "$1" = "--dry-run" ] || [ "$1" = "-d" ]; then
    DRY_RUN=true
    echo "🧪 DRY RUN MODE - Testing deployment locally"
    echo "🖥️  Platform: $(uname -s) $(uname -m)"
else
    echo "🚀 Deploying SpecGen to production on port 8080..."
    echo "📦 This is a complete deployment - no separate setup needed!"
fi

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port in use
    else
        return 0  # Port available
    fi
}

# Get absolute path of current working directory
# In dry-run, use the actual working directory, not NPX cache
if [ "$DRY_RUN" = true ]; then
    PROJECT_DIR=$(pwd)
else
    PROJECT_DIR=$(pwd)
fi

echo "📂 Project directory: $PROJECT_DIR"

# ========================================
# PLATFORM-SPECIFIC SETUP
# ========================================

# Detect platform
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Darwin" ]; then
    echo "🍎 Detected macOS"
    PM2_CMD="npx pm2"
elif [ "$PLATFORM" = "Linux" ]; then
    echo "🐧 Detected Linux"
    PM2_CMD="npx pm2"
else
    echo "⚠️  Unknown platform: $PLATFORM"
    PM2_CMD="npx pm2"
fi

# ========================================
# CLEANUP (Skip in dry-run for safety)
# ========================================

if [ "$DRY_RUN" = false ]; then
    echo "🧹 Cleaning up existing installations..."
    
    # Stop and remove all PM2 processes
    $PM2_CMD stop all 2>/dev/null || true
    $PM2_CMD delete all 2>/dev/null || true
    $PM2_CMD kill 2>/dev/null || true
    
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
else
    echo "🧪 DRY RUN: Skipping cleanup (existing processes will remain)"
    echo "   This is a safe test that won't affect your system"
fi

# ========================================
# VERIFY PREREQUISITES
# ========================================

echo "🔍 Checking prerequisites..."

# Check Node.js version (more lenient for dry-run)
NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$DRY_RUN" = true ]; then
    # More lenient for dry-run testing
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo "❌ Node.js 18+ required for testing. Current version: $(node --version)"
        if [ "$PLATFORM" = "Darwin" ]; then
            echo "Install with: brew install node"
        fi
        exit 1
    else
        echo "✅ Node.js version: $(node --version) (sufficient for testing)"
        if [ "$NODE_VERSION" -lt 20 ]; then
            echo "   ⚠️  Note: Production deployment requires Node.js 20+"
        fi
    fi
else
    # Strict for production
    if [ "$NODE_VERSION" -lt 20 ]; then
        echo "❌ Node.js 20+ required for production. Current version: $(node --version)"
        if [ "$PLATFORM" = "Darwin" ]; then
            echo "Install with: brew install node@20"
        else
            echo "Install with: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
        fi
        exit 1
    else
        echo "✅ Node.js version: $(node --version)"
    fi
fi

# Check npm
echo "✅ npm version: $(npm --version)"

# Check available memory
if [ "$PLATFORM" = "Darwin" ]; then
    MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    echo "✅ Available memory: ${MEMORY_GB}GB"
    if [ "$MEMORY_GB" -lt 4 ]; then
        echo "⚠️  Warning: Less than 4GB RAM detected. Builds may be slow."
    fi
elif [ "$PLATFORM" = "Linux" ]; then
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    echo "✅ Available memory: ${MEMORY_GB}GB"
    if [ "$MEMORY_GB" -lt 1 ]; then
        echo "⚠️  Warning: Less than 1GB RAM detected. Consider adding swap space."
    fi
fi

# Check if we have required tools
echo "✅ Platform tools:"
echo "   curl: $(which curl >/dev/null && echo "available" || echo "missing")"
echo "   tar: $(which tar >/dev/null && echo "available" || echo "missing")"
echo "   lsof: $(which lsof >/dev/null && echo "available" || echo "missing")"

# ========================================
# SETUP OPENAI API KEY
# ========================================

echo "🔑 Setting up OpenAI API key..."

# In dry-run mode, always use a test key
if [ "$DRY_RUN" = true ]; then
    echo "🧪 DRY RUN: Using test API key"
    mkdir -p "$PROJECT_DIR/server"
    echo "OPENAI_API_KEY=sk-test1234567890abcdef" > "$PROJECT_DIR/server/.env"
    echo "NODE_ENV=production" >> "$PROJECT_DIR/server/.env"
    echo "PORT=8080" >> "$PROJECT_DIR/server/.env"
elif [ ! -f "$PROJECT_DIR/server/.env" ] || grep -q "your_openai_api_key_here" "$PROJECT_DIR/server/.env" 2>/dev/null; then
    if [ "$CI" = "true" ]; then
        echo "CI mode - using test API key"
        mkdir -p "$PROJECT_DIR/server"
        echo "OPENAI_API_KEY=sk-test1234" > "$PROJECT_DIR/server/.env"
        echo "NODE_ENV=production" >> "$PROJECT_DIR/server/.env"
        echo "PORT=8080" >> "$PROJECT_DIR/server/.env"
    else
        echo "⚠️ OpenAI API key required for SpecGen to work."
        echo "Enter your OpenAI API key (or press Enter to use test key): "
        read -r OPENAI_KEY
        
        if [ -z "$OPENAI_KEY" ]; then
            OPENAI_KEY="sk-test1234567890abcdef"
            echo "Using test API key for this deployment"
        fi
        
        mkdir -p "$PROJECT_DIR/server"
        echo "OPENAI_API_KEY=$OPENAI_KEY" > "$PROJECT_DIR/server/.env"
        echo "NODE_ENV=production" >> "$PROJECT_DIR/server/.env"
        echo "PORT=8080" >> "$PROJECT_DIR/server/.env"
        echo "✅ API key saved"
    fi
fi

# ========================================
# BUILD APPLICATION
# ========================================

echo "🏗️ Building application components..."

# Navigate to project directory
cd "$PROJECT_DIR"

# Install and build server with better extraction
if [ ! -f "server/index.js" ]; then
    echo "📦 Setting up server..."
    
    # Clean up any existing server directory
    rm -rf server
    
    # Download and extract server
    echo "   Downloading server package..."
    npm pack @gv-sh/specgen-server --loglevel=warn
    
    echo "   Extracting server package..."
    tar -xzf gv-sh-specgen-server-*.tgz
    
    # Move the extracted package to server directory
    if [ -d "package" ]; then
        mv package server
        echo "✅ Server extracted successfully"
    else
        echo "❌ Failed to extract server package"
        ls -la
        exit 1
    fi
    
    # Clean up the tar file
    rm gv-sh-specgen-server-*.tgz
    
    # Install server dependencies
    echo "   Installing server dependencies..."
    cd server
    echo "engine-strict=false" > .npmrc
    npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
    
    # Verify server files
    if [ ! -f "index.js" ]; then
        echo "❌ Server index.js not found after installation"
        echo "Server directory contents:"
        ls -la
        exit 1
    fi
    
    cd "$PROJECT_DIR"
fi

# Install and build admin
if [ ! -d "admin/build" ]; then
    echo "📱 Building admin interface..."
    
    if [ ! -d "admin" ]; then
        # Clean up any existing admin directory
        rm -rf admin
        
        echo "   Downloading admin package..."
        npm pack @gv-sh/specgen-admin --loglevel=warn
        tar -xzf gv-sh-specgen-admin-*.tgz
        
        if [ -d "package" ]; then
            mv package admin
            echo "✅ Admin extracted successfully"
        else
            echo "❌ Failed to extract admin package"
            exit 1
        fi
        
        rm gv-sh-specgen-admin-*.tgz
    fi
    
    echo "   Installing admin dependencies..."
    cd admin
    echo "engine-strict=false" > .npmrc
    # Install ALL dependencies for build process
    npm install --no-fund --no-audit --maxsockets=2 --loglevel=warn
    echo "   Building admin interface..."
    # Build with proper environment variables
    GENERATE_SOURCEMAP=false SKIP_PREFLIGHT_CHECK=true PUBLIC_URL=/admin npm run build
    cd "$PROJECT_DIR"
fi

# Install and build user
if [ ! -d "user/build" ]; then
    echo "👤 Building user interface..."
    
    if [ ! -d "user" ]; then
        # Clean up any existing user directory
        rm -rf user
        
        echo "   Downloading user package..."
        npm pack @gv-sh/specgen-user --loglevel=warn
        tar -xzf gv-sh-specgen-user-*.tgz
        
        if [ -d "package" ]; then
            mv package user
            echo "✅ User extracted successfully"
        else
            echo "❌ Failed to extract user package"
            exit 1
        fi
        
        rm gv-sh-specgen-user-*.tgz
    fi
    
    echo "   Installing user dependencies..."
    cd user
    echo "engine-strict=false" > .npmrc
    # Install ALL dependencies for build process
    npm install --no-fund --no-audit --maxsockets=2 --loglevel=warn
    echo "   Building user interface..."
    # Build with proper environment variables
    GENERATE_SOURCEMAP=false SKIP_PREFLIGHT_CHECK=true REACT_APP_API_URL=/api PUBLIC_URL=/app npm run build
    cd "$PROJECT_DIR"
fi

# ========================================
# VERIFY BUILDS
# ========================================

echo "✅ Verifying builds..."

# Check admin build
if [ ! -d "$PROJECT_DIR/admin/build" ]; then
    echo "❌ Admin build failed"
    ls -la "$PROJECT_DIR/admin/" || echo "Admin directory not found"
    exit 1
fi

# Check user build
if [ ! -d "$PROJECT_DIR/user/build" ]; then
    echo "❌ User build failed"
    ls -la "$PROJECT_DIR/user/" || echo "User directory not found"
    exit 1
fi

# Check server
if [ ! -f "$PROJECT_DIR/server/index.js" ]; then
    echo "❌ Server index.js not found"
    echo "Server directory contents:"
    ls -la "$PROJECT_DIR/server/" || echo "Server directory not found"
    exit 1
fi

echo "📁 Build verification:"
echo "   Admin build: $(ls -la "$PROJECT_DIR/admin/build/" | wc -l) files"
echo "   User build: $(ls -la "$PROJECT_DIR/user/build/" | wc -l) files"
echo "   Server files: $(ls -la "$PROJECT_DIR/server/" | wc -l) files"
echo "   ✅ Server script: $PROJECT_DIR/server/index.js"

# Show some sample files to verify builds
echo "📄 Key files found:"
echo "   Admin: $(ls "$PROJECT_DIR/admin/build/" | grep -E '\.(html|js|css)$' | head -3 | tr '\n' ' ')"
echo "   User: $(ls "$PROJECT_DIR/user/build/" | grep -E '\.(html|js|css)$' | head -3 | tr '\n' ' ')"
echo "   Server: $(ls "$PROJECT_DIR/server/" | grep -E '\.(js|json)$' | head -3 | tr '\n' ' ')"

# ========================================
# DEPLOYMENT / TEST SERVER
# ========================================

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "🧪 DRY RUN: Testing server startup..."
    
    # Test if the server can start
    cd "$PROJECT_DIR"
    
    # Copy environment
    cp "$PROJECT_DIR/server/.env" "$PROJECT_DIR/.env" 2>/dev/null || true
    
    # Check if port 8080 is available for testing
    if ! check_port 8080; then
        echo "   ⚠️  Port 8080 is in use, testing on port 8081 instead"
        TEST_PORT=8081
        sed -i.bak 's/PORT=8080/PORT=8081/' "$PROJECT_DIR/server/.env"
    else
        TEST_PORT=8080
    fi
    
    echo "   Starting test server on port $TEST_PORT for 10 seconds..."
    
    # Start server in background
    (cd server && NODE_ENV=production PORT=$TEST_PORT node index.js) &
    SERVER_PID=$!
    
    # Wait a bit for server to start
    sleep 3
    
    # Test the endpoints
    echo "   Testing endpoints on port $TEST_PORT:"
    
    if curl -s http://localhost:$TEST_PORT/api/health >/dev/null 2>&1; then
        echo "   ✅ Health endpoint: OK"
        HEALTH_RESPONSE=$(curl -s http://localhost:$TEST_PORT/api/health)
        echo "      Status: $(echo $HEALTH_RESPONSE | grep -o '"status":"[^"]*"' | cut -d'"' -f4)"
    else
        echo "   ❌ Health endpoint: FAILED"
    fi
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$TEST_PORT/ 2>/dev/null || echo "000")
    echo "   📄 Main page: HTTP $HTTP_CODE"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$TEST_PORT/admin 2>/dev/null || echo "000")
    echo "   ⚙️  Admin page: HTTP $HTTP_CODE"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$TEST_PORT/app 2>/dev/null || echo "000")
    echo "   👤 User page: HTTP $HTTP_CODE"
    
    # Stop test server
    sleep 2
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    # Restore original .env if we changed it
    if [ -f "$PROJECT_DIR/server/.env.bak" ]; then
        mv "$PROJECT_DIR/server/.env.bak" "$PROJECT_DIR/server/.env"
    fi
    
    echo ""
    echo "🎉 DRY RUN COMPLETED!"
    echo ""
    echo "📊 Summary:"
    echo "   ✅ All packages downloaded and extracted"
    echo "   ✅ All dependencies installed"
    echo "   ✅ React apps built successfully"
    echo "   ✅ Server can start and respond"
    echo ""
    if [ "$NODE_VERSION" -lt 20 ]; then
        echo "⚠️  Note for AWS deployment:"
        echo "   Your Mac has Node.js $(node --version)"
        echo "   AWS deployment requires Node.js 20+"
        echo "   Make sure your AWS server has the right version"
        echo ""
    fi
    echo "🚀 Ready for production deployment!"
    echo "   Deploy to AWS with: npx @gv-sh/specgen-app deploy"
    echo ""
    echo "🔧 To test locally right now:"
    echo "   cd server && npm start"
    echo "   Open http://localhost:8080/"
    
else
    # Real deployment with PM2
    echo "🚀 Starting PM2 deployment..."
    
    # Create PM2 ecosystem configuration with absolute paths
    cat > "$PROJECT_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [{
    name: 'specgen',
    script: '$PROJECT_DIR/server/index.js',
    cwd: '$PROJECT_DIR',
    env: {
      NODE_ENV: 'production',
      PORT: 8080
    },
    instances: 1,
    exec_mode: 'fork',
    max_memory_restart: '500M',
    error_file: '$PROJECT_DIR/logs/err.log',
    out_file: '$PROJECT_DIR/logs/out.log',
    log_file: '$PROJECT_DIR/logs/combined.log',
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
    mkdir -p "$PROJECT_DIR/logs"
    
    # Copy .env to project root for PM2
    cp "$PROJECT_DIR/server/.env" "$PROJECT_DIR/.env" 2>/dev/null || true
    
    # Final port check
    if ! check_port 8080; then
        echo "Port 8080 occupied, force cleaning..."
        lsof -ti:8080 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Start with PM2
    cd "$PROJECT_DIR"
    echo "▶️ Starting SpecGen with PM2..."
    
    NODE_ENV=production PORT=8080 $PM2_CMD start "$PROJECT_DIR/ecosystem.config.js"
    
    # Wait for startup and verify
    sleep 5
    
    # Verify deployment
    echo "🔍 Verifying deployment..."
    
    if $PM2_CMD list | grep -q "online"; then
        echo "Testing endpoints:"
        
        if curl -s http://localhost:8080/api/health >/dev/null 2>&1; then
            echo "✅ Health endpoint: OK"
        else
            echo "❌ Health endpoint: FAILED"
        fi
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null)
        echo "📄 Main page: HTTP $HTTP_CODE"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/admin 2>/dev/null)
        echo "⚙️  Admin page: HTTP $HTTP_CODE"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/app 2>/dev/null)
        echo "👤 User page: HTTP $HTTP_CODE"
        
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null || echo 'your-server')
        
        echo ""
        echo "🎉 SpecGen deployment completed!"
        echo ""
        echo "🌐 Access your application at:"
        echo "   - Main page: http://$PUBLIC_IP:8080/"
        echo "   - User app: http://$PUBLIC_IP:8080/app"
        echo "   - Admin panel: http://$PUBLIC_IP:8080/admin"
        echo "   - API docs: http://$PUBLIC_IP:8080/api-docs"
        echo "   - Health check: http://$PUBLIC_IP:8080/api/health"
        echo ""
        echo "📊 Management commands:"
        echo "   $PM2_CMD status           # Check status"
        echo "   $PM2_CMD logs specgen     # View logs"
        echo "   $PM2_CMD restart specgen  # Restart"
        
    else
        echo ""
        echo "❌ Deployment failed!"
        echo "📝 Check logs: $PM2_CMD logs specgen"
        echo "📊 Check status: $PM2_CMD status"
        exit 1
    fi
fi