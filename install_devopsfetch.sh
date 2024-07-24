#!/bin/bash

# Function to check if a package is installed
is_installed() {
    dpkg -l | grep -qw "$1"
}

# Install dependencies if not already installed
sudo apt-get update

# Check and install Nginx
if ! is_installed nginx; then
    sudo apt install -y nginx
else
    echo "Nginx is already installed."
fi

# Check and install jq
if ! is_installed jq; then
    sudo apt install -y jq
else
    echo "jq is already installed."
fi

# Check and install Docker
if ! is_installed docker-ce; then
    sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker ${USER}
else
    echo "Docker is already installed."
fi

# Copy devopsfetch script to /usr/local/bin
sudo cp devopsfetch.sh /usr/local/bin/devopsfetch
sudo chmod +x /usr/local/bin/devopsfetch

# Create a log directory and file if not already exists
if [ ! -d /var/log/devopsfetch ]; then
    sudo mkdir -p /var/log/devopsfetch
fi
if [ ! -f /var/log/devopsfetch.log ]; then
    sudo touch /var/log/devopsfetch.log
    sudo chmod 644 /var/log/devopsfetch.log
fi

# Set up log rotation
if [ ! -f /etc/logrotate.d/devopsfetch ]; then
    cat <<EOF | sudo tee /etc/logrotate.d/devopsfetch > /dev/null
/var/log/devopsfetch.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 root adm
}
EOF
fi

# Create systemd service
if [ ! -f /etc/systemd/system/devopsfetch.service ]; then
    cat <<EOF | sudo tee /etc/systemd/system/devopsfetch.service > /dev/null
[Unit]
Description=DevOps Fetch Monitoring Service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch --monitor
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable devopsfetch.service
    sudo systemctl start devopsfetch.service
else
    echo "DevOpsFetch service is already configured."
fi

echo "Yay! Wande's DevOpsFetch tool is installed and the monitoring service is started."
