#!/bin/bash

# Exit on any error
set -e

echo "=== Starting Calculator Application Deployment ==="

# Update and install necessary packages
echo "=== Updating system and installing packages ==="
sudo apt-get update
sudo apt-get upgrade -y
sudo apt install -y python3 python3-pip python3-venv nginx git

# Set up application directory
echo "=== Setting up application directory ==="
cd /var/www/html

# Check if directory already exists
if [ -d "/var/www/html/calculator" ]; then
    echo "Calculator directory already exists, updating..."
    cd calculator
    sudo git pull
    cd src
else
    echo "Cloning calculator repository..."
    sudo git clone https://github.com/maxoba/calculator.git
    cd calculator/src
fi

# Set permissions for the application directory
sudo chown -R ubuntu:ubuntu /var/www/html/calculator/

# Set up Python virtual environment
echo "=== Setting up Python virtual environment ==="
python3 -m venv jop
source jop/bin/activate

# Install Python dependencies
echo "=== Installing Python dependencies ==="
pip install --upgrade pip
pip install --upgrade gunicorn

# Install requirements if file exists
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    echo "No requirements.txt found, installing Flask manually"
fi

# Install Flask (ensure it's available)
pip install flask

# Create Flask app (backup - only if not already present)
if [ ! -f app.py ]; then
    echo "=== Creating Flask application file ==="
    cat > app.py << 'EOL'
# -*- coding: utf-8 -*-
"""
    Calculator
    ~~~~~~~~~~~~~~

    A simple Calculator made by Flask and jQuery.

    :copyright: (c) 2015 by Grey li.
    :license: MIT, see LICENSE for more details.
"""
import re
from flask import Flask, jsonify, render_template, request


app = Flask(__name__)


@app.route('/_calculate')
def calculate():
    a = request.args.get('number1', '0')
    operator = request.args.get('operator', '+')
    b = request.args.get('number2', '0')
    # validate the input data
    m = re.match(r'^\-?\d*[.]?\d*$', a)
    n = re.match(r'^\-?\d*[.]?\d*$', b)

    if m is None or n is None or operator not in '+-*/':
        return jsonify(result='Error!')

    if operator == '/':
        if float(b) == 0:
            return jsonify(result='Error!')
        result = float(a) / float(b)
    elif operator == '*':
        result = float(a) * float(b)
    elif operator == '+':
        result = float(a) + float(b)
    elif operator == '-':
        result = float(a) - float(b)
    
    return jsonify(result=result)


@app.route('/')
def index():
    return render_template('index.html')


if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")
EOL
else
    echo "app.py already exists, skipping creation"
fi

# Create wsgi.py (ensure it exists with correct syntax)
echo "=== Creating WSGI configuration ==="
cat > wsgi.py << 'EOL'
from app import app

if __name__ == "__main__":
    app.run()
EOL

# Create a Gunicorn systemd service file
echo "=== Creating systemd service ==="
sudo tee /etc/systemd/system/calculator.service > /dev/null << 'EOL'
[Unit]
Description=Gunicorn instance to serve calculator
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/var/www/html/calculator/src
Environment="PATH=/var/www/html/calculator/src/jop/bin"
ExecStart=/var/www/html/calculator/src/jop/bin/gunicorn --bind 0.0.0.0:5000 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Start and enable the Gunicorn service
echo "=== Starting calculator service ==="
sudo systemctl daemon-reload
sudo systemctl start calculator
sudo systemctl enable calculator

# Create nginx configuration
echo "=== Configuring Nginx ==="
sudo tee /etc/nginx/sites-available/calculator > /dev/null << 'EOL'
server {
    listen 80;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:5000;
    }
}
EOL

# Enable the Nginx configuration
sudo ln -sf /etc/nginx/sites-available/calculator /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "=== Testing Nginx configuration ==="
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Print status of services
echo ""
echo "=== DEPLOYMENT STATUS ==="
echo "========================="
echo ""

echo "=== Calculator Service Status ==="
sudo systemctl status calculator --no-pager -l

echo ""
echo "=== Nginx Service Status ==="
sudo systemctl status nginx --no-pager -l

# Check if services are listening on correct ports
echo ""
echo "=== Port Status ==="
echo "Checking port 5000 (Gunicorn):"
sudo ss -tlnp | grep :5000 || echo "Port 5000 not listening"

echo "Checking port 80 (Nginx):"
sudo ss -tlnp | grep :80 || echo "Port 80 not listening"

# Show recent logs
echo ""
echo "=== Recent Calculator Service Logs ==="
sudo journalctl -u calculator --no-pager -n 10

# Test the application
echo ""
echo "=== Testing Application ==="
echo "Testing Flask app directly on port 5000..."
curl -s localhost:5000 > /dev/null && echo "✅ Flask app responding" || echo "❌ Flask app not responding"

echo "Testing through Nginx on port 80..."
curl -s localhost > /dev/null && echo "✅ Nginx proxy working" || echo "❌ Nginx proxy not working"

# Get public IP and show final message
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to determine public IP")

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo "=========================="
echo ""
echo "🎉 Calculator application deployed successfully!"
echo ""
echo "Access your calculator at:"
echo "  http://$PUBLIC_IP"
echo ""
echo "Local testing URLs:"
echo "  Direct Flask: http://localhost:5000"
echo "  Through Nginx: http://localhost"
echo ""
echo "Service management commands:"
echo "  sudo systemctl status calculator"
echo "  sudo systemctl restart calculator"
echo "  sudo systemctl status nginx"
echo "  sudo systemctl restart nginx"
echo ""
echo "Log monitoring:"
echo "  sudo journalctl -u calculator -f"
echo "  sudo tail -f /var/log/nginx/error.log"