#!/bin/bash

# Development server for source repositories
set -e

echo "🚀 Starting SpecGen development from source..."

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

# Verify source directories exist
for dir in server admin user; do
    if [ ! -d "$dir" ]; then
        echo "❌ $dir directory not found. Run 'npm run setup:source' first."
        exit 1
    fi
done

# Ensure all dependencies are installed
echo "Checking dependencies..."
if [ ! -d "server/node_modules" ] || [ ! -d "admin/node_modules" ] || [ ! -d "user/node_modules" ]; then
    echo "Installing missing dependencies..."
    cd server && npm install
    cd ../admin && npm install
    cd ../user && npm install
    cd ..
fi

# Set development environment
export NODE_ENV=development

# Start development servers
echo "Starting development servers from source..."
npx concurrently \
    --prefix "[{name}]" \
    --names "server,admin,user" \
    --prefix-colors "cyan,magenta,yellow" \
    "cd server && npm run dev" \
    "cd admin && npm start" \
    "cd user && npm start"
