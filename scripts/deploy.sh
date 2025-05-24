#!/bin/bash

# SpecGen Deploy Script - Self-Contained Deployment on Port 80
set -e

# Check for dry-run mode
DRY_RUN=false
if [ "$1" = "--dry-run" ] || [ "$1" = "-d" ]; then
    DRY_RUN=true
    echo "🧪 DRY RUN MODE - Testing deployment locally"
    echo "🖥️  Platform: $(uname -s) $(uname -m)"
else
    echo "🚀 Deploying SpecGen to production on port 80..."
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
PROJECT_DIR=$(pwd)
echo "📂 Project directory: $PROJECT_DIR"

# ========================================
# PLATFORM-SPECIFIC SETUP
# ========================================

# Detect platform
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Darwin" ]; then
    echo "🍎 Detected macOS"
    PM2_CMD="npx pm2"
    DEFAULT_BIND_HOST="127.0.0.1"  # macOS - default to localhost
elif [ "$PLATFORM" = "Linux" ]; then
    echo "🐧 Detected Linux"
    PM2_CMD="npx pm2"
    DEFAULT_BIND_HOST="0.0.0.0"    # Linux - default to public access
else
    echo "⚠️  Unknown platform: $PLATFORM"
    PM2_CMD="npx pm2"
    DEFAULT_BIND_HOST="0.0.0.0"
fi

# Let user choose host binding unless in dry-run mode
if [ "$DRY_RUN" = true ]; then
    BIND_HOST="$DEFAULT_BIND_HOST"
    echo "🧪 DRY RUN: Using default host binding ($BIND_HOST)"
else
    echo ""
    echo "🌐 Choose server binding option:"
    echo "   1) 0.0.0.0 - Public access (accessible from any IP)"
    echo "   2) 127.0.0.1 - Local only (localhost access only)"
    echo "   3) Custom IP address"
    echo ""
    echo "Default for $PLATFORM: $DEFAULT_BIND_HOST"
    echo -n "Enter choice (1-3) or press Enter for default: "
    read -r HOST_CHOICE
    
    case "$HOST_CHOICE" in
        1)
            BIND_HOST="0.0.0.0"
            echo "✅ Selected: Public access (0.0.0.0)"
            ;;
        2)
            BIND_HOST="127.0.0.1"
            echo "✅ Selected: Local only (127.0.0.1)"
            ;;
        3)
            echo -n "Enter custom IP address: "
            read -r CUSTOM_HOST
            if [ -n "$CUSTOM_HOST" ]; then
                BIND_HOST="$CUSTOM_HOST"
                echo "✅ Selected: Custom host ($BIND_HOST)"
            else
                BIND_HOST="$DEFAULT_BIND_HOST"
                echo "✅ Using default: $BIND_HOST"
            fi
            ;;
        "")
            BIND_HOST="$DEFAULT_BIND_HOST"
            echo "✅ Using default: $BIND_HOST"
            ;;
        *)
            echo "⚠️  Invalid choice, using default: $DEFAULT_BIND_HOST"
            BIND_HOST="$DEFAULT_BIND_HOST"
            ;;
    esac
fi

echo "🌐 Server will bind to: $BIND_HOST"

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
    for port in 80 3000 3001 3002; do
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
fi

# ========================================
# VERIFY PREREQUISITES
# ========================================

echo "🔍 Checking prerequisites..."

# Check Node.js version
NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$DRY_RUN" = true ]; then
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo "❌ Node.js 18+ required for testing. Current version: $(node --version)"
        exit 1
    else
        echo "✅ Node.js version: $(node --version)"
    fi
else
    if [ "$NODE_VERSION" -lt 20 ]; then
        echo "❌ Node.js 20+ required for production. Current version: $(node --version)"
        exit 1
    else
        echo "✅ Node.js version: $(node --version)"
    fi
fi

echo "✅ npm version: $(npm --version)"

# ========================================
# SETUP OPENAI API KEY
# ========================================

echo "🔑 Setting up OpenAI API key..."

if [ "$DRY_RUN" = true ]; then
    echo "🧪 DRY RUN: Using test API key"
    mkdir -p "$PROJECT_DIR/server"
    echo "OPENAI_API_KEY=sk-test1234567890abcdef" > "$PROJECT_DIR/server/.env"
    echo "NODE_ENV=production" >> "$PROJECT_DIR/server/.env"
    echo "PORT=80" >> "$PROJECT_DIR/server/.env"
    echo "HOST=$BIND_HOST" >> "$PROJECT_DIR/server/.env"
