#!/bin/bash

# Local development setup script
set -e

echo "Setting up SpecGen App for local development..."

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS environment"
    # Ensure we have necessary tools
    if ! command -v npm &> /dev/null; then
        echo "npm not found. Please install Node.js from https://nodejs.org/"
        exit 1
    fi
fi

# Download and extract npm packages
echo "Downloading packages..."
npm run download-packages

echo "Extracting packages..."
npm run extract-packages

# Patch package.json files to fix scripts
echo "Patching package scripts..."
chmod +x scripts/patch-packages.sh
./scripts/patch-packages.sh

# Copy config files from local source repositories
echo "Copying config files from local source repos..."
chmod +x scripts/copy-configs.sh
./scripts/copy-configs.sh

# Install dependencies
echo "Installing dependencies..."
npm run install-all

# Setup environment files
echo "Setting up environment files..."

# Server .env
if [ ! -f server/.env ]; then
    cat > server/.env << 'EOF'
# Copy this file to .env and fill in your values
OPENAI_API_KEY=your_openai_api_key_here
NODE_ENV=development
PORT=3000
EOF
    echo "Created server/.env - Please add your OpenAI API key"
fi

# Admin .env.development
cat > admin/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:3000
PORT=3001
PUBLIC_URL=
GENERATE_SOURCEMAP=true
EOF

# User .env.development
cat > user/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:3000
PORT=3002
PUBLIC_URL=
GENERATE_SOURCEMAP=true
EOF

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Add your OpenAI API key to server/.env"
echo "2. Run 'npm run dev' (or 'npm run dev:mac' on Mac) to start all services"
echo ""
echo "If you have issues, run: npm run troubleshoot"
