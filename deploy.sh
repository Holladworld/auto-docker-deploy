#!/bin/bash

# ==========================================
# auto-docker-deploy - Automated Docker Deployment
# HNG DevOps Stage 1 Task
# ==========================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging setup
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] [$level]${NC} $message" | tee -a "$LOG_FILE"
}

# Function to validate input
validate_input() {
    if [[ -z "$1" ]]; then
        log "ERROR" "$2 cannot be empty"
        exit 1
    fi
}

# Function to validate Git URL
validate_git_url() {
    if [[ ! "$1" =~ ^https://.+\.git$ ]]; then
        log "ERROR" "Invalid Git URL format. Should be: https://github.com/user/repo.git"
        exit 1
    fi
}

# Function to validate IP address
validate_ip() {
    if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "ERROR" "Invalid IP address format"
        exit 1
    fi
}

# Function to validate port number
validate_port() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 65535 ]; then
        log "ERROR" "Invalid port number. Must be between 1-65535"
        exit 1
    fi
}

# Function to validate SSH key exists
validate_ssh_key() {
    if [ ! -f "$1" ]; then
        log "ERROR" "SSH key file not found: $1"
        exit 1
    fi
}

# Function to collect user input
collect_input() {
    echo -e "${YELLOW}=== Deployment Configuration ===${NC}"
    echo ""
    
    # Git Repository URL
    read -p "Git Repository URL (e.g., https://github.com/user/repo.git): " repo_url
    validate_input "$repo_url" "Git Repository URL"
    validate_git_url "$repo_url"
    
    # Personal Access Token
    read -s -p "Personal Access Token: " pat
    echo  # Add newline after hidden input
    validate_input "$pat" "Personal Access Token"
    
    # Branch name (optional)
    read -p "Branch name [main]: " branch
    branch=${branch:-main}
    
    # Server details
    read -p "Remote server username [ubuntu]: " username
    username=${username:-ubuntu}
    
    read -p "Remote server IP address: " server_ip
    validate_input "$server_ip" "Server IP address"
    validate_ip "$server_ip"
    
    read -p "SSH key path [~/.ssh/id_rsa]: " ssh_key
    ssh_key=${ssh_key:-~/.ssh/id_rsa}
    validate_ssh_key "$ssh_key"
    
    # Application port
    read -p "Application port [8080]: " app_port
    app_port=${app_port:-8080}
    validate_port "$app_port"
    
    # Display configuration summary
    echo ""
    echo -e "${YELLOW}=== Configuration Summary ===${NC}"
    echo "Repository: $(echo $repo_url | sed 's|https://||')"
    echo "Branch: $branch"
    echo "Server: $username@$server_ip"
    echo "SSH Key: $ssh_key"
    echo "App Port: $app_port"
    echo "Log File: $LOG_FILE"
    echo ""
    
    read -p "Proceed with deployment? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "Deployment cancelled by user"
        exit 0
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    log "INFO" "Testing SSH connection to $username@$server_ip..."
    
    if ssh -i "$ssh_key" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$username@$server_ip" "echo 'SSH connection successful'"; then
        log "SUCCESS" "SSH connection established"
    else
        log "ERROR" "SSH connection failed. Please check:"
        log "ERROR" "1. Server IP: $server_ip"
        log "ERROR" "2. Username: $username" 
        log "ERROR" "3. SSH key path: $ssh_key"
        log "ERROR" "4. Server firewall settings"
        exit 1
    fi
}

# Main function
main() {
    echo -e "${YELLOW}=== Auto Docker Deploy ===${NC}"
    echo -e "${YELLOW}Automated deployment script for Dockerized applications${NC}"
    echo ""
    
    log "INFO" "Script started"
    
    # Collect all user input
    collect_input
    
    # Test SSH connection
    test_ssh_connection
    
    log "SUCCESS" "Phase 1 completed - Input collected and validated"
    log "INFO" "Ready for deployment phase"
    echo -e "${GREEN}✓ Input validation completed${NC}"
    echo -e "${GREEN}✓ SSH connection tested${NC}"
    echo -e "${YELLOW}Next: Git operations and deployment${NC}"
    echo -e "${GREEN}Deployment log: $LOG_FILE${NC}"
}

# Run the script
main "$@"
