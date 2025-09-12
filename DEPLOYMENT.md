# Quick Deployment Guide for Gaia-X

## Immediate Setup Steps

### 1. Install Prerequisites
```bash
# Install Wrangler for Cloudflare
npm install -g wrangler

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash

# Install jq for JSON processing
sudo apt-get install jq
```

### 2. Authentication
```bash
# Cloudflare
wrangler login

# Azure
az login

# Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### 3. Quick Deploy
```bash
# Make CLI executable
chmod +x gaia-x-cli.sh

# Initialize configuration
./gaia-x-cli.sh init

# Deploy Cloudflare Worker
wrangler deploy

# Trigger Azure deployment (via GitHub Actions)
git push origin main

# Deploy Google Cloud Function
cd gcloud-functions
gcloud functions deploy gaia-x-orchestrate \
  --runtime python39 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point gaia_x_orchestrate
```

### 4. Test Voice Commands
```bash
# Enter interactive mode
./gaia-x-cli.sh voice

# Try these commands:
Voice> status
Voice> deploy cloudflare
Voice> deploy all
Voice> exit
```

### 5. Configuration
Edit `gaia-x-config.json` with your specific IDs:
- Cloudflare account/zone IDs
- Azure subscription/resource group
- Google Cloud project ID

## API Endpoints
- Cloudflare Worker: `https://gaia-x.YOUR_USERNAME.workers.dev`
- Azure Function: `https://agentazure.azurewebsites.net/api/orchestrate`
- Google Cloud: `https://REGION-PROJECT.cloudfunctions.net/gaia-x-orchestrate`

## Troubleshooting
- Check logs: `tail -f gaia-x.log`
- Verify status: `./gaia-x-cli.sh status`
- Reset config: `rm gaia-x-config.json && ./gaia-x-cli.sh init`