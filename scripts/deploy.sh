#!/bin/bash
set -e

echo "🚀 Deploying SpecGen..."

# Build React apps
echo "📦 Building applications..."
cd admin && npm run build && cd ..
cd user && npm run build && cd ..

# Set environment for production
echo "NODE_ENV=production" > server/.env
echo "PORT=80" >> server/.env
echo "HOST=0.0.0.0" >> server/.env

# Add OpenAI key if not set
if ! grep -q "OPENAI_API_KEY" server/.env 2>/dev/null; then
    echo "Enter OpenAI API key (or press Enter for test key):"
    read -r OPENAI_KEY
    if [ -z "$OPENAI_KEY" ]; then
        OPENAI_KEY="sk-test1234"
    fi
    echo "OPENAI_API_KEY=$OPENAI_KEY" >> server/.env
fi

# Deploy with PM2
echo "🚀 Starting with PM2..."
npx pm2 stop specgen 2>/dev/null || true
npx pm2 delete specgen 2>/dev/null || true

# Start server
cd server && npx pm2 start index.js --name specgen --env production

echo "✅ Deployed! Check with: npx pm2 status"