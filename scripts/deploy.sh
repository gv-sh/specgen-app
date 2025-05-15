#!/bin/bash

# AWS Ubuntu Deployment Script for SpecGen
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting SpecGen deployment...${NC}"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
echo -e "${YELLOW}Installing Node.js 18...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
echo -e "${YELLOW}Installing PM2...${NC}"
sudo npm install -g pm2

# Install Nginx
echo -e "${YELLOW}Installing Nginx...${NC}"
sudo apt install -y nginx

# Create application directory
sudo mkdir -p /opt/specgen-app
cd /opt/specgen-app

# Download and extract packages
echo -e "${YELLOW}Downloading SpecGen packages...${NC}"
npm pack @gv-sh/specgen-server
npm pack @gv-sh/specgen-admin  
npm pack @gv-sh/specgen-user

# Extract packages
tar -xzf gv-sh-specgen-server-*.tgz && mv package server
tar -xzf gv-sh-specgen-admin-*.tgz && mv package admin
tar -xzf gv-sh-specgen-user-*.tgz && mv package user

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
cd server && npm install --production
cd ../admin && npm install --production
cd ../user && npm install --production
cd ..

# Setup environment
echo -e "${YELLOW}Setting up environment...${NC}"
read -p "Enter your OpenAI API key: " OPENAI_KEY
read -p "Enter your domain (or IP): " DOMAIN

# Server .env
echo "OPENAI_API_KEY=$OPENAI_KEY" | sudo tee server/.env
echo "NODE_ENV=production" | sudo tee -a server/.env
echo "PORT=3000" | sudo tee -a server/.env

# Admin .env.production
echo "REACT_APP_API_URL=http://$DOMAIN" | sudo tee admin/.env.production
echo "GENERATE_SOURCEMAP=false" | sudo tee -a admin/.env.production

# User .env.production  
echo "REACT_APP_API_URL=http://$DOMAIN" | sudo tee user/.env.production
echo "GENERATE_SOURCEMAP=false" | sudo tee -a user/.env.production

# Build React apps
echo -e "${YELLOW}Building React applications...${NC}"
cd admin && NODE_ENV=production npm run build
cd ../user && NODE_ENV=production npm run build
cd ..

# Create PM2 ecosystem
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'specgen-server',
    script: './server/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
EOF

# Start server with PM2
echo -e "${YELLOW}Starting server with PM2...${NC}"
pm2 start ecosystem.config.js
pm2 startup
pm2 save

# Configure Nginx
echo -e "${YELLOW}Configuring Nginx...${NC}"
sudo tee /etc/nginx/sites-available/specgen << 'EOF'
server {
    listen 80 default_server;
    server_name _;

    # API
    location /api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Admin UI
    location /admin/ {
        alias /opt/specgen-app/admin/build/;
        try_files $uri $uri/ /admin/index.html;
    }

    # User UI (default)
    location / {
        root /opt/specgen-app/user/build;
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Gzip compression
    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types
        application/javascript
        application/json
        application/x-javascript
        application/xml
        application/xml+rss
        text/css
        text/javascript
        text/plain
        text/xml;
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/specgen /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t
sudo systemctl restart nginx

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Initialize database
echo -e "${YELLOW}Initializing database...${NC}"
cd server && npm run init-db

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}Access your application at:${NC}"
echo -e "  User Interface: http://your-server-ip/"
echo -e "  Admin Interface: http://your-server-ip/admin/"
echo -e "  API: http://your-server-ip/api/"

# Setup SSL (optional)
read -p "Would you like to set up SSL with Let's Encrypt? (y/n): " setup_ssl
if [[ $setup_ssl == "y" ]]; then
    read -p "Enter your domain name: " domain_name
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d $domain_name
fi

echo -e "${GREEN}Setup complete!${NC}"
