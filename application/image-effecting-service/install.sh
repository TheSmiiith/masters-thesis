# Install dependencies
echo "Installing dependencies..."
sudo apt update > /dev/null 2>&1
sudo apt install unzip > /dev/null 2>&1
sudo apt install -y python3-pip > /dev/null 2>&1
sudo pip install boto3 > /dev/null 2>&1
sudo pip install Pillow > /dev/null 2>&1
echo "Installed dependencies."

# Install AWS CLI
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" > /dev/null 2>&1
unzip awscliv2.zip > /dev/null 2>&1
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update > /dev/null 2>&1
sudo rm -r -d aws > /dev/null 2>&1
sudo rm -r -d awscliv2.zip > /dev/null 2>&1
echo "Installed AWS CLI."

# Install Cloudwatch Agent
echo "Installing Cloudwatch Agent..."
curl "https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb" -o amazon-cloudwatch-agent.deb > /dev/null 2>&1
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb > /dev/null 2>&1
sudo rm -r ./amazon-cloudwatch-agent.deb >/dev/null 2>&1
echo "Installed Cloudwatch Agent."

# Start Cloudwatch agent
sudo service awslogs start > /dev/null 2>&1

# Configure git
echo "Configuring git repository..."
git config --global credential.helper '!aws codecommit credential-helper $@' > /dev/null 2>&1
git config --global credential.UseHttpPath true > /dev/null 2>&1
echo "Configured git repository."

# Clone repository
echo "Cloning git repository..."
git clone https://git-codecommit.eu-central-1.amazonaws.com/v1/repos/MastersThesis > /dev/null 2>&1
echo "Cloned git repository."

# Create systemctl service
echo "Creating systemctl service..."
sudo bash -c 'cat << EOF > /etc/systemd/system/image-effecting-service.service
[Unit]
Description=Image Effecting Service
After=network.target

[Service]
User=ubuntu
EnvironmentFile=/etc/environment
ExecStart=/usr/bin/python3 -u /home/ubuntu/MastersThesis/application/image-effecting-service/main.py
WorkingDirectory=/home/ubuntu/MastersThesis/application/image-effecting-service
Restart=always
StandardOutput=file:/var/log/image-effecting-service.log
StandardError=file:/var/log/image-effecting-service.log

[Install]
WantedBy=multi-user.target
EOF'
echo "Created systemctl service."

# Configure Cloudwatch Agent
echo "Configuring Cloudwatch Agent..."
sudo bash -c 'cat << EOF >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
        "agent": {
                "metrics_collection_interval": 1,
                "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
        },
        "logs": {
                "logs_collected": {
                        "files": {
                                "collect_list": [
                                        {
                                                "file_path": "/var/log/image-effecting-service.log",
                                                "log_group_name": "/aws/ec2/masters-thesis/image-effecting-service",
                                                "log_stream_name": "{instance_id}",
                                                "timestamp_format": "%b %d %H:%M:%S",
                                                "timezone": "UTC"
                                        }
                                ]
                        }
                },
                "log_stream_name": "logs",
                "force_flush_interval" : 1
        }
}
EOF'
echo "Configured Cloudwatch Agent."

# Reload systemctl service
echo "Reload systemctl service..."
sudo systemctl daemon-reload > /dev/null 2>&1
sudo systemctl enable amazon-cloudwatch-agent > /dev/null 2>&1
echo "Reloaded systemctl service."