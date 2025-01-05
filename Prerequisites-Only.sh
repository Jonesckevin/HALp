#!/bin/bash

# shellcheck disable=SC1091

create_prerequisites() {
  set_color
  echo "--------------------------------------------------------------------------------------"
  echo "                      UPDATES AND PREREQUISITES SETUP"
  echo "--------------------------------------------------------------------------------------"
  ## Set package manager based on the operating system
  ## This Option was choosen to reduce the overall footprint of the script by about 50 lines since it's practically the same script.
  if [[ -x "$(command -v apt)" ]]; then
      package_manager="apt"
      package_manager_message="             Checking OS... Ubuntu Detected. APT and such engaging..."
  elif [[ -x "$(command -v yum)" ]]; then
      package_manager="yum"
      package_manager_message="             Checking... CentOS Detected. YUM and such engaging..."
  else
      echo "Unsupported operating system. Please make sure you are running Ubuntu or CentOS."
      exit 1
  fi
  echo
  # Prompt user for prerequisites
  read -r -p "Do you want to go through the prerequisites? (y/N): " response
  if [[ $response =~ ^[Yy]$ ]]; then
    echo "Checking and implementing updates..."
    echo "-----------------------------------------------------------------------------------------"
    set_color
    echo "-----------------------------------------------------------------------------------------"
    echo
    echo "$package_manager_message"
    echo
    echo "-----------------------------------------------------------------------------------------"
    echo
    # Update and install prerequisites using the package manager
    $package_manager update -y
    $package_manager upgrade -y
    $package_manager install -y htop git curl net-tools open-vm-tools-desktop openssh-server ca-certificates gnupg lsb-release software-properties-common apt-transport-https openjdk-11-jdk

    # Remove old docker if exists
    $package_manager remove -y docker.io containerd runc docker-compose

    # Update repository with official docker
    install -m 0755 -d /etc/apt/keyrings
    if [[ $package_manager == "apt" ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    elif [[ $package_manager == "yum" ]]; then
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi

    # Update with new repository then install docker and dependencies
    $package_manager update -y
    $package_manager install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Configure docker to be used without requiring sudo
    groupadd docker
    usermod -aG docker "$SUDO_USER"
    echo "Docker group added. Please relog to update groups or run 'exec sg docker newgrp' to initialize."
    sudo systemctl set-default multi-user.target
    echo "Configuration complete"
    echo "Updates are complete. Moving forward..."
    echo "------------------------------"
    echo
  else
    echo
    echo "                                SKIPPING Prerequisites..."
    echo
  fi
}
create_prerequisites

tr -d '\r' < Setup.sh > Setup.tmp && mv Setup.tmp Setup.sh
chmod +x Setup.sh
#./Setup.sh
