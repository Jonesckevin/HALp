#!/bin/bash

echo "Running from file: $0"
echo
echo "--------------------------------------------------------------------------------------"
figlet -f slant -w 140 "  PREREQUISITES" | lolcat
echo "--------------------------------------------------------------------------------------"

  prereq() {
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
    echo "Action Initiated: sudo apt-get update && upgrade ..."
    sudo $package_manager update -y > /dev/null &&
      log_success "System updated successfully" || log_error "System update failed"
    sudo $package_manager upgrade -y > /dev/null &&
      log_success "System upgraded successfully" || log_error "System upgrade failed"
    echo "Action Initiated: Installing multiple apt-gets..."
    sudo $package_manager install -y htop git curl net-tools open-vm-tools-desktop openssh-server ca-certificates gnupg lsb-release software-properties-common apt-transport-https openjdk-11-jdk > /dev/null &&
      log_success "Prerequisites installed successfully" || log_error "Failed to install prerequisites"

    # Remove old docker if exists
    echo "Action Initiated: Removing old Docker versions..."
    sudo $package_manager remove -y docker.io containerd runc docker-compose > /dev/null &&
      log_success "Old Docker versions removed successfully" || log_error "Failed to remove old Docker versions"

    # Update repository with official docker
    echo "Action Initiated: Adding Docker repository..."
    install -m 0755 -d /etc/apt/keyrings
    if [[ $package_manager == "apt-get" ]]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    elif [[ $package_manager == "yum" ]]; then
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi

    # Update with new repository then install docker and dependencies
    echo "Action Initiated: sudo apt-get update ..."
    sudo $package_manager update -y > /dev/null &&
      log_success "Docker repository updated successfully" || log_error "Failed to update Docker repository"
    echo "Action Initiated: Installing apt-get Docker..."
    sudo $package_manager install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null &&
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
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "The bash source is ${BASH_SOURCE[0]}"
    sudo apt-get update
    sudo apt-get install figlet ruby
    sudo gem install lolcat
    #source ./Setup.sh
    prereq
else
    echo "Running from file: $0"
    prereq
fi

