#!/bin/bash

# Mac development server starter with CSS fix
set -e

echo "🚀 Starting SpecGen development servers with CSS support..."

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port in use
    else
        return 0  # Port available
    fi
}

# Kill existing processes on required ports if needed
echo "Checking ports..."
for port in 3000 3001 3002; do
    if ! check_port $port; then
        echo "Port $port is in use. Attempting to free it..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
done

# Ensure all dependencies are installed
if [ ! -d "server/node_modules" ] || [ ! -d "admin/node_modules" ] || [ ! -d "user/node_modules" ]; then
    echo "Installing missing dependencies..."
    npm run install-all
fi

# Set development environment for CSS support
export NODE_ENV=development
export SKIP_PREFLIGHT_CHECK=true
export GENERATE_SOURCEMAP=true
export FAST_REFRESH=true

# Ensure CSS files are imported
echo "Checking CSS imports..."
npm run diagnose-css

# Start development servers with proper environment
echo "Starting servers with CSS support..."
npx concurrently \
    --prefix "[{name}]" \
    --names "server,admin,user" \
    --prefix-colors "cyan,magenta,yellow" \
    "cd server && NODE_ENV=development npm run dev" \
    "cd admin && SKIP_PREFLIGHT_CHECK=true FAST_REFRESH=true GENERATE_SOURCEMAP=true PORT=3001 npm start" \
    "cd user && SKIP_PREFLIGHT_CHECK=true FAST_REFRESH=true GENERATE_SOURCEMAP=true PORT=3002 npm start"
