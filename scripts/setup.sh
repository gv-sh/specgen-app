#!/bin/bash

# SpecGen App Setup Script
set -e

echo "🚀 Setting up SpecGen App..."

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

# Clean existing directories with proper permission handling
echo "Cleaning existing directories..."
safe_remove "server"
safe_remove "admin" 
safe_remove "user"
rm -f *.tgz package 2>/dev/null || true

# Install dependencies to get latest versions
echo "📦 Installing dependencies..."
npm install

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

# Patch package.json files to fix React scripts
echo "🔧 Patching package scripts..."

# Fix user package start script
if [ -f "user/package.json" ]; then
    echo "Fixing user package start script..."
    # Replace the start script to use react-scripts instead of missing scripts/start.js
    sed -i.bak 's|"start": "cross-env PORT=3002 REACT_APP_API_URL=http://localhost:3000 node scripts/start.js"|"start": "cross-env PORT=3002 REACT_APP_API_URL=http://localhost:3000 react-scripts start"|g' user/package.json
    rm -f user/package.json.bak
fi

# Fix admin package start script if needed
if [ -f "admin/package.json" ]; then
    echo "Checking admin package start script..."
    # Check if admin has similar issue
    if grep -q "node scripts/start.js" admin/package.json; then
        echo "Fixing admin package start script..."
        sed -i.bak 's|node scripts/start.js|react-scripts start|g' admin/package.json
        rm -f admin/package.json.bak
    fi
fi

# Install dependencies for each component
echo "📚 Installing dependencies..."
for dir in server admin user; do
    if [ -d "$dir" ]; then
        echo "Installing $dir dependencies..."
        cd "$dir" && npm install
        cd ..
    else
        echo "⚠️  Warning: $dir directory not found"
    fi
done

# Setup environment files
echo "🔧 Setting up environment files..."

# Server .env
if [ ! -f server/.env ]; then
    cat > server/.env << 'EOF'
# Add your OpenAI API key here
OPENAI_API_KEY=your_openai_api_key_here
NODE_ENV=development
PORT=3000
EOF
    echo "Created server/.env - Please add your OpenAI API key"
fi

# Admin .env.development  
if [ -d admin ]; then
    cat > admin/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:3000
PORT=3001
SKIP_PREFLIGHT_CHECK=true
GENERATE_SOURCEMAP=true
EOF
fi

# User .env.development
if [ -d user ]; then
    cat > user/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:3000  
PORT=3002
SKIP_PREFLIGHT_CHECK=true
GENERATE_SOURCEMAP=true
EOF
fi

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Add your OpenAI API key to server/.env"
echo "2. Run 'npm run dev' to start all services"
echo ""
echo "Access URLs:"
echo "  🌐 User Interface: http://localhost:3002"
echo "  ⚙️  Admin Interface: http://localhost:3001"  
echo "  🔧 API: http://localhost:3000"