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

# Function to collect user input
collect_input() {
    echo -e "${YELLOW}=== Deployment Configuration ===${NC}"
    
    read -p "Git Repository URL: " repo_url
    validate_input "$repo_url" "Git Repository URL"
    
    read -s -p "Personal Access Token: " pat
    echo
    validate_input "$pat" "Personal Access Token"
    
    read -p "Branch name [main]: " branch
    branch=${branch:-main}
    
    read -p "Remote server username [ubuntu]: " username
    username=${username:-ubuntu}
    
    read -p "Remote server IP: " server_ip
    validate_input "$server_ip" "Server IP"
    
    read -p "SSH key path: " ssh_key
    validate_input "$ssh_key" "SSH key"
    
    read -p "Application port [8080]: " app_port
    app_port=${app_port:-8080}
    
    echo ""
    echo -e "${YELLOW}=== Configuration Summary ===${NC}"
    echo "Repository: $repo_url"
    echo "Branch: $branch"
    echo "Server: $username@$server_ip"
    echo "App Port: $app_port"
    echo ""
}

# Function to test SSH connection
test_ssh() {
    log "INFO" "Testing SSH connection..."
    ssh -i "$ssh_key" -o ConnectTimeout=10 "$username@$server_ip" "echo 'SSH successful'" || {
        log "ERROR" "SSH connection failed"
        exit 1
    }
    log "SUCCESS" "SSH connection established"
}

# Function to setup remote server
setup_server() {
    log "INFO" "Setting up remote server..."
    
    ssh -i "$ssh_key" "$username@$server_ip" "
        set -e
        echo 'Updating system...'
        sudo apt update && sudo apt upgrade -y
        
        echo 'Installing Docker...'
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker \$USER
        
        echo 'Installing Docker Compose...'
        sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        echo 'Installing Nginx...'
        sudo apt install nginx -y
        
        echo 'Starting services...'
        sudo systemctl enable docker nginx
        sudo systemctl start docker nginx
        
        echo 'Server setup complete'
    " >> "$LOG_FILE" 2>&1
    
    log "SUCCESS" "Remote server setup completed"
}

# Function to clone and deploy application
deploy_app() {
    local repo_name=$(basename "$repo_url" .git)
    local auth_repo_url=$(echo "$repo_url" | sed "s|https://|https://token:${pat}@|")
    
    log "INFO" "Cloning repository..."
    
    # Clone on remote server
    ssh -i "$ssh_key" "$username@$server_ip" "
        set -e
        if [ -d \"$repo_name\" ]; then
            echo 'Repository exists, pulling updates...'
            cd \"$repo_name\"
            git pull origin \"$branch\"
        else
            git clone -b \"$branch\" \"$auth_repo_url\" \"$repo_name\"
            cd \"$repo_name\"
        fi
        
        echo 'Building and running Docker application...'
        if [ -f \"docker-compose.yml\" ]; then
            docker-compose down || true
            docker-compose up -d --build
        elif [ -f \"Dockerfile\" ]; then
            docker build -t app .
            docker stop app_container || true
            docker run -d --rm -p $app_port:$app_port --name app_container app
        else
            echo 'ERROR: No Dockerfile or docker-compose.yml found'
            exit 1
        fi
        
        echo 'Waiting for application to start...'
        sleep 10
        docker ps
    " >> "$LOG_FILE" 2>&1
    
    log "SUCCESS" "Application deployed"
}

# Function to setup Nginx reverse proxy
setup_nginx() {
    log "INFO" "Configuring Nginx reverse proxy..."
    
    ssh -i "$ssh_key" "$username@$server_ip" "
        set -e
        # Create nginx config
        sudo tee /etc/nginx/sites-available/app > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$app_port;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
    }
}
EOF
        
        # Enable site
        sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default
        
        # Test and reload
        sudo nginx -t
        sudo systemctl reload nginx
        
        echo 'Nginx configured successfully'
    " >> "$LOG_FILE" 2>&1
    
    log "SUCCESS" "Nginx reverse proxy configured"
}

# Function to validate deployment
validate_deployment() {
    log "INFO" "Validating deployment..."
    
    ssh -i "$ssh_key" "$username@$server_ip" "
        # Check if container is running
        if docker ps | grep -q app; then
            echo '✓ Container is running'
        else
            echo '✗ Container not running'
            exit 1
        fi
        
        # Test application internally
        if curl -f http://localhost:$app_port > /dev/null 2>&1; then
            echo '✓ Application responding on port $app_port'
        else
            echo '✗ Application not responding'
            exit 1
        fi
        
        # Test nginx
        if curl -f http://localhost > /dev/null 2>&1; then
            echo '✓ Nginx proxy working'
        else
            echo '✗ Nginx proxy failing'
            exit 1
        fi
    " >> "$LOG_FILE" 2>&1
    
    # Test external access
    if curl -f "http://$server_ip" --max-time 10 > /dev/null 2>&1; then
        log "SUCCESS" "External access verified"
    else
        log "WARNING" "External access failed - check firewall"
    fi
}

# Main function
main() {
    echo -e "${YELLOW}=== Auto Docker Deploy ===${NC}"
    log "INFO" "Script started"
    
    collect_input
    test_ssh
    setup_server
    deploy_app
    setup_nginx
    validate_deployment
    
    log "SUCCESS" "Deployment completed successfully!"
    echo -e "${GREEN}✓ Application deployed to: http://$server_ip${NC}"
    echo -e "${GREEN}✓ Log file: $LOG_FILE${NC}"
}

# Run main function
main "$@"
