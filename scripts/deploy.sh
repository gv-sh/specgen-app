#!/bin/bash

# SpecGen Deploy Script - Simple PM2 Deployment on Port 8080 with Full Cleanup
set -e

echo "🚀 Deploying SpecGen to production on port 8080..."
echo "🧹 Performing full cleanup before deployment..."

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port in use
    else
        return 0  # Port available
    fi
}

# ========================================
# FULL CLEANUP
# ========================================

# Stop and remove all PM2 processes
echo "Stopping all PM2 processes..."
npx pm2 stop all 2>/dev/null || true
npx pm2 delete all 2>/dev/null || true
npx pm2 kill 2>/dev/null || true

# Remove old PM2 config files
rm -f ecosystem.config.js 2>/dev/null || true
rm -f pm2.config.js 2>/dev/null || true

# Kill processes on all relevant ports
echo "Freeing all ports..."
for port in 8080 3000 3001 3002; do
    if ! check_port $port; then
        echo "Killing processes on port $port..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
done

# Clean up logs
rm -rf logs/* 2>/dev/null || true

# Check for nginx conflicts
if command -v nginx &> /dev/null && systemctl is-active --quiet nginx 2>/dev/null; then
    if nginx -T 2>/dev/null | grep -q ":8080"; then
        echo "⚠️ WARNING: Nginx is configured to use port 8080"
        echo "   You may need to stop nginx or reconfigure it"
        echo "   Run: sudo systemctl stop nginx"
    fi
fi

# ========================================
# RUN PRODUCTION SETUP
# ========================================

echo "Running production setup..."
npm run production &
SETUP_PID=$!

# Wait for setup to complete or timeout
TIMEOUT=90
COUNT=0
while [ $COUNT -lt $TIMEOUT ]; do
    if ! kill -0 $SETUP_PID 2>/dev/null; then
        echo "Production setup completed"
        break
    fi
    sleep 1
    COUNT=$((COUNT + 1))
    
    # Show progress every 15 seconds
    if [ $((COUNT % 15)) -eq 0 ]; then
        echo "Setup still running... ($COUNT/$TIMEOUT seconds)"
    fi
done

# Kill setup process if it's still running
if kill -0 $SETUP_PID 2>/dev/null; then
    echo "Setup taking too long, terminating and continuing with PM2 deployment..."
    kill $SETUP_PID 2>/dev/null || true
    # Force kill any remaining processes
    for port in 8080 3000; do
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
    done
fi

# Wait a moment for cleanup
sleep 3

# ========================================
# PM2 DEPLOYMENT
# ========================================

# Create PM2 ecosystem configuration
echo "Creating PM2 ecosystem configuration..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'specgen',
    script: './server/index.js',
    cwd: process.cwd(),
    env: {
      NODE_ENV: 'production',
      PORT: 8080
    },
    instances: 1,
    exec_mode: 'fork',
    max_memory_restart: '500M',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    watch: false,
    ignore_watch: ['node_modules', 'logs', '*.log'],
    restart_delay: 1000,
    max_restarts: 3,
    min_uptime: '10s'
  }]
}
EOF

# Create logs directory
mkdir -p logs

# Final port check
echo "Final port check..."
if ! check_port 8080; then
    echo "Port 8080 still occupied, force cleaning..."
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Start with PM2
echo "Starting SpecGen with PM2 on port 8080..."
NODE_ENV=production PORT=8080 npx pm2 start ecosystem.config.js

# Wait for startup and verify
sleep 5

# Check if the process is actually running
if npx pm2 list | grep -q "online"; then
    echo ""
    echo "✅ SpecGen deployment completed successfully!"
    
    # Get public IP
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null || echo 'your-server')
    
    echo ""
    echo "🌐 Access your application at:"
    echo "   - Main page: http://$PUBLIC_IP:8080/"
    echo "   - User app: http://$PUBLIC_IP:8080/app"
    echo "   - Admin panel: http://$PUBLIC_IP:8080/admin"
    echo "   - API docs: http://$PUBLIC_IP:8080/api-docs"
    echo "   - Health check: http://$PUBLIC_IP:8080/api/health"
    echo ""
    echo "📊 Management commands:"
    echo "   - Check status: npx pm2 status"
    echo "   - View logs: npx pm2 logs specgen"
    echo "   - Restart: npx pm2 restart specgen"
    echo "   - Stop: npx pm2 stop specgen"
    echo ""
    
    # Test the health endpoint
    echo "🔍 Testing health endpoint..."
    if curl -s http://localhost:8080/api/health >/dev/null 2>&1; then
        echo "✅ Health check passed!"
    else
        echo "⚠️ Health check failed - check logs with: npx pm2 logs specgen"
    fi
    
else
    echo ""
    echo "❌ Deployment failed!"
    echo "📝 Check logs with: npx pm2 logs specgen"
    echo "📊 Check status with: npx pm2 status"
    exit 1
fi