#!/bin/bash

# Check if the script is being run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or using sudo."
  exit 1
fi

# Function to install Node.js using NodeSource repository
install_nodejs() {
  # Download the NodeSource installation script
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

  # Update the package lists again after adding the repository
  apt update

  # Install Node.js and npm
  apt install -y nodejs

  # Verify installation
  node --version
  npm --version
}

# Function to add the PPA repository for PHP
add_php_repository() {
  # Install software-properties-common if not already installed
  apt install -y software-properties-common

  # Add the PPA repository for PHP
  add-apt-repository -y ppa:ondrej/php

  # Update the package lists after adding the repository
  apt update
}

# Function to configure the firewall
configure_firewall() {
  # Install ufw (Uncomplicated Firewall) if not already installed
  apt install -y ufw

  # Enable firewall
  yes | ufw enable

  # Allow OpenSSH (SSH) connections
  ufw allow OpenSSH

  # Allow HTTP and HTTPS traffic
  ufw allow 'Nginx Full'
  # Replace 'Nginx Full' with 'Apache Full' if using Apache as the web server

  # Enable ufw logging (optional)
  ufw logging on
}

# Function to download, extract, and move PHPMyAdmin to the proper location
install_phpmyadmin() {
  # Download PHPMyAdmin (adjust the version as needed)
  PHPMYADMIN_VERSION="5.1.1"
  curl -fsSL -o phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz

  # Extract the archive
  tar -xzf phpmyadmin.tar.gz

  # Move PHPMyAdmin to the web server's document root (e.g., /var/www/html)
  mv phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages /usr/share/nginx/html/phpmyadmin

  # Set the proper permissions
  chown -R www-data:www-data /usr/share/nginx/html/phpmyadmin

  # Clean up the downloaded archive
  rm phpmyadmin.tar.gz
}

# Function to move a file from source to destination
move_file() {
  source_file="config.json"
  destination="/etc/nginx/sites-enabled/"

  if [ ! -f "$source_file" ]; then
    echo "Error: Source file '$source_file' not found or not a regular file."
    exit 1
  fi

  if [ -f "$destination" ]; then
    echo "Warning: Destination file '$destination' already exists. Overwriting..."
  fi

  mv "$source_file" "$destination"
  if [ $? -eq 0 ]; then
    echo "Successfully moved '$source_file' to '$destination'."
  else
    echo "Error moving '$source_file' to '$destination'."
    exit 1
  fi
}

# List of software to install
software_list=(
  mysql-server
  redis-server
  curl
  nginx
  php8.2
  php8.2-cli php8.2-common php8.2-mysql php8.2-zip php8.2-gd php8.2-mbstring php8.2-curl php8.2-xml php8.2-bcmath
  php8.2-fpm
  libreoffice libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw libreoffice-math libreoffice-base

  # Add more packages here as needed
)

# Step 1: Install Node.js using NodeSource
install_nodejs

# Step 2: Add the PPA repository for PHP
add_php_repository

# Step 3: Update the package lists
apt update

# Step 4: Install the software packages
for package in "${software_list[@]}"; do
  # Check if the package is already installed
  if dpkg -s "$package" &> /dev/null; then
    echo "$package is already installed. Skipping..."
  else
    # Install the package
    apt install -y "$package"
    if [ $? -eq 0 ]; then
      echo "Successfully installed $package."
    else
      echo "Error installing $package. Exiting..."
      exit 1
    fi
  fi
done

# Step 5: Configure the firewall
configure_firewall

# Step 6: Download, extract, and move PHPMyAdmin
install_phpmyadmin

# Step 7: Move the file (Use $1 and $2 to represent source file and destination folder)
# (Replace /path/to/source_file.txt and /path/to/destination_folder/ with actual paths)
move_file "$1" "$2"

# Step 8: Stop the Apache2 service (if installed)
if systemctl is-active --quiet apache2; then
  systemctl stop apache2
  echo "Apache2 service stopped."
fi

# Step 9: Delete the default Nginx site configuration (if it exists)
default_nginx_config="/etc/nginx/sites-enabled/default"
if [ -f "$default_nginx_config" ]; then
  rm "$default_nginx_config"
  echo "Deleted the default Nginx site configuration."
fi

# Step 10: Set the MySQL root password and disable password policy
# Replace 'your_default_password_here' with your desired MySQL root password
DEFAULT_MYSQL_ROOT_PASSWORD="password"

# Set the MySQL root password using the default password
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DEFAULT_MYSQL_ROOT_PASSWORD';"

# Set the MySQL password policy to 0 (LOW)
echo "SET GLOBAL validate_password.policy=0;"

# Step 11: Restart the Nginx service
systemctl restart nginx
echo "Nginx service restarted."

echo "Software installation, PHP repository added, PHPMyAdmin installation, file moved, firewall configuration, MySQL root password set, and MySQL password policy set completed."
