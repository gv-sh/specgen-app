#!/bin/bash

# SpecGen EC2 Remote Deployment Script
# Run from your Mac to deploy to EC2

set -e

# Configuration - can be overridden with environment variables
EC2_HOST="${EC2_HOST:-}"
EC2_KEY="${EC2_KEY:-~/.ssh/id_rsa}"
REPO_URL="${REPO_URL:-https://github.com/gv-sh/specgen-app.git}"
APP_DIR="${APP_DIR:-/home/ubuntu/specgen-app}"

# Prompt for EC2 host if not set
if [ -z "$EC2_HOST" ]; then
    echo "🔑 Enter your EC2 SSH connection string:"
    echo "   (e.g., ubuntu@ec2-xx-xx-xx-xx.region.compute.amazonaws.com)"
    read -p "EC2 Host: " EC2_HOST

    if [ -z "$EC2_HOST" ]; then
        echo "❌ EC2 host is required!"
        exit 1
    fi
fi

# Prompt for SSH key if the default doesn't exist
if [ ! -f "$EC2_KEY" ]; then
    echo "🔑 Enter the path to your SSH key file:"
    echo "   (default: ~/.ssh/id_rsa)"
    read -p "SSH Key Path: " INPUT_KEY

    if [ -n "$INPUT_KEY" ]; then
        EC2_KEY="$INPUT_KEY"
    fi

    if [ ! -f "$EC2_KEY" ]; then
        echo "❌ SSH key file '$EC2_KEY' not found!"
        exit 1
    fi
fi

# Prompt for public IP address
echo "📡 Enter the public IP address or domain for your EC2 instance:"
echo "   (e.g., 52.66.251.12 or your-domain.com)"
read -p "Public IP/Domain: " PUBLIC_IP

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Public IP/Domain is required for proper frontend configuration!"
    exit 1
fi

echo "✅ Using public address: $PUBLIC_IP"

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
"

echo "🏗️ Building applications..."
run_on_ec2 "
    cd '$APP_DIR'
    
    # Build admin interface with correct public URL (admin appends /api to base URL)
    echo 'Building admin interface...'
    cd admin && PUBLIC_URL=/admin REACT_APP_API_URL='https://futuresofhope.org' npm run build && cd ..
    
    # Build user interface with production API URL (user interface appends /api to base URL)
    echo 'Building user interface...'
    cd user
    # Install devDependencies including cross-env
    npm install --include=dev
    # Temporarily modify package.json to use correct base URL for production
    sed -i 's|\"build\": \"cross-env REACT_APP_API_URL=/api react-scripts build\"|\"build\": \"cross-env REACT_APP_API_URL=https://futuresofhope.org react-scripts build\"|' package.json
    npm run build
    # Restore original package.json
    git checkout package.json 2>/dev/null || true
    cd ..
    
    # Copy builds to server directory where Express expects them
    echo 'Copying builds to server directory...'
    mkdir -p server/admin server/user
    cp -r admin/build server/admin/
    cp -r user/build server/user/
    
    echo '✅ Builds completed and copied to server'
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
PORT=8088
HOST=0.0.0.0
EOF
    
    # Add OpenAI key securely
    echo 'OPENAI_API_KEY=$OPENAI_KEY' >> server/.env
    
    echo 'Environment configured with OpenAI API key'
"

echo "🌐 Setting up nginx and SSL..."
run_on_ec2 "
    # Install nginx and certbot if not present
    if ! command -v nginx &> /dev/null; then
        echo 'Installing nginx and certbot...'
        sudo apt update
        sudo apt install -y nginx certbot python3-certbot-nginx
    fi
    
    # Create initial nginx configuration for futuresofhope.org (HTTP only for certbot)
    NGINX_CONF='/etc/nginx/sites-available/futuresofhope.org'
    if [ ! -f \"\$NGINX_CONF\" ]; then
        echo 'Creating initial nginx configuration...'
        sudo tee \"\$NGINX_CONF\" > /dev/null << 'NGINXEOF'
# Nginx configuration for futuresofhope.org
server {
    listen 80;
    server_name futuresofhope.org www.futuresofhope.org;
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_buffers 16 4k;
        proxy_buffer_size 2k;
        proxy_pass http://127.0.0.1:8088;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXEOF
        
        # Enable the site
        sudo ln -sf \"\$NGINX_CONF\" /etc/nginx/sites-enabled/
        
        # Remove default site
        sudo rm -f /etc/nginx/sites-enabled/default
        
        # Create web root for certbot
        sudo mkdir -p /var/www/html
        
        # Test and reload nginx
        sudo nginx -t && sudo systemctl enable nginx && sudo systemctl reload nginx
        echo 'Initial nginx configuration created'
    else
        echo 'Nginx configuration already exists'
    fi
    
    # Obtain SSL certificate
    echo 'Setting up SSL certificate...'
    if [ ! -f /etc/letsencrypt/live/futuresofhope.org/fullchain.pem ]; then
        echo 'Obtaining SSL certificate from Let'\''s Encrypt...'
        sudo certbot --nginx -d futuresofhope.org -d www.futuresofhope.org --non-interactive --agree-tos --email admin@futuresofhope.org --redirect
        echo 'SSL certificate obtained and nginx configured for HTTPS'
    else
        echo 'SSL certificate already exists'
    fi
    
    # Setup auto-renewal
    echo 'Setting up SSL certificate auto-renewal...'
    (sudo crontab -l 2>/dev/null || true; echo '0 12 * * * /usr/bin/certbot renew --quiet') | sudo crontab -
    
    echo 'SSL setup completed'
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
HEALTH_CHECK=$(run_on_ec2 "curl -s http://localhost:8088/api/health | jq -r '.status' 2>/dev/null || echo 'failed'")

if [ "$HEALTH_CHECK" = "healthy" ]; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🌐 Access your application:"
    echo "  User Interface: https://futuresofhope.org/"
    echo "  Admin Panel: https://futuresofhope.org/admin"
    echo "  API Documentation: https://futuresofhope.org/api-docs"
    echo "  Health Check: https://futuresofhope.org/api/health"
    echo ""
    echo "🔒 SSL Certificate:"
    echo "  - HTTPS enabled and configured"
    echo "  - Auto-renewal set up via cron"
    echo "  - HTTP requests redirect to HTTPS"
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