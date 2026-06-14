#!/bin/bash
# deploy_app.sh
# Purpose: Deploy the containerized application.

APP_DIR="/home/ubuntu/newshub"

echo "Deploying NewsHub Application..."

# Normally you would git clone here, but assuming files are already uploaded via SCP or Git:
# sudo git clone https://github.com/your-repo/newshub.git $APP_DIR

# Navigate to app directory
cd $APP_DIR || exit 1

# Bring down existing containers
docker-compose down

# Build and start new containers
docker-compose up --build -d

echo "Application deployed successfully. View it at http://<your-ec2-public-ip>:3000"
