# SpecGen App - Complete Platform

[![Version](https://img.shields.io/badge/version-0.3.0-blue.svg)](https://github.com/gv-sh/specgen-app)

A unified deployment package for the SpecGen speculative fiction generator platform.

## Components

- **Server**: Node.js API with OpenAI integration
- **Admin**: React admin interface for content management
- **User**: React user interface for story generation

## Quick Start

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

### Option 1: Quick NPM Deployment to Remote Server

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
   # Install globally
   sudo npm install -g @gv-sh/specgen-app
   
   # Create and enter project directory
   mkdir specgen
   cd specgen
   
   # Run the setup
   npx @gv-sh/specgen-app setup
   
   # Start in production mode
   npx @gv-sh/specgen-app production
   ```

5. **Keep the service running with PM2** (recommended):
   ```bash
   sudo npm install -g pm2
   pm2 start "npx @gv-sh/specgen-app production" --name "specgen"
   pm2 startup
   pm2 save
   ```

6. **Access your application**:
   - User Interface: http://your-server-ip:3000
   - Admin Interface: http://your-server-ip:3000/admin

### Option 2: NPM Package Deployment (Detailed)

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
   npx @gv-sh/specgen-app setup
   ```
   During setup, you'll be prompted to enter your OpenAI API key.

4. **Start the application**:
   - Development mode: `npx @gv-sh/specgen-app dev`
   - Production mode: `npx @gv-sh/specgen-app production`

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

4. **Install SpecGen**:
   ```bash
   npm install @gv-sh/specgen-app
   ```

5. **Setup the application**:
   ```bash
   npx @gv-sh/specgen-app setup
   ```

6. **Start in production mode**:
   ```bash
   npx @gv-sh/specgen-app production
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

When using NPM global installation:
```bash
# Check status
npx @gv-sh/specgen-app status

# Stop services
npx @gv-sh/specgen-app stop

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

## Troubleshooting

If you encounter issues:

```bash
# For global NPM installation
npx @gv-sh/specgen-app troubleshoot

# For repository installation
npm run troubleshoot
```

This will check your setup and identify common problems.

## Environment Variables

The setup script creates necessary environment files automatically. You only need to add your OpenAI API key during setup or later to `server/.env`.