elif [ ! -f "$PROJECT_DIR/server/.env" ] || grep -q "your_openai_api_key_here" "$PROJECT_DIR/server/.env" 2>/dev/null; then
    if [ "$CI" = "true" ]; then
        echo "CI mode - using test API key"
        mkdir -p "$PROJECT_DIR/server"
        echo "OPENAI_API_KEY=sk-test1234" > "$PROJECT_DIR/server/.env"
        echo "NODE_ENV=production" >> "$PROJECT_DIR/server/.env"
        echo "PORT=80" >> "$PROJECT_DIR/server/.env"
        echo "HOST=$BIND_HOST" >> "$PROJECT_DIR/server/.env"
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
        echo "PORT=80" >> "$PROJECT_DIR/server/.env"
        echo "HOST=$BIND_HOST" >> "$PROJECT_DIR/server/.env"
        echo "✅ API key saved"
    fi
fi

# ========================================
# BUILD APPLICATION
# ========================================

echo "🏗️ Building application components..."
cd "$PROJECT_DIR"

# Install and build server
if [ ! -f "server/index.js" ]; then
    echo "📦 Setting up server..."
    
    rm -rf server
    npm pack @gv-sh/specgen-server --loglevel=warn
    tar -xzf gv-sh-specgen-server-*.tgz
    
    if [ -d "package" ]; then
        mv package server
        rm gv-sh-specgen-server-*.tgz
        echo "✅ Server extracted successfully"
    else
        echo "❌ Failed to extract server package"
        exit 1
    fi
    
    cd server
    echo "engine-strict=false" > .npmrc
    npm install --no-fund --no-audit --production --maxsockets=2 --loglevel=warn
    cd "$PROJECT_DIR"
    
    # Install unified server that binds to 0.0.0.0
    echo "   🔧 Installing unified server (binds to all interfaces)..."
    cat > server/index.js << 'EOF'
// index.js - Unified server for port 80 with public binding
/* global process */
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const errorHandler = require('./middleware/errorHandler');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 80;
const HOST = process.env.HOST || '0.0.0.0';  // Bind to all interfaces by default

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files for admin interface at /admin
const adminBuildPath = path.join(__dirname, '../admin/build');
const fs = require('fs');
if (fs.existsSync(adminBuildPath)) {
  app.use('/admin', express.static(adminBuildPath));
  app.get('/admin/*', (req, res) => {
    res.sendFile(path.join(adminBuildPath, 'index.html'));
  });
  console.log('✅ Admin interface available at /admin');
} else {
  console.log('⚠️ Admin build not found');
}

// Serve static files for user interface at /app  
const userBuildPath = path.join(__dirname, '../user/build');
if (fs.existsSync(userBuildPath)) {
  app.use('/app', express.static(userBuildPath));
  app.get('/app/*', (req, res) => {
    res.sendFile(path.join(userBuildPath, 'index.html'));
  });
  console.log('✅ User interface available at /app');
} else {
  console.log('⚠️ User build not found');
}

// Serve user interface as default at root
if (fs.existsSync(userBuildPath)) {
  app.use('/', express.static(userBuildPath, { index: false }));
}

// API Routes
const categoryRoutes = require('./routes/categories');
const parameterRoutes = require('./routes/parameters');
const generateRoutes = require('./routes/generate');
const databaseRoutes = require('./routes/database');
const contentRoutes = require('./routes/content');
const settingsRoutes = require('./routes/settings');

app.use('/api/categories', categoryRoutes);
app.use('/api/parameters', parameterRoutes);
app.use('/api/generate', generateRoutes);
app.use('/api/database', databaseRoutes);
app.use('/api/content', contentRoutes);
app.use('/api/settings', settingsRoutes);

if (process.env.NODE_ENV !== 'test') {
  const swaggerRoutes = require('./routes/swagger');
  app.use('/api-docs', swaggerRoutes);
}

const healthRoutes = require('./routes/health');
app.use('/api/health', healthRoutes);

