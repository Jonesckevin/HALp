#!/bin/bash

echo "Running from file: $0"
backtheup(){
    set_color && echo
    # Create cron job to backup "${DOCPATH}" folder
    echo "--------------------------------------------------------------------------------------"
    echo "                         Creating Backup Cron Job..."
    echo "--------------------------------------------------------------------------------------"
    echo "0 0 * * * tar -czvf $(pwd)/$(basename "${DOCPATH}")-backup.tar.gz -C ${DOCPATH} ." | crontab - 2>&1 &&
        log_success "Backup cron job created successfully" || log_error "Failed to create backup cron job"
    echo "Cron job created."

    # Shutdown all containers and backup the "${DOCPATH}" folder
    echo "--------------------------------------------------------------------------------------"
    echo "                         Shutting down all containers..."
    echo "--------------------------------------------------------------------------------------"
    docker stop "$(docker ps -aq)" 2>&1 &&
        log_success "All containers stopped successfully" || log_error "Failed to stop all containers"
    echo "All containers stopped."
    echo
    echo "--------------------------------------------------------------------------------------"
    # Backup the "${DOCPATH}" folder as root
    echo "--------------------------------------------------------------------------------------"
    echo "                         Backing up ""${DOCPATH}"" folder..."
    echo "--------------------------------------------------------------------------------------"
    tar -czvf "$(pwd)/zocker-data-backup.tar.gz" -C "${DOCPATH}" . 2>&1 &&
        log_success "Backup completed successfully" || log_error "Failed to complete backup"
    echo "Backup completed: $(pwd)/zocker-data-backup.tar.gz"
    echo
    echo "--------------------------------------------------------------------------------------"
    echo "                         Restarting all containers..."
    echo "--------------------------------------------------------------------------------------"
    docker start "$(docker ps -aq)" 2>&1 &&
        log_success "All containers restarted successfully" || log_error "Failed to restart all containers"
    echo "All containers restarted."
    echo
    echo "--------------------------------------------------------------------------------------"
    echo "                         Backup complete."
    echo "--------------------------------------------------------------------------------------"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "The bash source is ${BASH_SOURCE[0]}"
    sudo apt-get update
    sudo apt-get install figlet ruby
    sudo gem install lolcat
    source ./Setup.sh
    backtheup
else
    echo "Running from file: $0"
    backtheup
fi

