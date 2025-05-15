#!/bin/bash

# Mac development troubleshooting script
echo "🔍 SpecGen Mac Troubleshooting"
echo "================================"

# Check Node.js and npm
echo "📦 Node.js/npm versions:"
node -v
npm -v
echo ""

# Check if packages are extracted
echo "📁 Component directories:"
for dir in server admin user; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir exists"
    else
        echo "  ❌ $dir missing - run npm run setup:mac"
    fi
done
echo ""

# Check environment files
echo "🔧 Environment files:"
if [ -f "server/.env" ]; then
    if grep -q "your_openai_api_key_here" server/.env; then
        echo "  ⚠️  server/.env needs OpenAI API key"
    else
        echo "  ✓ server/.env configured"
    fi
else
    echo "  ❌ server/.env missing"
fi

for dir in admin user; do
    if [ -f "$dir/.env.development" ]; then
        echo "  ✓ $dir/.env.development exists"
    else
        echo "  ❌ $dir/.env.development missing"
    fi
done
echo ""

# Check port availability
echo "🌐 Port status:"
for port in 3000 3001 3002; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ❌ Port $port in use"
    else
        echo "  ✓ Port $port available"
    fi
done
echo ""

# Check node_modules
echo "📚 Dependencies:"
for dir in . server admin user; do
    if [ -d "$dir/node_modules" ]; then
        echo "  ✓ $dir/node_modules exists"
    else
        echo "  ❌ $dir/node_modules missing - run npm install"
    fi
done
