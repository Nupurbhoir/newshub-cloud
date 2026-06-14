#!/bin/bash
# setup_server.sh
# Purpose: Initialize the EC2 instance with Docker, Docker Compose, and essential tools.

echo "Starting server setup..."

# 1. Update system packages
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. Install essential tools
sudo apt-get install -y curl wget git unzip

# 3. Create a dedicated user/group for deployment (Linux Admin requirement)
sudo groupadd appgroup || true
sudo useradd -m -g appgroup -s /bin/bash appuser || true

# 4. Install Docker
echo "Installing Docker..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# 5. Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 6. Add users to docker group
sudo usermod -aG docker ubuntu
sudo usermod -aG docker appuser

# 7. Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# 8. Setup backup directory
sudo mkdir -p /opt/newshub/backups
sudo chown -R appuser:appgroup /opt/newshub

echo "Server setup complete! Please log out and log back in for Docker group changes to take effect."
