#!/bin/bash

# SpecGen Troubleshooting Script  
echo "🔍 SpecGen Troubleshooting"
echo "========================="

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
        if [ -f "$dir/package.json" ]; then
            version=$(cat "$dir/package.json" | grep '"version"' | sed 's/.*"version": "\([^"]*\)".*/\1/')
            echo "    Version: $version"
        fi
    else
        echo "  ❌ $dir missing - run npm run setup"
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
        process=$(lsof -Pi :$port -sTCP:LISTEN -t | xargs ps -o comm= -p)
        echo "  ❌ Port $port in use by: $process"
    else
        echo "  ✓ Port $port available"
    fi
done
echo ""

# Check dependencies
echo "📚 Dependencies:"
for dir in server admin user; do
    if [ -d "$dir/node_modules" ]; then
        echo "  ✓ $dir/node_modules exists"
    else
        echo "  ❌ $dir/node_modules missing - run: cd $dir && npm install"
    fi
done
echo ""

# Check for common CSS/styling issues
echo "🎨 CSS and Build files:"
for dir in admin user; do
    if [ -d "$dir" ]; then
        echo "  $dir:"
        if [ -f "$dir/src/index.css" ]; then
            echo "    ✓ index.css exists"
        else
            echo "    ❌ index.css missing"
        fi
        if [ -f "$dir/tailwind.config.js" ]; then
            echo "    ✓ tailwind.config.js exists"
        else
            echo "    ⚠️  tailwind.config.js missing (may be normal)"
        fi
    fi
done