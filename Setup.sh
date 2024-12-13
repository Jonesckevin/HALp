#!/bin/bash

# shellcheck disable=SC1091

create_docker_commands() {
  # Create executables for starting all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerstart
  echo "sudo docker start \$(docker ps -a --format \"{{.Names}}\" | tail -n +2)" | sudo tee -a /usr/local/bin/dockerstart
  sudo chmod +x /usr/local/bin/dockerstart
  # Create executables for stopping all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerstop
  echo "sudo docker stop \$(docker ps -a --format \"{{.Names}}\" | tail -n +2)" | sudo tee -a /usr/local/bin/dockerstop
  sudo chmod +x /usr/local/bin/dockerstop
  # Create executables for removing all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerrm
  echo "sudo docker rm \$(docker ps -a --format \"{{.Names}}\" | tail -n +2)" | sudo tee -a /usr/local/bin/dockerrm
  sudo chmod +x /usr/local/bin/dockerrm
  # Create executables for restarting all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerrestart
  echo "sudo docker restart \$(docker ps -a --format \"{{.Names}}\" | tail -n +2)" | sudo tee -a /usr/local/bin/dockerrestart
  sudo chmod +x /usr/local/bin/dockerrestart
  # Create executables for listing all Docker containers
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockerpss
  printf 'sudo docker ps -a --format "table \t{{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2\n' | sudo tee -a /usr/local/bin/dockerpss
  sudo chmod +x /usr/local/bin/dockerpss
}
create_docker_commands

counter=2
set_color() {
    ((counter++))                          # Increment counter
    [[ $counter -gt 7 ]] && counter=1      # Reset counter
    [[ $counter -eq 4 ]] && ((counter++))  # Skip color 4 Blue (Looks bad on black bg)
    tput setaf $counter
}

# Banner: https://www.patorjk.com/software/taag/
echo
echo -e "\t\t __  __  ______  __                "
echo -e "\t\t/\ \/\ \/\  _  \/\ \               "
echo -e "\t\t\ \ \_\ \ \ \L\ \ \ \      _____   "
echo -e "\t\t \ \  _  \ \  __ \ \ \    /\ '__\`\\ "
echo -e "\t\t  \\ \\ \\ \\ \\ \\ \\/\\ \\ \\ \\__ \\ \\ \\L\\ \\"
echo -e "\t\t   \\ \\_\\ \\_\\ \\_\\ \\_\\ \\___\\ \\\\ \\ ,__/"
echo -e "\t\t    \\/_/\\/_/\\/_/\\/_/\\/___/  \\ \\ \\/ "
echo -e "\t\t                             \\ \\_\\ "
echo -e "\t\t                              \\/_/ "
echo
echo

