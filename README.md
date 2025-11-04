# SpecGen App - Complete Platform

[![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)](https://github.com/gv-sh/specgen-app)

A unified deployment package for the SpecGen speculative fiction generator platform. **Optimized for port 80 deployment with low memory usage.**

## 🚀 Quick Start

### One-Command Deployment (Recommended)

```bash
# Create project directory
mkdir specgen && cd specgen

# Deploy everything in one command
npx @gv-sh/specgen-app deploy
```

**What this does:**
- Downloads and sets up server, admin, and user components
- Builds React frontends optimized for production
- Configures everything for port 80
- Starts with PM2 for process management
- Prompts for OpenAI API key

## 🌐 Access URLs

Once deployed, access your application at:

- **Main Application**: http://your-server:80/
- **User Interface**: http://your-server:80/app  
- **Admin Panel**: http://your-server:80/admin
- **API Documentation**: http://your-server:80/api-docs
- **Health Check**: http://your-server:80/api/health
- **API Endpoints**: http://your-server:80/api/*

## 🖥️ Server Requirements

### Minimum Requirements
- **Node.js**: 20.0.0 or higher
- **RAM**: 1GB minimum (2GB recommended)
- **Storage**: 2GB free space
- **OS**: Ubuntu 20.04+ (or similar Linux distribution)

### Quick Server Setup (Ubuntu)

```bash
# Install Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version  # Should show v20.x.x or higher
npm --version
```

## 📋 Deployment Methods

### Method 1: Direct NPX Deployment (Easiest)

```bash
# SSH into your server
ssh -i "your-key.pem" ubuntu@your-server-ip

# Create project and deploy
mkdir specgen && cd specgen
npx @gv-sh/specgen-app deploy
```

### Method 2: Development Mode

For local development with separate ports:

```bash
mkdir specgen-dev && cd specgen-dev
npx @gv-sh/specgen-app setup
npx @gv-sh/specgen-app dev
```

**Development URLs:**
- User Interface: http://localhost:3002
- Admin Interface: http://localhost:3001  
- API Server: http://localhost:80

### Method 3: Manual Deployment

If you prefer more control:

```bash
# Clone repository
git clone https://github.com/gv-sh/specgen-app.git
cd specgen-app

# Setup and deploy
npm run setup
npm run deploy
```

## 🔧 Configuration

### OpenAI API Key Setup

During deployment, you'll be prompted for your OpenAI API key. You can also set it manually:

```bash
# Create/edit the environment file
echo "OPENAI_API_KEY=your_openai_api_key_here" > server/.env
echo "NODE_ENV=production" >> server/.env
echo "PORT=80" >> server/.env

# Restart the service
npx pm2 restart specgen --update-env
```

### Environment Variables

The deployment creates these configuration files:
- `server/.env` - Server configuration (port 80, API key)
- `admin/.env.development` - Admin development settings  
- `user/.env.development` - User development settings

## 📊 Process Management

The deployment uses PM2 for process management:

```bash
# Check status
npx pm2 status

# View logs  
npx pm2 logs specgen

# Restart application
npx pm2 restart specgen

# Stop application
npx pm2 stop specgen

# Monitor resources
npx pm2 monit
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### 1. Port 80 Already in Use
```bash
# Check what's using the port
sudo lsof -i :80

# Kill the process
sudo lsof -ti:80 | xargs kill -9

# Redeploy
npx @gv-sh/specgen-app deploy
```

#### 2. Frontend Not Loading (404 Errors)
```bash
# Check if builds exist
ls -la admin/build/
ls -la user/build/

# If missing, manually rebuild
cd admin && npm install && GENERATE_SOURCEMAP=false PUBLIC_URL=/admin npm run build
cd ../user && npm install && GENERATE_SOURCEMAP=false REACT_APP_API_URL=/api PUBLIC_URL=/app npm run build

# Restart server
npx pm2 restart specgen
```

#### 3. OpenAI API Key Issues
```bash
# Check current environment
npx pm2 env 0

# Update API key
echo "OPENAI_API_KEY=your_new_key_here" > server/.env
echo "NODE_ENV=production" >> server/.env
echo "PORT=80" >> server/.env

# Restart with new environment
npx pm2 restart specgen --update-env
```

#### 4. Out of Memory Errors
```bash
# Add swap space (2GB recommended)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap is active
free -h
```

#### 5. Node.js Version Issues
```bash
# Check current version
node --version

# If less than v20, update:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Debugging Commands

```bash
# Test API health
curl http://localhost:80/api/health

# Test main page response
curl -I http://localhost:80/

# Check server logs
npx pm2 logs specgen --lines 50

# Check build status
ls -la */build/ 2>/dev/null || echo "No builds found"

# Check processes listening on port 80
sudo netstat -tlnp | grep :80
```

### Manual Build Process

If automatic builds fail, try manual building:

```bash
# Stop current deployment
npx pm2 stop specgen

# Manual server setup
npm pack @gv-sh/specgen-server
tar -xzf gv-sh-specgen-server-*.tgz
mv package server
cd server && npm install && cd ..

# Manual admin build
npm pack @gv-sh/specgen-admin  
tar -xzf gv-sh-specgen-admin-*.tgz
mv package admin
cd admin && npm install && GENERATE_SOURCEMAP=false PUBLIC_URL=/admin npm run build && cd ..

# Manual user build
npm pack @gv-sh/specgen-user
tar -xzf gv-sh-specgen-user-*.tgz  
mv package user
cd user && npm install && GENERATE_SOURCEMAP=false REACT_APP_API_URL=/api PUBLIC_URL=/app npm run build && cd ..

# Restart deployment
npx pm2 start server/index.js --name specgen
```

## 🚨 Known Issues

### Current Limitations
- **Memory Usage**: Requires at least 1GB RAM for builds
- **Build Time**: Initial deployment can take 5-10 minutes
- **SQLite Dependencies**: May require build tools on some systems
- **Static File Serving**: Builds must complete successfully for frontend access

### AWS EC2 Specific
- **Security Groups**: Ensure port 80 is open in your security group
- **Instance Type**: t2.micro may struggle with builds (t2.small recommended)
- **Storage**: Ensure at least 2GB free space for node_modules and builds

## 📚 API Documentation

Once deployed, access interactive API documentation at:
- **Swagger UI**: http://your-server:80/api-docs

### Key API Endpoints
- `GET /api/health` - Health check and system status
- `POST /api/generate` - Generate speculative fiction content
- `GET /api/categories` - List available story categories
- `GET /api/parameters` - Get generation parameters

## 🔄 Updates and Maintenance

### Updating SpecGen
```bash
# Stop current deployment
npx pm2 stop specgen

# Clean up old installation
rm -rf admin user server node_modules

# Deploy latest version
npx @gv-sh/specgen-app deploy
```

### Backup Important Data
```bash
# Backup database and configurations
tar -czf specgen-backup-$(date +%Y%m%d).tar.gz server/data server/.env logs/
```

## 🤝 Support

### Getting Help
- **Health Check**: Visit http://your-server:80/api/health
- **Logs**: Run `npx pm2 logs specgen`
- **Issues**: [GitHub Issues](https://github.com/gv-sh/specgen-app/issues)
- **Status**: Run `npx pm2 status` to check process status

### Reporting Bugs
When reporting issues, please include:
- Output of `npx pm2 logs specgen`
- Output of `curl http://localhost:80/api/health`
- Your server specifications (RAM, OS version, Node.js version)
- Any error messages from the deployment process

## 📄 License

This project is licensed under the ISC License.