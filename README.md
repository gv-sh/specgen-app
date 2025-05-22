# SpecGen App - Complete Platform

[![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)](https://github.com/gv-sh/specgen-app)

A unified deployment package for the SpecGen speculative fiction generator platform. **Now optimized for low-memory servers and unified on port 8080!**

## 🚀 What's New

- **Single Port Deployment**: Everything runs on port 8080 with clean URL paths
- **Low Memory Default**: Optimized for small servers and EC2 instances
- **Automatic Cleanup**: Smart setup that cleans existing installations
- **Unified Interface**: All services accessible through one port

## Components

- **Server**: Node.js API with OpenAI integration (Port 8080)
- **Admin**: React admin interface at `/admin`
- **User**: React user interface at `/app` (also default at `/`)

## Quick Start

### Using NPX (Recommended)

```bash
# Create and enter your project directory
mkdir specgen-project
cd specgen-project

# Run setup (automatically includes low-memory optimizations and cleanup)
npx @gv-sh/specgen-app setup

# Start in development mode (traditional separate ports)
npx @gv-sh/specgen-app dev

# Or start in production mode (unified port 8080)
npx @gv-sh/specgen-app production

# Or deploy with PM2 (recommended for servers)
npx @gv-sh/specgen-app deploy
```

## 🌐 Access URLs

### Production Mode (Port 8080 - Unified)
- **Main Application**: http://localhost:8080/
- **User Interface**: http://localhost:8080/app
- **Admin Panel**: http://localhost:8080/admin
- **API Documentation**: http://localhost:8080/api-docs
- **Health Check**: http://localhost:8080/api/health
- **API Endpoints**: http://localhost:8080/api/*

### Development Mode (Separate Ports)
- **User Interface**: http://localhost:3002
- **Admin Interface**: http://localhost:3001
- **API Server**: http://localhost:8080

## 🖥️ Server Deployment

### Option 1: Quick AWS/VPS Deployment

Perfect for EC2, DigitalOcean, or any Ubuntu server:

1. **SSH into your server**:
   ```bash
   ssh -i "key.pem" ubuntu@your-server-ip
   ```

2. **Install Node.js 20+** (required):
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Deploy SpecGen** (one command setup with cleanup):
   ```bash
   mkdir specgen && cd specgen
   npx @gv-sh/specgen-app setup
   npx @gv-sh/specgen-app deploy
   ```

4. **Access your application**:
   - **Main**: http://your-server-ip:8080/
   - **User App**: http://your-server-ip:8080/app
   - **Admin Panel**: http://your-server-ip:8080/admin

### Option 2: Manual Setup

```bash
# Clone and setup manually
git clone https://github.com/gv-sh/specgen-app.git
cd specgen-app
npm run setup
npm run deploy
```

## 🛠️ Setup Features

The setup script now includes **comprehensive cleanup**:

- ✅ **PM2 Process Cleanup**: Stops and removes existing PM2 processes
- ✅ **Port Liberation**: Frees up ports 8080, 3000, 3001, 3002
- ✅ **Nginx Cleanup**: Removes conflicting nginx configurations
- ✅ **Docker Cleanup**: Removes any existing SpecGen containers
- ✅ **Service Cleanup**: Removes systemd services
- ✅ **File Cleanup**: Removes old installations and log files
- ✅ **Low Memory Optimization**: Optimized for servers with limited RAM

## 📋 Available Commands

### Core Commands
```bash
# Setup with cleanup (one-time)
npx @gv-sh/specgen-app setup

# Development mode (separate ports)
npx @gv-sh/specgen-app dev

# Production mode (direct run on port 8080)
npx @gv-sh/specgen-app production

# Production deployment with PM2 (recommended)
npx @gv-sh/specgen-app deploy
```

### Management Commands
```bash
# Check deployment status
npx @gv-sh/specgen-app deploy:status

# Stop all services
npx @gv-sh/specgen-app deploy:stop

# Restart services
npx @gv-sh/specgen-app deploy:restart
```

### Using NPM Scripts (if you cloned the repo)
```bash
npm run setup      # Setup with cleanup
npm run dev        # Development mode
npm run production # Production mode
npm run deploy     # Deploy with PM2
```

## 🔧 Configuration

### OpenAI API Key
You'll be prompted for your OpenAI API key during setup. If you skip it, add it later to `server/.env`:

```env
OPENAI_API_KEY=your_openai_api_key_here
NODE_ENV=production
PORT=8080
```

### Environment Files
The setup automatically creates optimized environment files:
- `server/.env` - Server configuration (port 8080)
- `admin/.env.development` - Admin dev settings
- `user/.env.development` - User dev settings

## 🐳 Docker Alternative

If you prefer Docker:

```bash
# Quick Docker setup
docker run -d \
  --name specgen \
  -p 8080:8080 \
  -e OPENAI_API_KEY=your_key_here \
  gvsh/specgen-app:latest
```

## 📊 Management with PM2

When deployed with `npm run deploy`, you get PM2 process management:

```bash
# Check status
npx pm2 status

# View logs
npx pm2 logs specgen

# Restart
npx pm2 restart specgen

# Stop
npx pm2 stop specgen

# Monitor
npx pm2 monit
```

## 🔍 Troubleshooting

### Common Issues

1. **Port 8080 Already in Use**:
   ```bash
   # The setup script handles this automatically, but if needed:
   sudo lsof -ti:8080 | xargs kill -9
   ```

2. **Out of Memory on Small Servers**:
   ```bash
   # Add swap space (setup script suggests this)
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

3. **Node.js Version Issues**:
   ```bash
   # Ensure Node.js 20+ is installed
   node --version  # Should be v20+
   ```

4. **SQLite3 Binding Errors**:
   ```bash
   # The setup script includes engine-strict=false
   # If issues persist, run setup again - it includes full cleanup
   npx @gv-sh/specgen-app setup
   ```

### Health Check
Test if your deployment is working:
```bash
curl http://localhost:8080/api/health
# Should return: {"status":"ok","port":8080}
```

## 🚨 Breaking Changes from Previous Versions

- **Port Change**: Default port changed from 3000 → 8080
- **URL Structure**: Admin at `/admin`, User at `/app`
- **Simplified Scripts**: Single `setup` and `production` commands
- **Automatic Cleanup**: Setup now cleans existing installations

## 📚 API Documentation

Once deployed, access the interactive API documentation at:
- **Swagger UI**: http://your-server:8080/api-docs

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the ISC License.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/gv-sh/specgen-app/issues)
- **Documentation**: Check `/api-docs` when running
- **Health Check**: Visit `/api/health` to verify installation