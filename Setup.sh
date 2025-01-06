#!/bin/bash

LOGFILE="./HALP_Log.log"
exec > >(tee -a "$LOGFILE") 2>&1
exec 3>&1 4>&2

log_success() {
  tput setaf 2
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >>"$LOGFILE"
  tput $counter
}

log_error() {
  tput setaf 1
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >>"$LOGFILE"
  tput $counter
}

create_docker_commands() {
  # Create executables for starting all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerstart >/dev/null
  echo "sudo docker start \$(docker ps -a --format \"{{.Names}}\" | tail -n +1)" | sudo tee -a /usr/local/bin/dockerstart >/dev/null
  sudo chmod +x /usr/local/bin/dockerstart &&
    log_success "dockerstart command created successfully" || log_error "Failed to create dockerstart command"
  # Create executables for stopping all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerstop >/dev/null
  echo "sudo docker stop \$(docker ps -a --format \"{{.Names}}\" | tail -n +1)" | sudo tee -a /usr/local/bin/dockerstop >/dev/null
  sudo chmod +x /usr/local/bin/dockerstop &&
    log_success "dockerstop command created successfully" || log_error "Failed to create dockerstop command"
  # Create executables for removing all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerrm >/dev/null
  echo "sudo docker rm \$(docker ps -a --format \"{{.Names}}\" | tail -n +1)" | sudo tee -a /usr/local/bin/dockerrm >/dev/null
  sudo chmod +x /usr/local/bin/dockerrm &&
    log_success "dockerrm command created successfully" || log_error "Failed to create dockerrm command"
  # Create executables for restarting all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerrestart >/dev/null
  echo "sudo docker restart \$(docker ps -a --format \"{{.Names}}\" | tail -n +1)" | sudo tee -a /usr/local/bin/dockerrestart >/dev/null
  sudo chmod +x /usr/local/bin/dockerrestart &&
    log_success "dockerrestart command created successfully" || log_error "Failed to create dockerrestart command"
  # Create executables for listing all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerpss >/dev/null
  printf 'sudo docker ps -a --format "table \t{{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2\n' | sudo tee -a /usr/local/bin/dockerpss >/dev/null
  sudo chmod +x /usr/local/bin/dockerpss &&
    log_success "dockerpss command created successfully" || log_error "Failed to create dockerpss command"
}

counter=2
set_color() {
  ((counter++))                         # Increment counter
  [[ $counter -gt 7 ]] && counter=1     # Reset counter
  [[ $counter -eq 4 ]] && ((counter++)) # Skip color 4 Blue (Looks bad on black bg)
  tput setaf $counter
}

install_figlet_lolcat() {
  echo "Checking for figlet and lolcat..."
  # Check if figlet and lolcat are installed
  if ! command -v figlet || ! command -v lolcat; then
    set_color && echo "Installing figlet and lolcat..."
    set_color && sudo apt-get install figlet -y
    set_color && sudo apt-get install ruby -y
    set_color && sudo gem install lolcat
  fi
}

# Docker Variables
# Declare an associative array to store variables and their values
declare -A docker_vars=(
  [HOSTIP]="$(hostname -I | awk '{print $1}')"
  [DOCPATH]="$(pwd)/zocker-data"
  [LOGINUSER]="admin"
  [ACTPASSWORD]="password"
  [DOCKERSTART]="always"
  [HALPNETWORK]="halp"
  [ALLOWEDIPS]="0.0.0.0"
  [HOMERPORT]=80
  [VAULTPORT]=1000
  [PORTAINERPORT]=1001
  [PLANKAPORT]=1002
  [BOOKSTACKPORT]=1003
  [DFIRIRISPORT]=1004
  [PAPERLESSPORT]=1005
  [OPENWEBUIPORT]=1006
  [OCRPORT]=1007
  [DRAWIOPORT]=1008
  [CYBERCHEFPORT]=1009
  [REGEX101PORT]=1010
  [ITTOOLSPORT]=1011
  [CODIMDPORT]=1012
  [ETHERPADPORT]=1013
  [N8NPORT]=1014
  [GITLABPORT]=1015
  [BBSHUFFLEPORT]=1016
  [VSCODEPORT]=1017
  [PHOTOPEAPORT]=1018
  [STEGOTOOLKITPORT]=1020
  [REMMINAPORT]=1021
)

# Export all variables
for var in "${!docker_vars[@]}"; do
  export "$var=${docker_vars[$var]}"
done

