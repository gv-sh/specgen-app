#!/bin/bash

# SpecGen Production Script
set -e

echo "🚀 Starting SpecGen in production mode..."

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port in use
    else
        return 0  # Port available
    fi
}

# Verify OpenAI API key
if [ -f "server/.env" ]; then
    if grep -q "OPENAI_API_KEY=your_openai_api_key_here" server/.env; then
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

# Check if dependencies are installed
for dir in server admin user; do
    if [ ! -d "$dir/node_modules" ]; then
        echo "Installing $dir dependencies..."
        cd "$dir" && npm install
        cd ..
    fi
done

# Set production environment
export NODE_ENV=production

echo "Building web interfaces..."
# Build React apps for production
cd admin && npm run build && cd ..
cd user && npm run build && cd ..

# Create production-ready .env for server
cat > server/.env.production << EOF
$(cat server/.env)
NODE_ENV=production
EOF

# Kill existing processes on required ports if needed
echo "Checking ports..."
for port in 3000 3001 3002; do
    if ! check_port $port; then
        echo "Port $port is in use. Attempting to free it..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
done

# Start production server
echo "Starting production server..."
cd server && NODE_ENV=production npm start