// Root route
app.get('/', (req, res) => {
  if (fs.existsSync(userBuildPath)) {
    res.sendFile(path.join(userBuildPath, 'index.html'));
  } else {
    const html = `
<!DOCTYPE html>
<html>
<head>
    <title>SpecGen - Running on ${HOST}:${PORT}</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f8f9fa; }
        .nav-card { border: 1px solid #dee2e6; border-radius: 8px; padding: 20px; margin: 15px 0; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .nav-card:hover { background-color: #f8f9fa; transform: translateY(-2px); transition: all 0.2s; }
        a { text-decoration: none; color: #007bff; }
        h1 { color: #343a40; text-align: center; }
        .status { color: #28a745; font-weight: bold; text-align: center; background: #d4edda; padding: 10px; border-radius: 5px; margin: 20px 0; }
        .binding { background: #e3f2fd; border: 1px solid #2196f3; padding: 15px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>🚀 SpecGen Platform</h1>
    <div class="status">✅ Server running on ${HOST}:${PORT}</div>
    
    <div class="binding">
        <strong>🌐 Network Binding:</strong> ${HOST === '0.0.0.0' ? 'Public access enabled (0.0.0.0)' : 'Local access only (' + HOST + ')'}
    </div>
    
    <div class="nav-card">
        <h3><a href="/app">📱 User Application</a></h3>
        <p>Main SpecGen user interface</p>
    </div>
    
    <div class="nav-card">
        <h3><a href="/admin">⚙️ Admin Panel</a></h3>
        <p>Administrative interface</p>
    </div>
    
    <div class="nav-card">
        <h3><a href="/api-docs">📚 API Documentation</a></h3>
        <p>Interactive API documentation</p>
    </div>
    
    <div class="nav-card">
        <h3><a href="/api/health">❤️ Health Check</a></h3>
        <p>System health monitoring</p>
    </div>
</body>
</html>`;
    res.send(html);
  }
});

app.use(errorHandler);

if (require.main === module) {
  app.listen(PORT, HOST, () => {
    console.log(`🚀 SpecGen server running on ${HOST}:${PORT}`);
    console.log(`📱 User App: http://${HOST}:${PORT}/app`);
    console.log(`⚙️ Admin Panel: http://${HOST}:${PORT}/admin`);
    console.log(`📚 API Docs: http://${HOST}:${PORT}/api-docs`);
    console.log(`❤️ Health Check: http://${HOST}:${PORT}/api/health`);
    
    if (HOST === '0.0.0.0') {
      console.log(`🌐 Accessible from any IP address`);
    } else {
      console.log(`🏠 Local access only (${HOST})`);
    }
  });
}

module.exports = app;
EOF
    echo "✅ Unified server installed with public binding"
fi

# Build admin and user (shortened for brevity)
for component in admin user; do
    if [ ! -d "$component/build" ]; then
        echo "📱 Building $component interface..."
        
        if [ ! -d "$component" ]; then
            npm pack @gv-sh/specgen-$component --loglevel=warn
            tar -xzf gv-sh-specgen-$component-*.tgz
            mv package $component
            rm gv-sh-specgen-$component-*.tgz
        fi
        
        cd $component
        echo "engine-strict=false" > .npmrc
        npm install --no-fund --no-audit --maxsockets=2 --loglevel=warn
        
        if [ "$component" = "admin" ]; then
            GENERATE_SOURCEMAP=false SKIP_PREFLIGHT_CHECK=true PUBLIC_URL=/admin npm run build
        else
            GENERATE_SOURCEMAP=false SKIP_PREFLIGHT_CHECK=true REACT_APP_API_URL=/api PUBLIC_URL=/app npm run build
        fi
        cd "$PROJECT_DIR"
    fi
done

# No need to install serve - using unified server only

# ====================== ==================
# VERIFY BUILDS
# ========================================

echo "✅ Verifying builds..."
if [ ! -d "admin/build" ] || [ ! -d "user/build" ] || [ ! -f "server/index.js" ]; then
    echo "❌ Build verification failed"
    exit 1
fi

echo "📁 All builds completed successfully"

# ========================================
# DEPLOYMENT
# ========================================

