#!/bin/bash

# Setup using source repositories instead of npm packages
set -e

echo "🔄 Setting up from source repositories..."

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS environment"
    if ! command -v git &> /dev/null; then
        echo "Git not found. Please install Git."
        exit 1
    fi
fi

# Clean existing directories
echo "Cleaning existing directories..."
chmod -R u+w server admin user 2>/dev/null || true
rm -rf server admin user

# Clone source repositories
echo "Cloning source repositories..."
git clone https://github.com/gv-sh/specgen-server.git server
git clone https://github.com/gv-sh/specgen-admin.git admin
git clone https://github.com/gv-sh/specgen-user.git user

# Install dependencies for each component
echo "Installing dependencies..."
cd server && npm install
cd ../admin && npm install
cd ../user && npm install
cd ..

# Setup environment files
echo "Setting up environment files..."

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
cat > admin/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:3000
PORT=3001
EOF

# User .env.development
cat > user/.env.development << 'EOF'
REACT_APP_API_URL=http://localhost:3000
PORT=3002
EOF

echo "✅ Source setup complete!"
echo ""
echo "Next steps:"
echo "1. Add your OpenAI API key to server/.env"
echo "2. Run 'npm run dev:source' to start all services"
