#!/bin/bash

# SpecGen EC2 Remote Deployment Script
# Run from your Mac to deploy to EC2

set -e

# Configuration
EC2_HOST="ubuntu@ec2-52-66-251-12.ap-south-1.compute.amazonaws.com"
EC2_KEY="debanshu.pem"
REPO_URL="https://github.com/gv-sh/specgen-app.git"
APP_DIR="/home/ubuntu/specgen-app"

echo "🚀 SpecGen EC2 Remote Deployment Starting..."
echo "📡 Target: $EC2_HOST"

# Check if key file exists
if [ ! -f "$EC2_KEY" ]; then
    echo "❌ SSH key file '$EC2_KEY' not found!"
    echo "Please ensure the key file is in the current directory."
    exit 1
fi

# Function to run commands on EC2
run_on_ec2() {
    ssh -i "$EC2_KEY" "$EC2_HOST" "$1"
}

echo "🧹 Stopping existing services..."
run_on_ec2 "
    cd '$APP_DIR/server' 2>/dev/null || true
    npx pm2 stop specgen 2>/dev/null || true
    npx pm2 delete specgen 2>/dev/null || true
"

echo "📥 Updating repository..."
run_on_ec2 "
    if [ -d '$APP_DIR' ]; then
        cd '$APP_DIR' && git stash && git pull origin main
    else
        git clone '$REPO_URL' '$APP_DIR'
    fi
"

echo "📦 Setting up dependencies..."
run_on_ec2 "
    cd '$APP_DIR'
    npm run setup
    
    # Install cross-env globally for build process
    npm install -g cross-env
"

echo "🏗️ Building applications..."
run_on_ec2 "
    cd '$APP_DIR'
    
    # Build admin interface with correct public URL
    echo 'Building admin interface...'
    cd admin && PUBLIC_URL=/admin npm run build && cd ..
    
    # Build user interface with production API URL  
    echo 'Building user interface...'
    cd user && cross-env REACT_APP_API_URL=/api npm run build && cd ..
    
    echo '✅ Builds completed'
"

echo "🔧 Configuring environment..."

# Get OpenAI API key from local environment
OPENAI_KEY=""
if [ -f "../specgen-server/.env" ]; then
    OPENAI_KEY=$(grep "OPENAI_API_KEY=" ../specgen-server/.env | cut -d'=' -f2- | tr -d '"'"'"'')
    echo "✅ Found OpenAI API key in local specgen-server/.env"
elif [ -f "server/.env" ]; then
    OPENAI_KEY=$(grep "OPENAI_API_KEY=" server/.env | cut -d'=' -f2- | tr -d '"'"'"'')
    echo "✅ Found OpenAI API key in local server/.env"
else
    echo "⚠️  No OpenAI API key found locally, will use test key"
    OPENAI_KEY="sk-test1234"
fi

run_on_ec2 "
    cd '$APP_DIR'
    
    # Create logs directory
    mkdir -p logs
    
    # Configure server environment
    cat > server/.env << 'EOF'
NODE_ENV=production
PORT=80
HOST=0.0.0.0
EOF
    
    # Add OpenAI key securely
    echo 'OPENAI_API_KEY=$OPENAI_KEY' >> server/.env
    
    echo 'Environment configured with OpenAI API key'
"

echo "🚀 Starting application..."
run_on_ec2 "
    cd '$APP_DIR/server'
    
    # Check if ecosystem.config.js exists in deploy directory, if not use index.js
    if [ -f deploy/ecosystem.config.js ]; then
        npx pm2 start deploy/ecosystem.config.js
    else
        npx pm2 start index.js --name specgen
    fi
"

echo "⏳ Waiting for startup..."
sleep 5

echo "🧪 Testing deployment..."
HEALTH_CHECK=$(run_on_ec2 "curl -s http://localhost:80/api/health | jq -r '.status' 2>/dev/null || echo 'failed'")

if [ "$HEALTH_CHECK" = "healthy" ]; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🌐 Access your application:"
    echo "  User Interface: http://52.66.251.12/"
    echo "  Admin Panel: http://52.66.251.12/admin"
    echo "  API Documentation: http://52.66.251.12/api-docs"
    echo "  Health Check: http://52.66.251.12/api/health"
    echo ""
    echo "📊 Server status:"
    run_on_ec2 "cd '$APP_DIR/server' && npx pm2 status"
else
    echo "❌ Deployment failed - health check returned: $HEALTH_CHECK"
    echo "📋 Checking logs..."
    run_on_ec2 "cd '$APP_DIR/server' && npx pm2 logs specgen --lines 10"
    exit 1
fi

echo "🎉 SpecGen deployment completed successfully!"