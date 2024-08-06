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

#Set SELinux httpd can connect to 1
sudo setsebool -P httpd_can_network_connect 1

# Remove the default Nginx configuration
sudo rm /etc/nginx/conf.d/default.conf

# Creates variable for public IP
sudo PUBLIC_IP=$(curl -s ifconfig.me)

# Create a new Nginx configuration file
cat <<EOL | sudo tee /etc/nginx/conf.d/search_interface.conf
server {
    listen 80;
    server_name _;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    location /search {
        proxy_pass http://10.0.1.3:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Create the directory for the HTML file
sudo mkdir -p /usr/share/nginx/html

# Create the HTML file
cat <<EOL | sudo tee /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Search Interface</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }
        input[type="text"] {
            width: 300px;
            padding: 8px;
            margin-right: 10px;
        }
        button {
            padding: 8px 15px;
            cursor: pointer;
        }
        #results div {
            margin-top: 10px;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <h1>Search Interface</h1>
    <input type="text" id="searchQuery" placeholder="Enter search query">
    <button onclick="performSearch()">Search</button>
    <div id="results"></div>

    <script>
        async function performSearch() {
            const query = document.getElementById('searchQuery').value.trim();
            if (!query) {
                alert('Please enter a search query.');
                return;
            }

            try {
                const response = await fetch(\`/search?query=\${encodeURIComponent(query)}\`);
                if (!response.ok) {
                    throw new Error('Network response was not ok ' + response.statusText);
                }
                const results = await response.json();
                displayResults(results);
            } catch (error) {
                console.error('There has been a problem with your fetch operation:', error);
                document.getElementById('results').textContent = 'Error fetching results.';
            }
        }

        function displayResults(results) {
            const resultsDiv = document.getElementById('results');
            resultsDiv.innerHTML = '';

            if (Array.isArray(results) && results.length > 0) {
                results.forEach(result => {
                    const resultItem = document.createElement('div');
                    resultItem.innerHTML = formatResult(result);
                    resultsDiv.appendChild(resultItem);
                });
            } else {
                resultsDiv.textContent = 'No results found.';
            }
        }

        function formatResult(result) {
            let formatted = '';
            for (const key in result) {
                if (result.hasOwnProperty(key)) {
                    formatted += \`<strong>\${key}:</strong> \${result[key]}<br>\`;
                }
            }
            return formatted;
        }
    </script>
</body>
</html>
EOL

# Update the main Nginx configuration file
cat <<EOL | sudo tee /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log debug;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for" "\$proxy_host" "\$upstream_addr"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOL

# Restart Nginx to apply changes
sudo systemctl restart nginx

echo "Deployment completed successfully!"
