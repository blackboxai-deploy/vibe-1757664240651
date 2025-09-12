#!/bin/bash

# Gaia-X Multi-Cloud Orchestration CLI
# Unified interface for Azure, Cloudflare, and Google Cloud operations

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/gaia-x-config.json"
WORKER_URL="https://gaia-x.${USER}.workers.dev"
LOG_FILE="$SCRIPT_DIR/gaia-x.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_color() {
    echo -e "${2}${1}${NC}"
}

# Check if required CLI tools are installed
check_prerequisites() {
    local missing_tools=()
    
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    if ! command -v wrangler &> /dev/null; then
        missing_tools+=("wrangler")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("google-cloud-sdk")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_color "Missing required tools: ${missing_tools[*]}" "$RED"
        print_color "Please install them before running this script." "$YELLOW"
        exit 1
    fi
    
    print_color "All required CLI tools are available." "$GREEN"
}

# Initialize configuration
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_color "Creating initial configuration..." "$BLUE"
        cat > "$CONFIG_FILE" << EOF
{
  "cloudflare": {
    "worker_name": "gaia-x",
    "zone_id": "",
    "account_id": ""
  },
  "azure": {
    "resource_group": "gaia-x-rg",
    "function_app": "Agentazure",
    "subscription": ""
  },
  "gcloud": {
    "project_id": "",
    "region": "us-central1",
    "service_name": "gaia-x-service"
  },
  "voice_agent": {
    "enabled": true,
    "webhook_url": "$WORKER_URL/voice-command"
  }
}
EOF
        print_color "Configuration file created at: $CONFIG_FILE" "$GREEN"
        print_color "Please edit the configuration file with your specific settings." "$YELLOW"
    fi
}

# Voice command processing
process_voice_command() {
    local command="$1"
    local context="${2:-}"
    
    print_color "Processing voice command: $command" "$BLUE"
    log "Voice command received: $command"
    
    # Send to worker for processing
    local response=$(curl -s -X POST "$WORKER_URL/voice-command" \
        -H "Content-Type: application/json" \
        -d "{\"command\":\"$command\",\"context\":\"$context\"}")
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq -r '.result.message // .message // "Command processed"'
        log "Voice command processed successfully"
    else
        print_color "Failed to process voice command" "$RED"
        log "Voice command processing failed"
    fi
}

# Deploy to Cloudflare
deploy_cloudflare() {
    print_color "Deploying to Cloudflare..." "$BLUE"
    log "Starting Cloudflare deployment"
    
    cd "$SCRIPT_DIR"
    
    if wrangler deploy; then
        print_color "Cloudflare deployment successful!" "$GREEN"
        log "Cloudflare deployment completed successfully"
        
        # Notify worker of deployment
        curl -s -X POST "$WORKER_URL/webhook-forward" \
            -H "Content-Type: application/json" \
            -d "{\"event\":\"cloudflare_deployment\",\"status\":\"success\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /dev/null
    else
        print_color "Cloudflare deployment failed!" "$RED"
        log "Cloudflare deployment failed"
        exit 1
    fi
}

# Deploy to Azure
deploy_azure() {
    print_color "Triggering Azure deployment..." "$BLUE"
    log "Starting Azure deployment"
    
    local config=$(cat "$CONFIG_FILE")
    local resource_group=$(echo "$config" | jq -r '.azure.resource_group')
    local function_app=$(echo "$config" | jq -r '.azure.function_app')
    
    # Check if Azure Function App exists
    if az functionapp show --resource-group "$resource_group" --name "$function_app" &> /dev/null; then
        print_color "Azure Function App exists. Triggering GitHub Actions deployment..." "$GREEN"
        log "Azure Function App verified, triggering deployment"
        
        # Trigger GitHub Actions workflow via API
        curl -s -X POST "$WORKER_URL/github-commit" \
            -H "Content-Type: application/json" \
            -d "{\"message\":\"Trigger Azure deployment\",\"files\":[{\"path\":\"trigger.txt\",\"content\":\"$(date)\"}]}" > /dev/null
        
        print_color "Azure deployment triggered via GitHub Actions" "$GREEN"
        log "Azure deployment triggered successfully"
    else
        print_color "Azure Function App not found. Please check your configuration." "$RED"
        log "Azure Function App not found"
        exit 1
    fi
}

# Deploy to Google Cloud
deploy_gcloud() {
    print_color "Deploying to Google Cloud..." "$BLUE"
    log "Starting Google Cloud deployment"
    
    local config=$(cat "$CONFIG_FILE")
    local project_id=$(echo "$config" | jq -r '.gcloud.project_id')
    local region=$(echo "$config" | jq -r '.gcloud.region')
    local service_name=$(echo "$config" | jq -r '.gcloud.service_name')
    
    if [ "$project_id" = "null" ] || [ -z "$project_id" ]; then
        print_color "Google Cloud project ID not configured. Please update $CONFIG_FILE" "$RED"
        log "Google Cloud project ID missing"
        exit 1
    fi
    
    # Set the project
    gcloud config set project "$project_id"
    
    # Example: Deploy a Cloud Function (modify as needed)
    if [ -f "main.py" ]; then
        gcloud functions deploy "$service_name" \
            --runtime python39 \
            --trigger-http \
            --allow-unauthenticated \
            --region "$region" \
            --source .
        
        print_color "Google Cloud deployment successful!" "$GREEN"
        log "Google Cloud deployment completed successfully"
    else
        print_color "No deployable code found for Google Cloud. Skipping..." "$YELLOW"
        log "Google Cloud deployment skipped - no deployable code"
    fi
}

