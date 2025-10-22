# Auto Docker Deploy

Automated deployment script for Dockerized applications - HNG DevOps Stage 1 Task.

## Features
- Automated server setup (Docker, Docker Compose, Nginx)
- Git repository cloning with PAT authentication
- Docker application deployment
- Nginx reverse proxy configuration
- Comprehensive logging and validation

## Usage
1. Make executable: `chmod +x deploy.sh`
2. Run: `./deploy.sh`
3. Provide:
   - Git repository URL
   - Personal Access Token
   - Server details (username, IP, SSH key)
   - Application port

## Requirements
- Bash 4.0+
- SSH access to remote Ubuntu server
- Dockerized application repository

## Author
Holladworld
violahollad
