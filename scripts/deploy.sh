#!/bin/bash
set -e

echo "🚀 Deploying SpecGen..."

# Build React apps with production configuration
echo "📦 Building applications..."

# Build admin with correct public URL
echo "Building admin interface..."
cd admin && PUBLIC_URL=/admin npm run build && cd ..

# Build user with production API URL  
echo "Building user interface..."
cd user && npm run build && cd ..

# Create logs directory
mkdir -p logs

# Set environment for production
echo "🔧 Configuring environment..."
cat > server/.env << 'EOF'
NODE_ENV=production
PORT=80
HOST=0.0.0.0
EOF

# Add OpenAI key if not set
if ! grep -q "OPENAI_API_KEY" server/.env 2>/dev/null; then
    echo "Enter OpenAI API key (or press Enter for test key):"
    read -r OPENAI_KEY
    if [ -z "$OPENAI_KEY" ]; then
        OPENAI_KEY="sk-test1234"
    fi
    echo "OPENAI_API_KEY=$OPENAI_KEY" >> server/.env
fi

# Deploy with PM2 using ecosystem config
echo "🚀 Starting with PM2..."
npx pm2 stop specgen 2>/dev/null || true
npx pm2 delete specgen 2>/dev/null || true

# Start with ecosystem config
npx pm2 start ecosystem.config.js

echo "✅ Deployed! Check with: npx pm2 status"
echo "🌐 Access at: http://localhost/ (admin: /admin)"