# Orchestrate all platforms
deploy_all() {
    print_color "Starting multi-cloud deployment..." "$BLUE"
    log "Multi-cloud deployment initiated"
    
    deploy_cloudflare
    deploy_azure
    deploy_gcloud
    
    print_color "Multi-cloud deployment completed!" "$GREEN"
    log "Multi-cloud deployment completed successfully"
    
    # Notify completion
    curl -s -X POST "$WORKER_URL/orchestrate" \
        -H "Content-Type: application/json" \
        -d "{\"operation\":\"deploy_all\",\"platform\":\"multi-cloud\",\"parameters\":{\"status\":\"completed\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" > /dev/null
}

# Check status of all platforms
check_status() {
    print_color "Checking platform status..." "$BLUE"
    
    # Cloudflare Worker health check
    print_color "Cloudflare Worker:" "$YELLOW"
    if curl -s -f "$WORKER_URL/health" > /dev/null; then
        print_color "  ✓ Online" "$GREEN"
    else
        print_color "  ✗ Offline" "$RED"
    fi
    
    # Azure Function status
    print_color "Azure Functions:" "$YELLOW"
    local config=$(cat "$CONFIG_FILE")
    local resource_group=$(echo "$config" | jq -r '.azure.resource_group')
    local function_app=$(echo "$config" | jq -r '.azure.function_app')
    
    if az functionapp show --resource-group "$resource_group" --name "$function_app" --query "state" -o tsv 2>/dev/null | grep -q "Running"; then
        print_color "  ✓ Running" "$GREEN"
    else
        print_color "  ✗ Not Running" "$RED"
    fi
    
    # Google Cloud status (simplified)
    print_color "Google Cloud:" "$YELLOW"
    local project_id=$(echo "$config" | jq -r '.gcloud.project_id')
    
    if [ "$project_id" != "null" ] && [ -n "$project_id" ]; then
        if gcloud config get-value project &> /dev/null; then
            print_color "  ✓ Authenticated" "$GREEN"
        else
            print_color "  ✗ Not Authenticated" "$RED"
        fi
    else
        print_color "  ⚠ Not Configured" "$YELLOW"
    fi
}

# Interactive voice mode
voice_mode() {
    print_color "Entering voice command mode..." "$BLUE"
    print_color "Type your commands (or 'exit' to quit):" "$YELLOW"
    
    while true; do
        echo -n "Voice> "
        read -r command
        
        case "$command" in
            "exit"|"quit"|"q")
                print_color "Exiting voice mode..." "$GREEN"
                break
                ;;
            "deploy cloudflare"|"deploy cf")
                deploy_cloudflare
                ;;
            "deploy azure")
                deploy_azure
                ;;
            "deploy gcloud"|"deploy google")
                deploy_gcloud
                ;;
            "deploy all")
                deploy_all
                ;;
            "status"|"check")
                check_status
                ;;
            "help")
                show_help
                ;;
            *)
                if [ -n "$command" ]; then
                    process_voice_command "$command"
                fi
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
Gaia-X Multi-Cloud Orchestration CLI

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  init              Initialize configuration
  deploy            Deploy to specified platform(s)
    cloudflare      Deploy to Cloudflare Workers
    azure           Deploy to Azure Functions
    gcloud          Deploy to Google Cloud
    all             Deploy to all platforms
  status            Check status of all platforms
  voice             Enter interactive voice command mode
  voice-cmd         Process a single voice command
  help              Show this help message

Voice Commands:
  - "deploy cloudflare" / "deploy cf"
  - "deploy azure"
  - "deploy gcloud" / "deploy google"
  - "deploy all"
  - "status" / "check"
  - "exit" / "quit" / "q"

Examples:
  $0 deploy all                    # Deploy to all platforms
  $0 deploy cloudflare            # Deploy only to Cloudflare
  $0 status                       # Check platform status
  $0 voice                        # Enter interactive mode
  $0 voice-cmd "deploy azure"     # Process single voice command

Configuration:
  Edit $CONFIG_FILE to customize settings.

Logs:
  Check $LOG_FILE for detailed logs.
EOF
}

# Main script logic
main() {
    check_prerequisites
    init_config
    
    case "${1:-help}" in
        "init")
            print_color "Configuration already initialized at: $CONFIG_FILE" "$GREEN"
            ;;
        "deploy")
            case "${2:-}" in
                "cloudflare"|"cf")
                    deploy_cloudflare
                    ;;
                "azure")
                    deploy_azure
                    ;;
                "gcloud"|"google")
                    deploy_gcloud
                    ;;
                "all"|"")
                    deploy_all
                    ;;
                *)
                    print_color "Unknown deployment target: $2" "$RED"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        "status"|"check")
            check_status
            ;;
        "voice")
            voice_mode
            ;;
        "voice-cmd")
            if [ -n "${2:-}" ]; then
                process_voice_command "$2" "${3:-}"
            else
                print_color "Please provide a voice command" "$RED"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_color "Unknown command: $1" "$RED"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"