chmod -R 777 ./*

# Variables
HOSTIP=$(hostname -I | awk '{print $1}')
LOGINUSER="admin"
ACTPASSWORD="password"
DOCKERSTART=always
HALPNETWORK="halp"
DOCPATH=$(pwd)/zocker-data
ALLOWEDIPS="0.0.0.0"

## Ports
HOMERPORT=80            # Homer
VAULTPORT=1000          # Vaultwarden
PORTAINERPORT=1001      # Portainer
PLANKAPORT=1002         # Planka
BOOKSTACKPORT=1003      # BookStack
DFIRIRISPORT=1004       # DFIR-IRIS
PAPERLESSPORT=1005      # Paperless
OLLAMAPORT=1006         # Ollama LLM
OCRPORT=1007            # Ollama OCR
DRAWIOPORT=1008         # Draw.io
CYBERCHEFPORT=1009      # CyberChef
REGEX101PORT=1010       # Regex101
ITTOOLSPORT=1011        # IT Tools
CODIMDPORT=1012         # Codimd
ETHERPADPORT=1013       # Etherpad
N8NPORT=1014            # N8N
GITLABPORT=1015         # GitLab
BBSHUFFLEPORT=1016      # B-B-Shuffle
VSCODEPORT=1017         # VSCode
PHOTOPEAPORT=1018       # Photopea
#FITCRACKPORT=1019       # Fitcrack
STEGOTOOLKITPORT=1020   # StegoToolkit
REMMINAPORT=1021        # Remmina

check_root_access() {
  set_color
  echo
  echo "--------------------------------------------------------------------------------------"
  echo "                          CHECKING FOR ROOT ACCESS..."
  echo "--------------------------------------------------------------------------------------"
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    echo "Running as user: $(whoami)"
    exit 1
  else
    echo "Running as user: $(whoami)"
    echo "Moving Forward..."
  fi
}

check_system_resources() {
  set_color
  echo "--------------------------------------------------------------------------------------"
  echo "                              CHECKING SYSTEM RESOURCES"
  echo "                     It's recommended to have 12 Cores and 16GB RAM"
  echo -e "\e[31m Install all tools, and AI Models; it's recommended to have more than 50GB of storage\e[0m"
  echo "--------------------------------------------------------------------------------------"
  
  cpu_check () {
    echo "Checking CPU Cores..."
    CORES=$(nproc)
    if [[ $CORES -lt 12 ]]; then
      echo -e "    You have \e[31m$CORES CPU Cores\e[0m. It's recommended to have 8+ Cores."
    else
      echo -e "    You have \e[31m$CORES CPU Cores\e[0m. Moving Forward..."
    fi
  }
  cpu_check

  mem_check () {
    echo "Checking Memory..."
    MEMORY=$(grep MemTotal /proc/meminfo | awk '{print int($2 / 10000)}')
    if [[ $MEMORY -lt 1600 ]]; then
      echo -e "    You have \e[31m$MEMORY MB of RAM\e[0m. It's recommended to have 16GB RAM."
    else
      echo -e "    You have \e[31m$MEMORY MB of RAM\e[0m. Moving Forward..."
    fi
  }
  mem_check
  
  echo
  read -r -p "             You have CPU Cores: $CORES, RAM: $MEMORY MB. Continue [Y/n]? " answer
  case ${answer:0:1} in n|N ) echo; echo "Exiting."; exit ;; * ) ;; esac
}

print_tools_to_install() {
  set_color
  echo "--------------------------------------------------------------------------------------"
  echo "                          TOOLS TO BE INSTALLED"
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
  echo -e "\t Ollama LLM\t<-  $OLLAMAPORT ->\tOffline LLM"
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

}
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

folder_variables_check() {
  set_color && echo
  echo "--------------------------------------------------------------------------------------"
  echo "                                 Data Folder Creation &&"
  echo "                 (OPTIONAL)            VARIABLES"
  echo "--------------------------------------------------------------------------------------"

  if [[ -d "${DOCPATH}" ]]; then
    read -r -p "The folder ""${DOCPATH}"" already exists. Do you want to delete all of it? [y/N]: " remove_folder
    if [[ $remove_folder =~ ^[Yy]$ ]]; then
      echo -e "\e[31mWARNING: You are about to delete all pre-made data in ${DOCPATH}. Are you sure? [y/N]: \e[0m"
      read -r confirm_delete
      if [[ ! $confirm_delete =~ ^[Yy]$ ]]; then
        echo "Aborting deletion."
      fi
      echo "Removing ""${DOCPATH}""..."
      rm -d -r "${DOCPATH}"
      echo "Checking for ""${DOCPATH}""..."
      if [[ ! -d "${DOCPATH}" ]]; then
        echo "Folder ""${DOCPATH}"" was removed."
          set_color && echo "Creating ""${DOCPATH}"""
          set_color && mkdir -p "${DOCPATH}"/ && echo "mkdir -p ""${DOCPATH}""/" || echo "Failed to create ""${DOCPATH}""/"
          set_color && chmod -R 777 "${DOCPATH}"/ && echo "chmod -R 777 ""${DOCPATH}""/"
          set_color && echo "ownership of '""${DOCPATH}""' retained as 1000:1000"
          set_color && install -v -g 1000 -o 1000 -d "${DOCPATH}"/ > /dev/null 2>&1
          set_color && echo
      fi
      ls "${DOCPATH}" > /dev/null 2>&1 && echo "Folder ""${DOCPATH}"" exists." || echo "Folder ""${DOCPATH}"" does not exist."
    fi
  fi
}

dashboard_SED() {
  echo "--------------------------------------------------------------------------------------"
  echo "                         Editing Dashboard Configuration Files..."
  echo "--------------------------------------------------------------------------------------"
  echo "                 Fixing in the Homer Config via SED..."
  sed -i "s/\$HOSTIP/$HOSTIP/g; s/\$HOMERPORT/$HOMERPORT/g; s/\$VAULTPORT/$VAULTPORT/g; s/\$PORTAINERPORT/$PORTAINERPORT/g; s/\$PLANKAPORT/$PLANKAPORT/g; s/\$BOOKSTACKPORT/$BOOKSTACKPORT/g; s/\$PAPERLESSPORT/$PAPERLESSPORT/g; s/\$OLLAMAPORT/$OLLAMAPORT/g; s/\$OCRPORT/$OCRPORT/g; s/\$DRAWIOPORT/$DRAWIOPORT/g; s/\$CYBERCHEFPORT/$CYBERCHEFPORT/g; s/\$REGEX101PORT/$REGEX101PORT/g; s/\$ITTOOLSPORT/$ITTOOLSPORT/g; s/\$CODIMDPORT/$CODIMDPORT/g; s/\$ETHERPADPORT/$ETHERPADPORT/g; s/\$GITLABPORT/$GITLABPORT/g; s/\$N8NPORT/$N8NPORT/g; s/\$DFIRIRISPORT/$DFIRIRISPORT/g; s/\$BBSHUFFLEPORT/$BBSHUFFLEPORT/g; s/\$VSCODEPORT/$VSCODEPORT/g; s/\$PHOTOPEAPORT/$PHOTOPEAPORT/g; s/\$STEGOTOOLKITPORT/$STEGOTOOLKITPORT/g; s/\$REMMINAPORT/$REMMINAPORT/g" "${DOCPATH}"/homer/config.yml

## Dashboard-icons is a git repo that contains a lot of icons for the dashboard
#  git clone https://github.com/walkxcode/dashboard-icons.git
#  mkdir -p "${DOCPATH}"/homer/tools/
#  cp -r dashboard-icons/png/* "${DOCPATH}"/homer/tools/
}

network_creation() {
  set_color && echo
  echo "--------------------------------------------------------------------------------------"
  echo "                         Creating Network..."
  echo "--------------------------------------------------------------------------------------"
  docker network create "${HALPNETWORK}"
  docker network create "${HALPNETWORK}_DB"
}

set_color && echo
  echo "--------------------------------------------------------------------------------------"
  echo "                  Pulling / Creating Docker Containers for Databases..."
  echo "--------------------------------------------------------------------------------------"

create_bookstack() {
  set_color && echo
  echo -e "\t\tCreating MySQL - BookStack-DB"
  docker run -d --name BookStack-DB --hostname bookstack-db --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -e PUID=1000 -e PGID=1000 -e MYSQL_ROOT_PASSWORD=bookstackrootpassword -e TZ=America/Toronto -v "${DOCPATH}"/bookstack/db_data:/config -e MYSQL_DATABASE=bookstackapp -e MYSQL_USER=bookstack -e MYSQL_PASSWORD=bookstackpassword lscr.io/linuxserver/mariadb  #  > /dev/null 2>&1

  echo
  echo -e "\t\tCreating Bookstack"
  docker run -d --name BookStack --hostname bookstack --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$BOOKSTACKPORT:80 -v "${DOCPATH}"/bookstack/app_data:/config -v "${DOCPATH}"/bookstack/public:/var/www/bookstack/public:rw -e PUID=1000 -e PGID=1000 -e DB_PORT=3306 -e DB_HOST=BookStack-DB -e APP_URL=http://"$HOSTIP":$BOOKSTACKPORT -e DB_USER=bookstack -e DB_PASS=bookstackpassword -e DB_DATABASE=bookstackapp lscr.io/linuxserver/bookstack:24.05.4  #  > /dev/null 2>&1
}
 
create_planka() {
  set_color && echo
  echo -e "\t\tCreating PostGres - Planka-DB"
  docker run -d --name Planka-DB --hostname planka-db --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -v "${DOCPATH}"/planka/db-data:/var/lib/postgresql/data:rw -e POSTGRES_DB=planka -e POSTGRES_HOST_AUTH_METHOD=trust postgres:14-alpine 

  echo
  echo -e "\t\tCreating Planka"
  docker run -d --name Planka --hostname planka --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$PLANKAPORT:1337 -e BASE_URL=http://"$HOSTIP":$PLANKAPORT -e DATABASE_URL=postgresql://postgres@Planka-DB/planka -e SECRET_KEY=secretofkeys -e DEFAULT_ADMIN_EMAIL=${LOGINUSER}@planka.local -e DEFAULT_ADMIN_PASSWORD=${ACTPASSWORD} -e DEFAULT_ADMIN_NAME=Admin -e DEFAULT_ADMIN_USERNAME=admin -v "${DOCPATH}"/planka/user-avatars:/app/public/user-avatars -v "${DOCPATH}"/planka/project-background-images:/app/public/project-background-images -v "${DOCPATH}"/planka/attachments:/app/private/attachments ghcr.io/plankanban/planka:latest
}

create_portainer() {
  set_color && echo
  echo -e "\t\tCreating Portainer"
  docker run -d --name Portainer --hostname portainer --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$PORTAINERPORT:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce:latest 
}

create_homer() {
  set_color && echo
  echo -e "\t\tCreating Homer"
  docker run -d --name Homer --hostname homer --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $HOMERPORT:8080 -u 0:0 -v "${DOCPATH}"/homer:/www/assets:rw -v "${DOCPATH}"/homer/tools:/www/assets/tools:rw -e INIT_ASSETS=1 b4bz/homer:latest 
}

create_vaultwarden() {
  set_color && echo
  mkdir -p "${DOCPATH}"/vaultwarden/ssl

  openssl req -nodes -x509 -newkey rsa:4096 -keyout "${DOCPATH}"/vaultwarden/ssl/bitwarden.key -out "${DOCPATH}"/vaultwarden/ssl/bitwarden.crt -days 365 -subj "/C=CA/ST=Ontario/L=Ottawa/O=TF/CN=bitwarden.local"

  ls "${DOCPATH}"/vaultwarden/ssl/
  echo -e "\t\tCreating VaultWarden"
  docker run -d --name VaultWarden --hostname vaultwarden --restart ${DOCKERSTART} -e SIGNUPS_ALLOWED=true -e INVITATIONS_ALLOWED=true -e DISABLE_ADMIN_TOKEN=false -e ADMIN_TOKEN='$argon2i$v=19$m=1024,t=1,p=2$em5qbXZ0OWtxQjcySHFINA$4ru65itAqedJVRs2C23JkQ' -e WEBSOCKET_ENABLED=false -p $VAULTPORT:80 -e ROCKET_TLS='{certs="/ssl/bitwarden.crt",key="/ssl/bitwarden.key"}' -v "${DOCPATH}"/vaultwarden/data:/data/:rw -v "${DOCPATH}"/vaultwarden/ssl:/ssl/:rw vaultwarden/server:latest
}

create_dfir_iris() {
  set_color && echo
  echo -e "\t\tCreating DFIR-IRIS"
  git clone https://github.com/dfir-iris/iris-web.git "${DOCPATH}/iris-web"
  cd "${DOCPATH}"/iris-web || exit
  git checkout v2.4.12
  cp .env.model .env
  sed -i "s/#IRIS_ADM_USERNAME=administrator/IRIS_ADM_USERNAME=$LOGINUSER/" ./.env
  sed -i "s/#IRIS_ADM_PASSWORD=MySuperAdminPassword!/IRIS_ADM_PASSWORD=$ACTPASSWORD/" ./.env
  sed -i "s/INTERFACE_HTTPS_PORT=443/INTERFACE_HTTPS_PORT=$DFIRIRISPORT/" ./.env
  docker compose pull
  docker compose up --detach
  cd ../..
}

create_paperless() {
  set_color && echo
  echo -e "\t\tCreating Paperless"
  #docker volume create paperless_{data, media, pgdata, redisdata}
  docker run -d --name Paperless-Redis --hostname paperless-redis --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -v "${DOCPATH}"/paperless/redisdata:/data docker.io/library/redis:7
  chmod -R 777 "${DOCPATH}"/paperless/redisdata
  docker run -d --name Paperless-DB --hostname paperless-db --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -v "${DOCPATH}"/paperless/pgdata:/var/lib/postgresql/data -e POSTGRES_DB=paperless -e POSTGRES_USER=paperless -e POSTGRES_PASSWORD=paperless docker.io/library/postgres:16
  docker run -d --name Paperless-NGX --hostname paperless-ngx --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $PAPERLESSPORT:8000 -v "${DOCPATH}"/paperless/data:/usr/src/paperless/data -v "${DOCPATH}"/paperless/media:/usr/src/paperless/media -v "${DOCPATH}"/paperless/export:/usr/src/paperless/export -v "${DOCPATH}"/paperless/consume:/usr/src/paperless/consume -e PAPERLESS_REDIS=redis://Paperless-Redis:6379 -e PAPERLESS_DBHOST=Paperless-DB -e PAPERLESS_OCR_LANGUAGE=eng -e USERMAP_UID=1000 -e USERMAP_GID=1000 -e PAPERLESS_OCR_LANGUAGES=fra ghcr.io/paperless-ngx/paperless-ngx:latest
  #-e PAPERLESS_URL=https://paperless.example.com
  #-e PAPERLESS_SECRET_KEY=change-me
}

create_ollama() {
  # https://github.com/ollama/ollama
  set_color && echo
  echo -e "\t\tCreating Ollama LLM"
  docker run -d --name Ollama-LLM --hostname ollama-llm --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p 11434:11434 -v "${DOCPATH}"/ollama:/root/.ollama ollama/ollama
}

create_llm_gpu_cuda() {
  # https://stackoverflow.com/questions/63751883/using-gpu-inside-docker-container-cuda-version-n-a-and-torch-cuda-is-availabl
  set_color && echo
  echo -e "\t\tCreating Ollama LLM with GPU and CUDA"
  
  # Install and prep CUDA Ubuntu
  echo '#!/bin/bash' | sudo tee /usr/local/bin/dockercuda
  printf 'sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi' | sudo tee -a /usr/local/bin/dockercuda
  sudo chmod +x /usr/local/bin/dockercuda

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  
  sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi

  echo "You can use the 'dockercuda' command to check if the GPU is working."
}

create_openwebui() {
  # https://github.com/open-webui/open-webui    
  set_color && echo
  echo -e "\t\tCreating OpenWebUI"
  docker run -d --name OpenWebUI --hostname openwebui --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$OLLAMAPORT:8080 -e OLLAMA_BASE_URL=http://"$HOSTIP":11434 -v ollama:/root/.ollama -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main
}

create_webpage() {
  set_color && echo
  docker build -t ollama-ocr "${DOCPATH}"/OCR/
  docker run -d --name Ollama-OCR --hostname ollama-ocr --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -v "${DOCPATH}"/OCR/html:/var/www/html:rw -p $ALLOWEDIPS:$OCRPORT:5000 ollama-ocr
}

create_drawio() {
  # https://github.com/jgraph/drawio
  set_color && echo
  echo -e "\t\tCreating Draw.io"
  docker run -d --name Draw.io --hostname drawio --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$DRAWIOPORT:8080 jgraph/drawio:latest
}

create_photopea() {
  # 
  set_color && echo
  echo -e "\t\tCreating Photopea"
  docker run -d --name Photopea --hostname photopea --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$PHOTOPEAPORT:8887 eorendel/photopea:latest
}

create_cyberchef() {
  # https://github.com/mpepping/docker-cyberchef
  set_color && echo
  echo -e "\t\tCreating CyberChef"
  docker run -d --name CyberChef --hostname cyberchef --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:"$CYBERCHEFPORT":8000 mpepping/cyberchef:latest
}

create_regex101() {
  # https://github.com/LoopSun/regex101-docker
  set_color && echo
  echo -e "\t\tCreating Regex101"
  docker run -d --name Regex101 --hostname regex101 --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:"$REGEX101PORT":9090 loopsun/regex101
}

create_ittools() {
  # https://it-tools.tech/docker-run-to-docker-compose-converter
  set_color && echo
  echo -e "\t\tCreating IT Tools"
  docker run -d --name IT-Tools --hostname it-tools --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$ITTOOLSPORT:80 corentinth/it-tools:latest
}

create_codimd() {
  # https://hackmd.io/c/codimd-documentation/%2Fs%2Fcodimd-docker-deployment
  # https://github.com/hackmdio/codimd
  set_color && echo
  echo -e "\t\tCreating Codimd DB"
  docker run -d --name Codimd-DB --hostname codimd-db --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -v "${DOCPATH}"/codimd/db-data:/var/lib/postgresql/data:rw -e POSTGRES_DB=codimd -e POSTGRES_USER=codimd -e POSTGRES_PASSWORD=${ACTPASSWORD} postgres:14-alpine 
  
  echo
  echo -e "\t\tCreating Codimd"
  docker run -d --name Codimd --hostname codimd --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$CODIMDPORT:3000 -e CMD_DB_URL=postgres://codimd:${ACTPASSWORD}@Codimd-DB/codimd -e CMD_USECDN=false -v "${DOCPATH}"/codimd/uploads:/home/hackmd/app/public/uploads hackmdio/hackmd:2.5.4
}

create_n8n() {
  # https://github.com/n8n-io/n8n
  set_color && echo
  echo -e "\t\tCreating N8N"
  docker run -d --name N8N --hostname n8n --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$N8NPORT:5678 -e N8N_BASIC_AUTH_ACTIVE=true -e N8N_SECURE_COOKIE=false -e N8N_BASIC_AUTH_USER=${LOGINUSER}@n8n.local -e N8N_BASIC_AUTH_PASSWORD=${ACTPASSWORD} -v "${DOCPATH}"/n8n:/home/node/.n8n n8nio/n8n:latest
}

create_gitlab() {
  # https://docs.gitlab.com/ee/install/docker/installation.html
  set_color && echo
  echo -e "\t\tCreating GitLab"
  docker run -d --name GitLab --hostname gitlab --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:"$GITLABPORT":80 -v "${DOCPATH}"/gitlab/config:/etc/gitlab:rw -v "${DOCPATH}"/gitlab/logs:/var/log/gitlab:rw -v "${DOCPATH}"/gitlab/data:/var/opt/gitlab:rw gitlab/gitlab-ce:latest
}

create_etherpad() {
  # https://github.com/ether/etherpad-lite
  set_color && echo
  echo -e "\t\tCreating Etherpad"
  docker run -d --name EtherPad --hostname etherpad --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB --pids-limit 2048 -e TZ=America/New_York -e NODE_VERSION=22.8.0 -e YARN_VERSION=1.22.22 -e TIMEZONE= -e NODE_ENV=production -e ETHERPAD_PRODUCTION=1 -p $ALLOWEDIPS:"$ETHERPADPORT":9001 etherpad/etherpad
}

create_remmina() {
  # https://github.com/linuxserver/docker-remmina
  set_color && echo
  echo -e "\t\tCreating Remmina"
  docker run -d --name Remmina --hostname remmina -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC -p $ALLOWEDIPS:$REMMINAPORT:3000 -p $ALLOWEDIPS:3001:3001 -v "${DOCPATH}"/remmina/config:/config --restart unless-stopped lscr.io/linuxserver/remmina:latest
}

create_b_b_shuffle() {
  # https://github.com/p3hndrx/B-B-Shuffle
  set_color && echo
  echo -e "\t\tCreating B-B-Shuffle"
  ## If you want to change the background image, you can replace the Orange-Background.png with your own image
  #cp Images/Orange-Background.png "${DOCPATH}"/B-B-Shuffle/App/img/page-back.png
  git clone https://github.com/p3hndrx/B-B-Shuffle.git "${DOCPATH}"/B-B-Shuffle
  docker build -t b-b-shuffle "${DOCPATH}"/B-B-Shuffle/
  docker run -d --name B-B-Shuffle --hostname b-b-shuffle --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:"${BBSHUFFLEPORT}":80 -v "${DOCPATH}"/B-B-Shuffle/html:/var/www/html:rw b-b-shuffle
}

create_stego-toolkit() {
  # https://github.com/DominicBreuker/stego-toolkit
  set_color && echo
  echo -e "\t\tCreating Stego-Toolkit"
  git clone https://github.com/DominicBreuker/stego-toolkit.git "${DOCPATH}"/stego-toolkit
  docker pull dominicbreuker/stego-toolkit:latest
  #docker build -t stego-toolkit "${DOCPATH}"/stego-toolkit/
  #docker run -d --name Stego-Toolkit --hostname stego-toolkit --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -v "${DOCPATH}"/stego-toolkit:/root/stego-toolkit:rw stego-toolkit
  #docker run -it --rm -p 127.0.0.1:22:22 dominicbreuker/stego-toolkit /bin/bash -c "start_ssh.sh && ssh -X -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost"
  #docker run -it --rm -p 127.0.0.1:6901:6901 dominicbreuker/stego-toolkit /bin/bash -c "start_vnc.sh && vncserver :1 -geometry 1280x800 -depth 24 && tail -f /root/.vnc/*:1.log"
  #docker run -d --name Stego-Toolkit --hostname stego-toolkit --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p 6901:6901 -p 22:22 dominicbreuker/stego-toolkit
  # in browser, connect with: http://localhost:6901/?password=<password_from_start_vnc>
}

create_sift_remnux() {
  # Prompt the user if they want to build, pull the image from docker-hub, or skip
  set_color && echo
  echo -e "\t\tCreating SIFT-REMnux"
  echo -e "Building the image can take a while. Potentially 30-120 min. Pulling from Docker-Hub is faster."
  read -r -p "Do you want to build the image, pull from Docker-Hub, or skip? [b/p/S] (default: Skip): " build_pull_skip
  build_pull_skip=${build_pull_skip:-s}
  if [[ $build_pull_skip =~ ^[Bb][Uu][Ii][Ll][Dd]$ || $build_pull_skip =~ ^[Bb]$ ]]; then
    # Build the image
    echo "Building the image..."
    docker build -t sift-remnux -f "${DOCPATH}"/siftnux-docker/Dockerfile "${DOCPATH}"/siftnux-docker

    # Run the container
    docker run -d --name SIFT-REMnux --hostname sift-remnux --restart ${DOCKERSTART} -p $ALLOWEDIPS:33:22 -v "${DOCPATH}"/sift-remnux:/root sift-remnux

  elif [[ $build_pull_skip =~ ^[Pp][Uu][Ll][Ll]$ || $build_pull_skip =~ ^[Pp]$ ]]; then
    # Pull the image
    echo "Pulling the image..."
    docker pull digitalsleuth/sift-remnux:latest

    # Run the container
    docker run -d --name SIFT-REMnux --hostname sift-remnux --restart ${DOCKERSTART} -p $ALLOWEDIPS:33:22 -v "${DOCPATH}"/sift-remnux:/root digitalsleuth/sift-remnux:latest

  else
    echo "Skipping SIFT-REMnux setup."
  fi
}

create_vscode() {
  set_color && echo
  echo -e "\t\tCreating VSCode"
  docker run -d --name VSCode --hostname vscode --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB -p $ALLOWEDIPS:$VSCODEPORT:8443 -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC -e PASSWORD=${ACTPASSWORD} -e HASHED_PASSWORD= -e SUDO_PASSWORD=${ACTPASSWORD} -e SUDO_PASSWORD_HASH= -e DEFAULT_WORKSPACE=/config/workspace -v "${DOCPATH}"/vscode:/config lscr.io/linuxserver/code-server:latest

  # Install extensions
  echo "Installing VSCode Extensions..."
  docker exec -it VSCode "code-server --install-extension \
    esbenp.prettier-vscode \
    ms-python.debugpy \
    redhat.vscode-yaml \
    redhat.vscode-xml \
    gitlab.gitlab-workflow \
    vscode-icons-team.vscode-icons \ 
    yzhang.markdown-all-in-one \
    mechatroner.rainbow-csv \
    oderwat.indent-rainbow \
    shd101wyy.markdown-preview-enhanced \
    grapecity.gc-excelviewer \
    bierner.markdown-mermaid \
    bpruitt-goddard.mermaid-markdown-syntax-highlighting"
  }

install_backup() {
  set_color && echo
  # Create cron job to backup "${DOCPATH}" folder
  echo "--------------------------------------------------------------------------------------"
  echo "                         Creating Backup Cron Job..."
  echo "--------------------------------------------------------------------------------------"
  echo "0 0 * * * tar -czvf /root/$(basename "${DOCPATH}")-backup.tar.gz -C ${DOCPATH} ." | crontab -
  echo "Cron job created."

  # Shutdown all containers and backup the "${DOCPATH}" folder
  echo "--------------------------------------------------------------------------------------"
  echo "                         Shutting down all containers..."
  echo "--------------------------------------------------------------------------------------"
  docker stop "$(docker ps -aq)"
  echo "All containers stopped."
  echo
  echo "--------------------------------------------------------------------------------------"
   # Backup the "${DOCPATH}" folder as root
  echo "--------------------------------------------------------------------------------------"
  echo "                         Backing up ""${DOCPATH}"" folder..."
  echo "--------------------------------------------------------------------------------------"
  tar -czvf /root/zocker-data-backup.tar.gz -C "${DOCPATH}" .
  echo "Backup completed: /root/zocker-data-backup.tar.gz"
  echo
  echo "--------------------------------------------------------------------------------------"
  echo "                         Restarting all containers..."
  echo "--------------------------------------------------------------------------------------"
  docker start "$(docker ps -aq)"
  echo "All containers restarted."
  echo
  echo "--------------------------------------------------------------------------------------"
  echo "                         Backup complete."
  echo "--------------------------------------------------------------------------------------"
}

# Helps Load pages faster for file editing
curl http://"$HOSTIP":$HOMERPORT > /dev/null 2>&1

fn_summary_cleanup() {
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
  echo "                                I changed the text color back to white for you"
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
  echo -e " VaultWarden    | $HOSTIP:$VAULTPORT/admin | N/A                                                         | L7G\$DF8@@SA5SA*PAPVWK7SQUF\$N#J"
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
  echo -e " OpenWebUI Admin| $HOSTIP:$OLLAMAPORT       | <You can create your own> (First one gets admin)            | <You can create your own>"
  echo -e " OpenWebUI      | $HOSTIP:$OLLAMAPORT       | <You can create your own>                                   | <You can create your own>"
  echo -e " Ollama-OCR     | $HOSTIP:$OCRPORT       | N/A                                                         | N/A"
  echo -e " B-B-Shuffle    | $HOSTIP:$BBSHUFFLEPORT       | N/A                                                         | N/A"
  echo -e " VSCode         | $HOSTIP:$VSCODEPORT       | N/A                                                         | ${ACTPASSWORD}"
  echo -e " Stego-Toolkit  | N/A                       | N/A                                                         | N/A"
  echo -e " Remmina        | $HOSTIP:$REMMINAPORT       | N/A                                                         | N/A"
  echo -e "------------------------------------------------------------------------------------------"
}

postcreation_changes() {
  ## Planka
  # Using SED, look in the file /app/public/static/css/main.*.css and not the main.*.css.map file and replace "../../static/media/*.jpg" with "../../static/media/cover.jpg"
  docker exec -it Planka bash -c "sed -i 's/..\/..\/static\/media\/.*.jpg/..\/..\/static\/media\/cover.jpg/g' /app/public/static/css/main.*.css"
  # Copy an Image from project image to media cover to replace the Splash Screen Image.
  docker exec -it Planka bash -c "cp /app/public/project-background-images/HALp-Ai-1.jpg /app/public/static/media/cover.jpg"

  ## Replace DFIR-IRIS Logo and Blue Color to Orange
  #docker exec -it iriswebapp_app bash -c "sed -i 's/#013479, #011d40/794d01, #b4770e/g' /iriswebapp/app/static/assets/css/login/login.css"
  #docker exec -it iriswebapp_app bash -c "sed -i 's/05316a/794d01/g' /iriswebapp/app/static/assets/css/login/login.css"

  # Docker Copy Command Image
  docker cp ./Images/iris-logo-white.png iriswebapp_app:/iriswebapp/app/static/assets/img/logo-white.png

  ## Remove Extra Apt Packages
  sudo apt autoremove -y
}

install_complete() {
  set_color && echo
  echo "--------------------------------------------------------------------------------------"
  echo "                             Installation Complete"
  echo "--------------------------------------------------------------------------------------"
  echo " Setting up Permissions...to be full 777 - Very Insecure, but this should be a closed system"
  chmod -R 777 "${DOCPATH}"
  echo " Permissions set to 777"
  echo "--------------------------------------------------------------------------------------"
  echo " Insert Profit Here"
  echo "--------------------------------------------------------------------------------------"
  echo
  dockerpss
}

check_root_access        ## CHECKING FOR ROOT ACCESS...
check_system_resources   ## CHECKING SYSTEM RESOURCES
 
print_tools_to_install   ## TOOLS TO BE INSTALLED
create_prerequisites     ## UPDATES AND PREREQUISITES SETUP
folder_variables_check   ## Data Folder Creation
network_creation         ## Creating Network...

dashboard_SED            ## Replaces IP and Ports in Homer Config

create_portainer         ## Creating Portainer...
create_homer             ## Installing Dashboard...
create_vaultwarden       ## Installing Vaultwarden...
create_dfir_iris         ## Installing DFIR-IRIS...
create_bookstack         ## Installing Wiki...
create_planka            ## Installing KanBan...
create_paperless         ## Installing Paperless...
create_ollama            ## Installing Ollama...
create_llm_gpu_cuda      ## Installing Ollama with GPU and CUDA...
create_openwebui         ## Installing OpenWebUI...
create_webpage           ## Installing Ollama-OCR...
create_ittools           ## Installing IT Tools...
create_codimd            ## Installing Codimd...
create_n8n               ## Installing N8N...
create_gitlab            ## Installing GitLab...
create_drawio            ## Installing Drawio...
create_cyberchef         ## Installing CyberChef...
create_photopea          ## Installing Photopea...
create_remmina
create_regex101          ## Installing Regex101...
create_etherpad          ## Installing Etherpad...
create_b_b_shuffle       ## Installing B-B-Shuffle...
create_vscode            ## Installing VSCode...
create_stego-toolkit     ## Installing Stego-Toolkit...
create_sift_remnux       ## Installing SIFT-REMnux...

postcreation_changes     ## Post Creation Changes such as replace images or change colors

fn_summary_cleanup       ## SUMMARY of Installation for user to see

default_logins_summary   ## VISIT $HOSTIP:$HOMERPORT TO ACCESS HOMER

#install_backup           ## Creating Backup Cron Job and Running Backup

install_complete         ## The last part of the script
