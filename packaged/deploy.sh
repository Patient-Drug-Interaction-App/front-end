#!/bin/bash

# Update the system
sudo dnf update -y

# Install Nginx
sudo dnf install nginx -y

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Configure firewall to allow HTTP traffic
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# Set SELinux httpd_can_network_connect to 1
sudo setsebool -P httpd_can_network_connect 1

# Remove the default Nginx configuration
sudo rm /etc/nginx/conf.d/default.conf

# Creates variable for public IP
PUBLIC_IP=$(curl -s ifconfig.me)

# Prints public IP Variable for Debugging
echo "Public IP: $PUBLIC_IP"

# Copy the Nginx configuration file for the search interface
sudo cp ./nginx/search_interface.conf /etc/nginx/conf.d/search_interface.conf

# Create the directory for the HTML file
sudo mkdir -p /usr/share/nginx/html

# Copy the HTML file to the correct location
sudo cp ./html/index.html /usr/share/nginx/html/index.html

# Copy the main Nginx configuration file
sudo cp ./nginx/nginx.conf /etc/nginx/nginx.conf

# Restart Nginx to apply changes
sudo systemctl restart nginx

echo "Deployment completed successfully!"
