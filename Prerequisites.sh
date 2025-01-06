#!/bin/bash

source ./Setup.sh

echo "Running from file: $0"
echo
echo "--------------------------------------------------------------------------------------"
figlet -f slant -w 140 "  PREREQUISITES" | lolcat
echo "--------------------------------------------------------------------------------------"

# Set package manager based on the operating system
if [[ -x "$(command -v apt-get)" ]]; then
  package_manager="apt-get"
  package_manager_message="     Ubuntu Detected."
elif [[ -x "$(command -v yum)" ]]; then
  package_manager="yum"
  package_manager_message="     Checking... CentOS Detected."
else
  log_error "Unsupported operating system. Please make sure you are running Ubuntu or CentOS."
  exit 1
fi
echo

# Prompt user for prerequisites
read -r -p "Do you want to go through the prerequisites? (y/N): " response
if [[ $response =~ ^[Yy]$ ]]; then
  echo "Checking and implementing updates..."
  echo "-----------------------------------------------------------------------------------------"
  figlet -w 150 "$package_manager_message" | lolcat
  echo "-----------------------------------------------------------------------------------------"
  echo
  # Update and install prerequisites using the package manager
  sudo $package_manager update -y &&
    log_success "System updated successfully" || log_error "System update failed"
  sudo $package_manager upgrade -y &&
    log_success "System upgraded successfully" || log_error "System upgrade failed"
  sudo $package_manager install -y htop git curl net-tools open-vm-tools-desktop openssh-server ca-certificates gnupg lsb-release software-properties-common apt-transport-https openjdk-11-jdk &&
    log_success "Prerequisites installed successfully" || log_error "Failed to install prerequisites"

  # Remove old docker if exists
  sudo $package_manager remove -y docker.io containerd runc docker-compose &&
    log_success "Old Docker versions removed successfully" || log_error "Failed to remove old Docker versions"

  # Update repository with official docker
  install -m 0755 -d /etc/apt/keyrings
  if [[ $package_manager == "apt-get" ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
  elif [[ $package_manager == "yum" ]]; then
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi

  # Update with new repository then install docker and dependencies
  sudo $package_manager update -y &&
    log_success "Docker repository updated successfully" || log_error "Failed to update Docker repository"
  sudo $package_manager install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin &&
    log_success "Docker installed successfully" || log_error "Failed to install Docker"

  # Configure docker to be used without requiring sudo
  sudo groupadd docker
  sudo usermod -aG docker "$SUDO_USER"
  log_success "Docker group added. Please relog to update groups or run 'exec sg docker newgrp' to initialize."
  sudo systemctl set-default multi-user.target
  log_success "Configuration complete"
  log_success "Updates are complete. Moving forward..."
  echo "------------------------------"
  echo
else
  echo
  log_success "SKIPPING Prerequisites..."
  echo
fi