if [ "$DRY_RUN" = true ]; then
    echo "🧪 DRY RUN: Testing server startup..."
    cd "$PROJECT_DIR"
    cp server/.env .env 2>/dev/null || true
    
    TEST_PORT=80
    if ! check_port $TEST_PORT; then
        TEST_PORT=8081
    fi
    
    echo "   Starting test server on $BIND_HOST:$TEST_PORT for 10 seconds..."
    (cd server && NODE_ENV=production PORT=$TEST_PORT HOST=$BIND_HOST node index.js) &
    SERVER_PID=$!
    
    sleep 3
    
    echo "   Testing endpoints:"
    if curl -s http://localhost:$TEST_PORT/api/health >/dev/null 2>&1; then
        echo "   ✅ Health endpoint: OK"
    else
        echo "   ❌ Health endpoint: FAILED"
    fi
    
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
    
    echo ""
    echo "🎉 DRY RUN COMPLETED!"
    echo "🚀 Ready for production deployment!"
    
else
    echo "🚀 Starting PM2 deployment..."
    
    mkdir -p logs
    cp server/.env .env 2>/dev/null || true

    # Grant Node permission to bind to port 80 (Linux only)
    if [ "$PLATFORM" = "Linux" ]; then
        echo "🔐 Granting Node.js permission to bind to port 80..."
        sudo setcap 'cap_net_bind_service=+ep' "$(which node)" 2>/dev/null || {
            echo "⚠️  Could not set capabilities. You may need to run as root or use a port > 1024"
        }
    fi

    # Load environment variables from .env
    set -o allexport
    source .env
    set +o allexport
    
    cat > "$PROJECT_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [
    {
      name: 'specgen',
      script: '$PROJECT_DIR/server/index.js',
      cwd: '$PROJECT_DIR',
      env: {
        NODE_ENV: 'production',
        PORT: 80,
        HOST: '$BIND_HOST',
        OPENAI_API_KEY: process.env.OPENAI_API_KEY
      },
      instances: 1,
      exec_mode: 'fork',
      max_memory_restart: '500M',
      error_file: '$PROJECT_DIR/logs/err.log',
      out_file: '$PROJECT_DIR/logs/out.log',
      log_file: '$PROJECT_DIR/logs/combined.log',
      time: true,
      watch: false
    }
  ]
}
EOF
    
    mkdir -p logs
    cp server/.env .env 2>/dev/null || true
    
    if ! check_port 80; then
        lsof -ti:80 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    NODE_ENV=production PORT=80 HOST=$BIND_HOST $PM2_CMD start ecosystem.config.js
    
    echo "⏱️  Waiting for server to start..."
    sleep 8
    
    # Verify the server is actually responding
    echo "🔍 Verifying server health..."
    HEALTH_CHECK=false
    for i in {1..10}; do
        if curl -s http://localhost:80/api/health >/dev/null 2>&1; then
            HEALTH_CHECK=true
            break
        fi
        echo "   Attempt $i/10: Server not ready yet..."
        sleep 2
    done
    
    if $PM2_CMD list | grep -q "online" && [ "$HEALTH_CHECK" = true ]; then
        PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo 'your-server')
        
        echo ""
        echo "🎉 SpecGen deployment completed!"
        echo ""
        echo "🌐 Access your application at:"
        if [ "$BIND_HOST" = "0.0.0.0" ]; then
            echo "   - Main page: http://$PUBLIC_IP/"
            echo "   - User app: http://$PUBLIC_IP/app"
            echo "   - Admin panel: http://$PUBLIC_IP/admin"
            echo "   - API docs: http://$PUBLIC_IP/api-docs"
            echo "   - Health check: http://$PUBLIC_IP/api/health"
        else
            echo "   - Main page: http://localhost/"
            echo "   - User app: http://localhost/app"
            echo "   - Admin panel: http://localhost/admin"
            echo "   - API docs: http://localhost/api-docs"
            echo "   - Health check: http://localhost/api/health"
        fi
        echo ""
        echo "🔧 Binding: Server is bound to $BIND_HOST"
        echo "📊 Management: npx pm2 status | npx pm2 logs specgen"
        echo ""
        echo "✅ All services are running and responding!"
        
    else
        echo ""
        echo "❌ Deployment failed!"
        echo "🔍 Process status:"
        $PM2_CMD list
        echo ""
        echo "📝 Recent logs:"
        $PM2_CMD logs specgen --lines 20
        echo ""
        echo "🔧 Debug commands:"
        echo "   npx pm2 logs specgen"
        echo "   npx pm2 restart specgen"
        echo "   curl http://localhost:80/api/health"
        exit 1
    fi
fi