check_root_access() {
  set_color
  echo "--------------------------------------------------------------------------------------"
  figlet -f slant -w 140 "Checking Root Access" | lolcat
  echo "--------------------------------------------------------------------------------------"
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    log_error "Running as user: $(whoami)"
    exit 1
  else
    log_success "Running as user: $(whoami)"
    log_success "Moving Forward..."
    echo "Settings permissions to 777"
    sudo chmod -R 777 ./*
  fi
}

check_system_resources() {
  set_color
  echo "--------------------------------------------------------------------------------------"
  figlet -f slant -w 400 "Checking System Resources" | lolcat
  echo "                     It's recommended to have 12 Cores and 16GB RAM"
  echo -e "\e[31m Install all tools, and AI Models; it's recommended to have more than 50GB of storage\e[0m"
  echo "--------------------------------------------------------------------------------------"

  cpu_check() {
    echo "Checking CPU Cores..."
    CORES=$(nproc)
    if [[ $CORES -lt 12 ]]; then
      log_error "You have $CORES CPU Cores. It's recommended to have 12 Cores."
    else
      log_success "You have $CORES CPU Cores. Moving Forward..."
    fi
  }
  cpu_check

  mem_check() {
    echo "Checking Memory..."
    MEMORY=$(grep MemTotal /proc/meminfo | awk '{print int($2 / 1000000)}')
    if [[ $MEMORY -lt 16 ]]; then
      log_error "You have $MEMORY GB of RAM. It's recommended to have 16GB RAM."
    else
      log_success "You have $MEMORY GB of RAM. Moving Forward..."
    fi
  }
  mem_check

  echo
  read -r -p "             You have CPU Cores: $CORES, RAM: $MEMORY GB. Continue [Y/n]? " answer
  case ${answer:0:1} in n | N)
    echo
    echo "Exiting."
    exit
    ;;
  *) ;; esac
}

print_tools_to_install() {
  set_color
  echo "--------------------------------------------------------------------------------------"
  figlet "         TOOL LIST"
  echo "--------------------------------------------------------------------------------------"
  echo
  echo -e "\t\t\t\e[31mT\e[32mA\e[33mB\e[34mL\e[35mE\e[36m \e[31mO\e[32mF\e[33m \e[34mC\e[35mO\e[36mN\e[31mT\e[32mE\e[33mN\e[34mT\e[35mS\e[0m:"
  echo -e "\t\t\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[0m"
  echo -e "\t\t\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[31m-\e[32m-\e[33m-\e[34m-\e[35m-\e[36m-\e[0m"
  set_color
  echo -e "\t Homer\t\t<-  $HOMERPORT   ->\tDashboard"
  echo -e "\t Portainer\t<-  $PORTAINERPORT ->\tContainer Management"
  echo -e "\t VaultWarden\t<-  $VAULTPORT ->\tPassword Manager"
  echo -e "\t BookStack\t<-  $BOOKSTACKPORT ->\tDocumentation"
  echo -e "\t Planka\t\t<-  $PLANKAPORT ->\tTasks Kanban Board"
  echo -e "\t DFIR-IRIS\t<-  $DFIRIRISPORT ->\tDFIR Case Management"
  echo -e "\t Paperless\t<-  $PAPERLESSPORT ->\tDocument Management with OCR"
  echo -e "\t Ollama LLM\t<-  $OPENWEBUIPORT ->\tOffline LLM"
  echo -e "\t Ollama OCR\t<-  $OCRPORT ->\tOCR For Images to Text and/or Translation"
  echo -e "\t Draw.io\t<-  $DRAWIOPORT ->\tDiagramming Tool"
  echo -e "\t Photopea\t<-  $PHOTOPEAPORT ->\tOnline Photo Editor"
  echo -e "\t CyberChef\t<-  $CYBERCHEFPORT ->\tCyberChef"
  echo -e "\t Regex101\t<-  $REGEX101PORT ->\tRegex Testing"
  echo -e "\t IT Tools\t<-  $ITTOOLSPORT ->\tVarious IT Tools"
  echo -e "\t Codimd\t\t<-  $CODIMDPORT ->\tCollaborative Markdown Editor"
  echo -e "\t Etherpad\t<-  $ETHERPADPORT ->\tCollaborative Document Editing"
  echo -e "\t N8N\t\t<-  $N8NPORT ->\tWorkflow Automation"
  echo -e "\t GitLab\t\t<-  $GITLABPORT ->\tOffline and OpenSource Git"
  echo -e "\t B-B-Shuffle\t<-  $BBSHUFFLEPORT ->\tB-B-Shuffle"
  echo -e "\t VSCode\t\t<-  $VSCODEPORT ->\tVSCode"
  echo -e "\t StegoToolkit\t<-  $STEGOTOOLKITPORT ->\tStegoToolkit"
  echo -e "\t Remmina\t<-  $REMMINAPORT ->\tRemote Desktop"
  echo
}

create_prerequisites() {
  set_color
  if [[ -f ./Prerequisites.sh ]]; then
    source ./Prerequisites.sh
  else
    log_error "Prerequisites.sh not found"
  fi
}

folder_variables_check() {
  set_color && echo
  figlet -f slant -w 120 "Data Folder" | lolcat

  if [[ -d "${DOCPATH}" ]]; then
    echo "NOTE: Deleting ""${DOCPATH}"" will remove all pre-made or existing data."
    read -r -p "The folder ""${DOCPATH}"" already exists. Do you want to delete all of it? [y/N]: " remove_folder
    if [[ $remove_folder =~ ^[Yy]$ ]]; then
      echo -e "\e[31mWARNING: You are about to delete all pre-made data in ${DOCPATH}. Are you sure? [y/N]: \e[0m"
      read -r confirm_delete
      if [[ ! $confirm_delete =~ ^[Yy]$ ]]; then
        log_success "Aborting deletion."
      fi
      echo "Removing ""${DOCPATH}""..."
      sudo rm -d -r "${DOCPATH}"
      echo "Checking for ""${DOCPATH}""..."
      if [[ ! -d "${DOCPATH}" ]]; then
        log_success "Folder ""${DOCPATH}"" was removed."
        set_color && echo "Creating ""${DOCPATH}"""
        set_color && mkdir -p "${DOCPATH}"/ &&
          log_success "mkdir -p ""${DOCPATH}""/" || log_error "Failed to create ""${DOCPATH}""/"
        set_color && chmod -R 777 "${DOCPATH}"/ &&
          log_success "chmod -R 777 ""${DOCPATH}""/"
        set_color &&
          log_success "ownership of '""${DOCPATH}""' retained as 1000:1000"
        set_color && install -v -g 1000 -o 1000 -d "${DOCPATH}"/ >/dev/null 2>&1
        set_color && echo
      fi
      ls "${DOCPATH}" >/dev/null 2>&1 &&
        log_success "Folder ""${DOCPATH}"" exists." || log_error "Folder ""${DOCPATH}"" does not exist."
    fi
  fi
}

dashboard_SED() {
  echo "--------------------------------------------------------------------------------------"
  echo "                         Editing Dashboard Configuration Files..."
  echo "--------------------------------------------------------------------------------------"
  echo "                 Fixing in the Homer Config via SED..."
  sed -i "s/\$HOSTIP/$HOSTIP/g; s/\$HOMERPORT/$HOMERPORT/g; s/\$VAULTPORT/$VAULTPORT/g; s/\$PORTAINERPORT/$PORTAINERPORT/g; s/\$PLANKAPORT/$PLANKAPORT/g; s/\$BOOKSTACKPORT/$BOOKSTACKPORT/g; s/\$PAPERLESSPORT/$PAPERLESSPORT/g; s/\$OPENWEBUIPORT/$OPENWEBUIPORT/g; s/\$OCRPORT/$OCRPORT/g; s/\$DRAWIOPORT/$DRAWIOPORT/g; s/\$CYBERCHEFPORT/$CYBERCHEFPORT/g; s/\$REGEX101PORT/$REGEX101PORT/g; s/\$ITTOOLSPORT/$ITTOOLSPORT/g; s/\$CODIMDPORT/$CODIMDPORT/g; s/\$ETHERPADPORT/$ETHERPADPORT/g; s/\$GITLABPORT/$GITLABPORT/g; s/\$N8NPORT/$N8NPORT/g; s/\$DFIRIRISPORT/$DFIRIRISPORT/g; s/\$BBSHUFFLEPORT/$BBSHUFFLEPORT/g; s/\$VSCODEPORT/$VSCODEPORT/g; s/\$PHOTOPEAPORT/$PHOTOPEAPORT/g; s/\$STEGOTOOLKITPORT/$STEGOTOOLKITPORT/g; s/\$REMMINAPORT/$REMMINAPORT/g" "${DOCPATH}"/homer/config.yml &&
    log_success "Homer config updated successfully" || log_error "Failed to update Homer config"

  ## Dashboard-icons is a git repo that contains a lot of icons for the dashboard
  #  git clone https://github.com/walkxcode/dashboard-icons.git
  #  mkdir -p "${DOCPATH}"/homer/tools/
  #  cp -r dashboard-icons/png/* "${DOCPATH}"/homer/tools/
}

network_creation() {
  set_color && echo
  echo "--------------------------------------------------------------------------------------"
  figlet "   Docker Network" | lolcat
  echo "--------------------------------------------------------------------------------------"
  docker network create "${HALPNETWORK}" &&
    log_success "Network ${HALPNETWORK} created successfully" || log_error "Failed to create network ${HALPNETWORK}"
  docker network create "${HALPNETWORK}_DB" &&
    log_success "Network ${HALPNETWORK}_DB created successfully" || log_error "Failed to create network ${HALPNETWORK}_DB"
}

create_dockers() {
  set_color && echo
  echo "--------------------------------------------------------------------------------------"
  echo "                         Creating Docker Containers..."
  echo "--------------------------------------------------------------------------------------"
  if [[ -f ./Docker-Runs.sh ]]; then
    source ./Docker-Runs.sh
  else
    log_error "Docker-Runs.sh not found"
  fi
}

install_backup() {
  set_color && echo
  if [[ -f ./Backup.sh ]]; then
    source ./Backup.sh
  else
    log_error "Backup.sh not found"
  fi
}

fn_summary_cleanup() {
  # Helps Load pages faster for file editing
  curl --max-time 10 http://"$HOSTIP":"$HOMERPORT" >/dev/null 2>&1

  set_color && echo
  echo "-------------------------------------------------------------------------------------------------------------------------"
  echo
  echo "Currently your Docker containers ID are numbers and are as follows:"
  echo -e '               docker ps --format \"table \\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\" | sort -k 2'
  echo "                                      OR " dockerpss ""
  echo "-------------------------------------------------------------------------------------------------------------------------"
  counter=5 && tput setaf $counter

  echo "  IP TO NAVIGATE:  $HOSTIP"
  echo "  DASHBOARD PORT:     $HOMERPORT"
  echo "                               ------------------------------------------------"
  echo "                                   I hope you enjoy your new Docker setup!"
  echo "                               ------------------------------------------------"
  echo
  counter=7
  tput setaf $counter
}

default_logins_summary() {
  set_color && echo
  echo -e "                     VISIT $HOSTIP:$HOMERPORT TO ACCESS HOMER"
  echo -e "          --------------------------------------------------------------------"
  echo -e "--------------------------------------------------------------------------------------"
  echo -e "                             Service Access Information"
  echo -e "--------------------------------------------------------------------------------------"
  echo -e " Service        | URL                       | Username                                                    | Password"
  echo -e "----------------|---------------------------|-------------------------------------------------------------|----------------------------------"
  echo -e " Homer          | $HOSTIP:$HOMERPORT         | Visit URL                                                   | N/A"
  echo -e " Portainer      | $HOSTIP:$PORTAINERPORT       | <You can create your own>                                   | <You can create your own>"
  echo -e " VaultWarden    | $HOSTIP:$VAULTPORT       | User - Signup to Create your own account                    | <You can create your own>"
  echo -e " VaultWarden    | $HOSTIP:$VAULTPORT/admin | N/A                                                         | Manually set Argon2id: 'password'"
  echo -e " BookStack      | $HOSTIP:$BOOKSTACKPORT       | admin@admin.com                                             | ${ACTPASSWORD}"
  echo -e " Planka         | $HOSTIP:$PLANKAPORT       | admin@planka.local                                          | ${ACTPASSWORD}"
  echo -e " DFIR-IRIS      | $HOSTIP:$DFIRIRISPORT       | ${LOGINUSER}                                                       | ${ACTPASSWORD}"
  echo -e " Paperless      | $HOSTIP:$PAPERLESSPORT       | docker exec -it Paperless-NGX \"./manage.py createsuperuser\" | <You can create your own>"
  echo -e " GitLab         | $HOSTIP:$GITLABPORT       | root                                                        | docker exec -it GitLab gitlab-rake \"gitlab:password:reset[root]\""
  echo -e " N8N            | $HOSTIP:$N8NPORT       | ${LOGINUSER}                                                       | ${ACTPASSWORD}"
  echo -e " Etherpad       | $HOSTIP:$ETHERPADPORT       | N/A                                                         | N/A"
  echo -e " Codimd         | $HOSTIP:$CODIMDPORT       | N/A                                                         | N/A"
  echo -e " Draw.io        | $HOSTIP:$DRAWIOPORT       | N/A                                                         | N/A"
  echo -e " CyberChef      | $HOSTIP:$CYBERCHEFPORT       | N/A                                                         | N/A"
  echo -e " Photopea       | $HOSTIP:$PHOTOPEAPORT       | N/A                                                         | N/A"
  echo -e " Regex101       | $HOSTIP:$REGEX101PORT       | N/A                                                         | N/A"
  echo -e " IT Tools       | $HOSTIP:$ITTOOLSPORT       | N/A                                                         | N/A"
  echo -e " OpenWebUI Admin| $HOSTIP:$OPENWEBUIPORT       | <You can create your own> (First one gets admin)            | <You can create your own>"
  echo -e " OpenWebUI      | $HOSTIP:$OPENWEBUIPORT       | <You can create your own>                                   | <You can create your own>"
  echo -e " Ollama-OCR     | $HOSTIP:$OCRPORT       | N/A                                                         | N/A"
  echo -e " B-B-Shuffle    | $HOSTIP:$BBSHUFFLEPORT       | N/A                                                         | N/A"
  echo -e " VSCode         | $HOSTIP:$VSCODEPORT       | N/A                                                         | ${ACTPASSWORD}"
  echo -e " Stego-Toolkit  | N/A                      | N/A                                                         | N/A"
  echo -e " Remmina        | $HOSTIP:$REMMINAPORT       | N/A                                                         | N/A"
  echo -e "------------------------------------------------------------------------------------------"
}

postcreation_changes() {
  echo && set_color
  if [[ -f ./Post_Setup.sh ]]; then
    chmod +x ./Post_Setup.sh
    ./Post_Setup.sh
  else
    log_error "Post_Setup.sh not found"
  fi
}

install_complete() {
  set_color && echo
  echo "--------------------------------------------------------------------------------------"
  echo "                             Installation Complete"
  echo "--------------------------------------------------------------------------------------"
  echo " Setting up Permissions...to be full 777 - Very Insecure, but this should be a closed system"
  sudo chmod -R 777 "${DOCPATH}"
  echo " Permissions set to $DOCPATH 777"
  echo "--------------------------------------------------------------------------------------"
  echo " Insert Profit Here"
  echo "--------------------------------------------------------------------------------------"
  echo
  dockerpss
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "The bash source is ${BASH_SOURCE[0]}"
  install_figlet_lolcat
  figlet -f slant -w 140 "               HALp" | lolcat
  
  create_docker_commands
  check_root_access      ## CHECKING FOR ROOT ACCESS...
  check_system_resources ## CHECKING SYSTEM RESOURCES

  print_tools_to_install ## TOOLS TO BE INSTALLED
  create_prerequisites   ## UPDATES AND PREREQUISITES SETUP
  folder_variables_check ## Data Folder Creation
  network_creation       ## Creating Network...

  dashboard_SED ## Replaces IP and Ports in Homer Config

  create_dockers
  create_portainer     ## Creating Portainer...
  create_homer         ## Installing Dashboard...
  create_vaultwarden   ## Installing Vaultwarden...
  create_dfir_iris     ## Installing DFIR-IRIS...
  create_bookstack     ## Installing Wiki...
  create_planka        ## Installing KanBan...
  create_paperless     ## Installing Paperless...
  create_llm_gpu_cuda  ## Installing Ollama with GPU and CUDA...
  create_ocr           ## Installing Ollama-OCR...
  create_ittools       ## Installing IT Tools...
  create_codimd        ## Installing Codimd...
  create_n8n           ## Installing N8N...
  create_gitlab        ## Installing GitLab...
  create_drawio        ## Installing Drawio...
  create_cyberchef     ## Installing CyberChef...
  create_photopea      ## Installing Photopea...
  create_remmina       ## Installing Remmina...
  create_regex101      ## Installing Regex101...
  create_etherpad      ## Installing Etherpad...
  create_b_b_shuffle   ## Installing B-B-Shuffle...
  create_vscode        ## Installing VSCode...
  create_stego-toolkit ## Installing Stego-Toolkit...
  create_sift_remnux   ## Installing SIFT-REMnux...

  postcreation_changes ## Post Creation Changes such as replace images or change colors

  fn_summary_cleanup ## SUMMARY of Installation for user to see

  default_logins_summary ## VISIT $HOSTIP:$HOMERPORT TO ACCESS HOMER

  #install_backup           ## Creating Backup Cron Job and Running Backup

fi
