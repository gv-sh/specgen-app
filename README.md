# SpecGen App - Complete Platform

[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](https://github.com/gv-sh/specgen-app)

A unified deployment package for the SpecGen speculative fiction generator platform.

## Components

- **Server**: Node.js API with OpenAI integration
- **Admin**: React admin interface for content management
- **User**: React user interface for story generation

## Quick Start

### Using NPX (Recommended)

```bash
# Create and enter your project directory
mkdir specgen-project
cd specgen-project

# Run setup directly with npx
npx @gv-sh/specgen-app setup

# Start in development mode
npx @gv-sh/specgen-app dev

# Or start in production mode
npx @gv-sh/specgen-app production
```

### Low Memory Mode for Small Servers

If you're deploying on a small EC2 instance or any server with limited RAM:

```bash
# First, add swap space to prevent out-of-memory errors
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Then use the low-memory versions of the commands
npx @gv-sh/specgen-app setup-low-memory
npx @gv-sh/specgen-app production-low-memory
```

### Using NPM Scripts

1. **Setup**:
   ```bash
   npm run setup
   ```
   During setup, you'll be prompted to enter your OpenAI API key.

2. **Add OpenAI API Key** to `server/.env` if you skipped during setup

3. **Start Development**:
   ```bash
   npm run dev
   ```

4. **Start Production** (optimized build with API key validation):
   ```bash
   npm run production
   ```

## Access URLs

- User Interface: http://localhost:3002
- Admin Interface: http://localhost:3001
- API: http://localhost:3000

## Deployment Options

### Option 1: Quick NPX Deployment to Remote Server

If you have SSH access to a server (like an EC2 instance), this is the fastest way to deploy:

1. **Save your SSH key** to a file (e.g., `key.pem`) and set permissions:
   ```bash
   chmod 400 key.pem
   ```

2. **SSH into your server**:
   ```bash
   ssh -i "key.pem" ubuntu@your-server-ip
   ```

3. **Install Node.js 18 or higher**:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

4. **Install and run SpecGen**:
   ```bash
   # Add swap space to prevent out-of-memory errors
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   
   # Create and enter project directory
   mkdir specgen
   cd specgen
   
   # Run the setup with low memory optimization
   npx @gv-sh/specgen-app setup-low-memory
   
   # Start in production mode with low memory optimization
   npx @gv-sh/specgen-app production-low-memory
   ```

5. **Keep the service running with PM2** (recommended):
   ```bash
   sudo npm install -g pm2
   # Use the low-memory production mode with PM2
   pm2 start "npx @gv-sh/specgen-app production-low-memory" --name "specgen"
   pm2 startup
   pm2 save
   ```

6. **Access your application**:
   - User Interface: http://your-server-ip:3002
   - Admin Interface: http://your-server-ip:3001
   - API: http://your-server-ip:3000

### Option 2: Global NPM Package Deployment

#### Local Machine Deployment

1. **Install globally** (recommended for deployment):
   ```bash
   npm install -g @gv-sh/specgen-app
   ```

2. **Create a project directory**:
   ```bash
   mkdir specgen-project
   cd specgen-project
   ```

3. **Initialize and setup**:
   ```bash
   specgen-app setup
   ```
   During setup, you'll be prompted to enter your OpenAI API key.

4. **Start the application**:
   - Development mode: `specgen-app dev`
   - Production mode: `specgen-app production`

#### Remote Server Deployment

1. **SSH into your server**:
   ```bash
   ssh -i "your-key.pem" username@your-server
   ```

2. **Install Node.js** (if not already installed):
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Create a project directory**:
   ```bash
   mkdir specgen
   cd specgen
   ```

4. **Install SpecGen globally**:
   ```bash
   npm install -g @gv-sh/specgen-app
   ```

5. **Setup the application**:
   ```bash
   specgen-app setup
   ```

6. **Start in production mode**:
   ```bash
   specgen-app production
   ```

### Option 3: Manual Deployment

Alternatively, you can deploy manually using the repository:

#### Build and Run Locally
```bash
git clone https://github.com/gv-sh/specgen-app.git
cd specgen-app
npm run setup
npm run build
npm run production
```

#### AWS Deployment Script

1. Launch Ubuntu 22.04 instance with SSH access
2. Run deployment script:

```bash
# On AWS instance
wget https://github.com/gv-sh/specgen-app/raw/main/scripts/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

## Management Commands

When using NPX or global installation:
```bash
# Check status
npx @gv-sh/specgen-app deploy:status
# or when installed globally
specgen-app deploy:status

# Stop services
npx @gv-sh/specgen-app deploy:stop
# or
specgen-app deploy:stop

# Restart services
npx @gv-sh/specgen-app deploy:restart
# or
specgen-app deploy:restart

# Update to latest version
npm update -g @gv-sh/specgen-app
```

When using the repository:
```bash
# Stop services
npm run deploy:stop

# Restart services
npm run deploy:restart

# Update to latest
npm run deploy:update

# Check status
npm run deploy:status

# Create backup
npm run deploy:backup
```

## Available Commands

The following commands are available when using `npx @gv-sh/specgen-app` or `specgen-app` (if installed globally):

- `setup` - Set up the SpecGen application
- `setup-low-memory` - Set up the SpecGen application with memory optimizations
- `production` - Run the application in production mode
- `production-low-memory` - Run the application in production mode with memory optimizations
- `dev` - Run the application in development mode
- `deploy` - Deploy the application
- `deploy:stop` - Stop the deployed application
- `deploy:restart` - Restart the deployed application
- `deploy:update` - Update the deployed application
- `deploy:status` - Check the status of the deployed application
- `deploy:backup` - Create a backup of the deployed application
- `troubleshoot` - Run troubleshooting checks

## Troubleshooting

If you encounter issues:

```bash
# Using npx
npx @gv-sh/specgen-app troubleshoot

# Using global installation
specgen-app troubleshoot

# For repository installation
npm run troubleshoot
```

This will check your setup and identify common problems.

## Environment Variables

The setup script creates necessary environment files automatically. You only need to add your OpenAI API key during setup or later to `server/.env`.