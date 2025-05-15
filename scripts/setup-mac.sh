#!/bin/bash

# Mac-specific setup and run script
set -e

echo "🍎 SpecGen Development Setup for macOS"

# Check Node.js version
node_version=$(node -v 2>/dev/null || echo "none")
if [[ $node_version == "none" ]]; then
    echo "❌ Node.js not found. Please install from https://nodejs.org/"
    exit 1
fi

echo "✓ Node.js version: $node_version"

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh

# Run main setup
echo "🚀 Running setup..."
./scripts/setup.sh

# Check if OpenAI key is set
if [[ -f server/.env ]]; then
    if grep -q "your_openai_api_key_here" server/.env; then
        echo "⚠️  Don't forget to add your OpenAI API key to server/.env"
    fi
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start development:"
echo "  npm run dev"
echo ""
echo "Access URLs:"
echo "  🌐 User Interface: http://localhost:3002"
echo "  ⚙️  Admin Interface: http://localhost:3001"
echo "  🔧 API: http://localhost:3000"
