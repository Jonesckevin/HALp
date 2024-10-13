# shellcheck disable=1017, 2215
#!/bin/bash

counter=2
set_color() {
    ((counter++))                          # Increment counter
    [[ $counter -gt 7 ]] && counter=1      # Reset counter
    [[ $counter -eq 4 ]] && ((counter++))  # Skip color 4 Blue (Looks bad on black bg)
    tput setaf $counter
}

chmod -R 777 ./*

# Variables
HOSTIP=$(hostname -I | awk '{print $1}')
LOGINUSER="admin"
ACTPASSWORD="password"
DOCKERSTART=unless-stopped
HALPNETWORK="halp"
DOCPATH=$(pwd)/zocker-data

## Ports
HOMERPORT=80            # Homer
VAULTPORT=1000          # Vaultwarden
PORTAINERPORT=1001      # Portainer
PLANKAPORT=1002         # Planka
BOOKSTACKPORT=1003      # BookStack
PAPERLESSPORT=1004          # Paperless
OLLAMAPORT=1005         # Ollama LLM
OCRPORT=1006            # Ollama OCR
DRAWIOPORT=1007         # Draw.io
CYBERCHEFPORT=1008      # CyberChef
REGEX101PORT=1009       # Regex101
ITTOOLSPORT=1010        # IT Tools
CODIMDPORT=1011         # Codimd
ETHERPADPORT=1012       # Etherpad
N8NPORT=1013            # N8N
GITLABPORT=1014         # GitLab

check_root_access() {
  set_color
  echo
  echo "--------------------------------------------------------------------------------------"
  echo "                          CHECKING FOR ROOT ACCESS...                                 "
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
  echo "                            CHECKING SYSTEM RESOURCES                                 "
  echo "                   It's recommended to have 12 Cores and 16GB RAM                     "
  echo "--------------------------------------------------------------------------------------"
  cpu_check () {
    echo "Checking CPU Cores..."
    CORES=$(nproc)
    if [[ $CORES -lt 12 ]]; then
      echo "    You have $CORES CPU Cores. It's recommended to have 8+ Cores."
    else
      echo "    You have $CORES CPU Cores. Moving Forward..."
    fi
  }
  cpu_check
  mem_check () {
    echo "Checking Memory..."
    MEMORY=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $MEMORY -lt 16000 ]]; then
      echo "    You have $MEMORY MB of RAM. It's recommended to have 16GB RAM."
    else
      echo "    You have $MEMORY MB of RAM. Moving Forward..."
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
  echo "                          TOOLS TO BE INSTALLED                                      "
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
  echo -e "\t Paperless\t<-  $PAPERLESSPORT ->\tDocument Management with OCR"
  echo -e "\t Ollama LLM\t<-  $OLLAMAPORT ->\tOffline LLM"
  echo -e "\t Ollama OCR\t<-  $OCRPORT ->\tOCR For Images to Text and/or Translation"
  echo -e "\t Draw.io\t<-  $DRAWIOPORT ->\tDiagramming Tool"
  echo -e "\t CyberChef\t<-  $CYBERCHEFPORT ->\tCyberChef"
  echo -e "\t Regex101\t<-  $REGEX101PORT ->\tRegex Testing"
  echo -e "\t IT Tools\t<-  $ITTOOLSPORT ->\tVarious IT Tools"
  echo -e "\t Codimd\t\t<-  $CODIMDPORT ->\tCollaborative Markdown Editor"
  echo -e "\t Etherpad\t<-  $ETHERPADPORT ->\tCollaborative Document Editing"
  echo -e "\t N8N\t\t<-  $N8NPORT ->\tWorkflow Automation"
  echo -e "\t GitLab\t\t<-  $GITLABPORT ->\tOffline and OpenSource Git"
}

create_prerequisites() {
  echo "--------------------------------------------------------------------------------------"
  echo "                      UPDATES AND PREREQUISITES SETUP"
  echo "--------------------------------------------------------------------------------------"
  set_color
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
      echo

      counter=$((counter+1)) && counter=$((counter>7 ? 1 : counter)) && tput setaf $counter

      echo "-----------------------------------------------------------------------------------------"
      echo
      echo "$package_manager_message"
      echo
      echo "-----------------------------------------------------------------------------------------"
      echo
      # Update and install prerequisites using the package manager
      $package_manager update -y
      $package_manager upgrade -y
      $package_manager install -y \
          htop \
          git \
          curl \
          net-tools \
          open-vm-tools-desktop \
          openssh-server \
          ca-certificates \
          gnupg \
          lsb-release \
          software-properties-common \
          apt-transport-https \
          openjdk-11-jdk

      # Remove old docker if exists
      $package_manager remove -y \
          docker.io \
          containerd \
          runc \
          docker-compose

      # Update repository with official docker
      install -m 0755 -d /etc/apt/keyrings
      if [[ $package_manager == "apt" ]]; then
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
          chmod a+r /etc/apt/keyrings/docker.gpg
          echo "deb [arch=$(dpkg --print-architecture) \
          signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
      elif [[ $package_manager == "yum" ]]; then
          yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi

      # Update with new repository then install docker and dependencies
      $package_manager update -y
      $package_manager install -y \
          docker-ce \
          docker-ce-cli \
          containerd.io \
          docker-buildx-plugin \
          docker-compose-plugin

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
              set_color && echo "ownership of './zocker-data/' retained as 1000:1000"
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
  sed -i \
    "s/\$HOSTIP/$HOSTIP/g; \
    s/\$HOMERPORT/$HOMERPORT/g; \
    s/\$VAULTPORT/$VAULTPORT/g; \
    s/\$PORTAINERPORT/$PORTAINERPORT/g; \
    s/\$PLANKAPORT/$PLANKAPORT/g; \
    s/\$BOOKSTACKPORT/$BOOKSTACKPORT/g; \
    s/\$PAPERLESSPORT/$PAPERLESSPORT/g; \
    s/\$OLLAMAPORT/$OLLAMAPORT/g; \
    s/\$OCRPORT/$OCRPORT/g; \
    s/\$DRAWIOPORT/$DRAWIOPORT/g; \
    s/\$CYBERCHEFPORT/$CYBERCHEFPORT/g; \
    s/\$REGEX101PORT/$REGEX101PORT/g; \
    s/\$ITTOOLSPORT/$ITTOOLSPORT/g; \
    s/\$CODIMDPORT/$CODIMDPORT/g; \
    s/\$ETHERPADPORT/$ETHERPADPORT/g; \
    s/\$GITLABPORT/$GITLABPORT/g; \
    s/\$N8NPORT/$N8NPORT/g" \
    "${DOCPATH}"/homer/config.yml #  > /dev/null 2>&1

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

create_bookstack_db() {
  set_color && echo
  echo -e "\t\tCreating MySQL - BookStack-DB"
  docker run -d \
  --name BookStack-DB --hostname bookstack-db \
  --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
  -e PUID=1000 -e PGID=1000 \
  -e MYSQL_ROOT_PASSWORD=bookstackrootpassword \
  -e TZ=America/Toronto \
  -v "${DOCPATH}"/bookstack/db_data:/config \
  -e MYSQL_DATABASE=bookstackapp \
  -e MYSQL_USER=bookstack -e MYSQL_PASSWORD=bookstackpassword \
  lscr.io/linuxserver/mariadb  #  > /dev/null 2>&1
}
create_bookstack() {
  echo -e "\t\tCreating Bookstack"
  docker run -d \
  --name BookStack --hostname bookstack \
  --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
  -p $BOOKSTACKPORT:80 \
  -v "${DOCPATH}"/bookstack/app_data:/config \
  -v "${DOCPATH}"/bookstack/public:/var/www/bookstack/public:rw \
  -e PUID=1000 \
  -e PGID=1000 \
  -e DB_PORT=3306 \
  -e DB_HOST=BookStack-DB \
  -e APP_URL=http://"$HOSTIP":$BOOKSTACKPORT \
  -e DB_USER=bookstack -e DB_PASS=bookstackpassword -e DB_DATABASE=bookstackapp \
  lscr.io/linuxserver/bookstack  #  > /dev/null 2>&1
}
 

create_planka_db() {
  set_color && echo
  echo -e "\t\tCreating PostGres - Planka-DB"
  docker run -d \
  --name Planka-DB --hostname planka-db \
  --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
  -v "${DOCPATH}"/planka/db-data:/var/lib/postgresql/data:rw \
  -e POSTGRES_DB=planka \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:14-alpine  #  > /dev/null 2>&1
}

create_portainer() {
  set_color && echo
  echo -e "\t\tCreating Portainer"
  docker run -d \
  --name Portainer --hostname portainer \
  --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
  -p 0.0.0.0:$PORTAINERPORT:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  portainer/portainer-ce:latest  #  > /dev/null 2>&1
}

create_homer() {
  echo -e "\t\tCreating Homer"
  docker run -d \
  --name Homer --hostname homer \
  --restart ${DOCKERSTART} --network ${HALPNETWORK} \
  -p $HOMERPORT:8080 \
  -u 0:0 \
  -v "${DOCPATH}"/homer:/www/assets:rw \
  -v "${DOCPATH}"/homer/tools:/www/assets/tools:rw \
  -e INIT_ASSETS=1 \
  b4bz/homer:latest  #  > /dev/null 2>&1
}

create_planka() {
    echo -e "\t\tCreating Planka"
    docker run -d \
      --name Planka --hostname planka \
      --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
      -p $PLANKAPORT:1337 \
      -e BASE_URL=http://"$HOSTIP":$PLANKAPORT \
      -e DATABASE_URL=postgresql://postgres@Planka-DB/planka \
      -e SECRET_KEY=secretofkeys \
      -e DEFAULT_ADMIN_EMAIL=${LOGINUSER}@planka.local \
      -e DEFAULT_ADMIN_PASSWORD=${ACTPASSWORD} \
      -e DEFAULT_ADMIN_NAME=Admin \
      -e DEFAULT_ADMIN_USERNAME=admin \
      -v "${DOCPATH}"/planka/user-avatars:/app/public/user-avatars \
      -v "${DOCPATH}"/planka/project-background-images:/app/public/project-background-images \
      -v "${DOCPATH}"/planka/attachments:/app/private/attachments \
      ghcr.io/plankanban/planka:latest #  > /dev/null 2>&1
}

echo "--------------------------------------------------------------------------------------"
echo "                             Installing Additional Tools..."
echo "--------------------------------------------------------------------------------------"
set_color && echo

create_vaultwarden() {
  mkdir -p "${DOCPATH}"/vaultwarden/ssl

  openssl req -nodes -x509 -newkey rsa:4096 -keyout "${DOCPATH}"/vaultwarden/ssl/bitwarden.key -out "${DOCPATH}"/vaultwarden/ssl/bitwarden.crt -days 365 -subj "/C=CA/ST=Ontario/L=Ottawa/O=TF/CN=bitwarden.local"

  ls "${DOCPATH}"/vaultwarden/ssl/
  echo -e "\t\tCreating VaultWarden"
  docker run -d \
    --name VaultWarden --hostname vaultwarden \
    --restart ${DOCKERSTART} \
    -e SIGNUPS_ALLOWED=true \
    -e INVITATIONS_ALLOWED=true \
    -e DISABLE_ADMIN_TOKEN=false \
    -e ADMIN_TOKEN='$argon2i$v=19$m=1024,t=1,p=2$em5qbXZ0OWtxQjcySHFINA$4ru65itAqedJVRs2C23JkQ' \
    -e WEBSOCKET_ENABLED=false \
    -p $VAULTPORT:80 \
    -e ROCKET_TLS='{certs="/ssl/bitwarden.crt",key="/ssl/bitwarden.key"}' \
    -v "${DOCPATH}"/vaultwarden/data:/data/:rw \
    -v "${DOCPATH}"/vaultwarden/ssl:/ssl/:rw \
    vaultwarden/server:latest #  > /dev/null 2>&1
}

create_paperless() {
    echo -e "\t\tCreating Paperless"
    #docker volume create paperless_{data, media, pgdata, redisdata}
    
    docker run -d \
        --name Paperless-Redis --hostname paperless-redis \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -v "${DOCPATH}"/paperless/redisdata:/data \
        docker.io/library/redis:7 #  > /dev/null 2>&1
    
    sleep 1
    chmod -R 777 "${DOCPATH}"/paperless/redisdata

    docker run -d \
        --name Paperless-DB --hostname paperless-db \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -v "${DOCPATH}"/paperless/pgdata:/var/lib/postgresql/data \
        -e POSTGRES_DB=paperless \
        -e POSTGRES_USER=paperless \
        -e POSTGRES_PASSWORD=paperless \
        docker.io/library/postgres:16 #  > /dev/null 2>&1
    
    docker run -d \
        --name Paperless-NGX --hostname paperless-ngx \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p $PAPERLESSPORT:8000 \
        -v "${DOCPATH}"/paperless/data:/usr/src/paperless/data \
        -v "${DOCPATH}"/paperless/media:/usr/src/paperless/media \
        -v "${DOCPATH}"/paperless/export:/usr/src/paperless/export \
        -v "${DOCPATH}"/paperless/consume:/usr/src/paperless/consume \
        -e PAPERLESS_REDIS=redis://Paperless-Redis:6379 \
        -e PAPERLESS_DBHOST=Paperless-DB \
        -e PAPERLESS_OCR_LANGUAGE=eng \
        -e USERMAP_UID=1000 \
        -e USERMAP_GID=1000 \
        -e PAPERLESS_OCR_LANGUAGES=fra \
        ghcr.io/paperless-ngx/paperless-ngx:latest #  > /dev/null 2>&1
        #-e PAPERLESS_URL=https://paperless.example.com
        #-e PAPERLESS_SECRET_KEY=change-me
}

create_ollama() {
    echo -e "\t\tCreating Ollama LLM"
    docker run -d \
        --name Ollama-LLM --hostname ollama-llm \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p 11434:11434 \
        -v "${DOCPATH}"/ollama:/root/.ollama \
        ollama/ollama
}

create_openwebui() {
    # https://github.com/open-webui/open-webui    
    echo -e "\t\tCreating OpenWebUI"
    docker run -d \
        --name OpenWebUI --hostname openwebui \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p $OLLAMAPORT:8080 \
        -v ollama:/root/.ollama \
        -v open-webui:/app/backend/data \
        ghcr.io/open-webui/open-webui:main
}

create_webpage() {
  echo -e "\t\tCreating Ollama-OCR"
  docker run -d \
    --name Ollama-OCR --hostname ollama-ocr \
    --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
    -p $OCRPORT:80 \
    -v "${DOCPATH}"/OCR:/var/www/html:rw \
    python:3.9-slim bash -c "apt-get update && apt-get install -y apache2 && service apache2 start && tail -f /dev/null"
}

create_drawio() {
    echo -e "\t\tCreating Draw.io"
    docker run -d \
        --name Draw.io --hostname drawio \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p $DRAWIOPORT:8080 \
        jgraph/drawio:latest #  > /dev/null 2>&1
}

create_cyberchef() {
    echo -e "\t\tCreating CyberChef"
    docker run -d \
        --name CyberChef --hostname cyberchef \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p "$CYBERCHEFPORT":8000 \
        mpepping/cyberchef:latest #  > /dev/null 2>&1
}

create_regex101() {
    echo -e "\t\tCreating Regex101"
    docker run -d \
        --name Regex101 --hostname regex101 \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p "$REGEX101PORT":9090 \
        loopsun/regex101 #  > /dev/null 2>&1
}

create_ittools() {
    # https://it-tools.tech/docker-run-to-docker-compose-converter
    echo -e "\t\tCreating IT Tools"
    docker run -d \
    --name IT-Tools --hostname it-tools \
    --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
    -p $ITTOOLSPORT:80 \
    corentinth/it-tools:latest
}

create_codimd() {
    # https://hackmd.io/c/codimd-documentation/%2Fs%2Fcodimd-docker-deployment
    echo -e "\t\tCreating Codimd DB"
    docker run -d \
        --name Codimd-DB --hostname codimd-db \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -v "${DOCPATH}"/codimd/db-data:/var/lib/postgresql/data:rw \
        -e POSTGRES_DB=codimd \
        -e POSTGRES_USER=codimd \
        -e POSTGRES_PASSWORD=${ACTPASSWORD} \
        postgres:14-alpine  #  > /dev/null 2>&1
    
    echo -e "\t\tCreating Codimd"
    docker run -d \
        --name Codimd --hostname codimd \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p $CODIMDPORT:3000 \
        -e CMD_DB_URL=postgres://codimd:${ACTPASSWORD}@Codimd-DB/codimd \
        -e CMD_USECDN=false \
        -v "${DOCPATH}"/codimd/uploads:/home/hackmd/app/public/uploads \
        hackmdio/hackmd:2.5.4 #  > /dev/null 2>&1
}

create_n8n() {
    echo -e "\t\tCreating N8N"
    docker run -d \
        --name N8N --hostname n8n \
        --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
        -p $N8NPORT:5678 \
        -e N8N_BASIC_AUTH_ACTIVE=true \
        -e N8N_SECURE_COOKIE=false \
        -e N8N_BASIC_AUTH_USER=${LOGINUSER}@n8n.local \
        -e N8N_BASIC_AUTH_PASSWORD=${ACTPASSWORD} \
        -v "${DOCPATH}"/n8n:/home/node/.n8n \
        n8nio/n8n:latest #  > /dev/null 2>&1
}

create_gitlab() {
  echo -e "\t\tCreating GitLab"
  docker run -d \
    --name GitLab --hostname gitlab \
    --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
    -p "$GITLABPORT":80 \
    -v "${DOCPATH}"/gitlab/config:/etc/gitlab:rw \
    -v "${DOCPATH}"/gitlab/logs:/var/log/gitlab:rw \
    -v "${DOCPATH}"/gitlab/data:/var/opt/gitlab:rw \
    gitlab/gitlab-ce:latest #  > /dev/null 2>&1
}

create_etherpad() {
  echo -e "\t\tCreating Etherpad"
  docker run -d \
    --name EtherPad --hostname etherpad \
    --restart ${DOCKERSTART} --network ${HALPNETWORK} --network ${HALPNETWORK}_DB \
    --pids-limit 2048 \
    -e TZ=America/New_York \
    -e NODE_VERSION=22.8.0 \
    -e YARN_VERSION=1.22.22 \
    -e TIMEZONE= \
    -e NODE_ENV=production \
    -e ETHERPAD_PRODUCTION=1 \
    -p "$ETHERPADPORT":9001 \
    etherpad/etherpad
}


# Helps Load pages faster for file editing
curl http://"$HOSTIP":$HOMERPORT > /dev/null 2>&1

fn_summary_cleanup() {
  echo "-------------------------------------------------------------------------------------------------------------------------"
  echo
  echo "Currently your Docker containers ID are numbers and are as follows:"
  echo -e "               docker ps -a --format \"table {{.ID}}\\t{{.Names}}\\t{{.Status}}\\t{{.Ports}}\" | tail -n +2 | sort -k 2"
  echo "   OR " dockerpss ""
  echo "-------------------------------------------------------------------------------------------------------------------------"
  echo 'alias dockerpss="sudo docker ps -a --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\" | tail -n +2 | sort -k 2"' >> ~/.bashrc
  source ~/.bashrc
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
  echo -e "                     VISIT $HOSTIP:$HOMERPORT TO ACCESS HOMER"
  echo "          --------------------------------------------------------------------"

  echo -e "\t\tBookStack Default Login:\tadmin@admin.com // ${ACTPASSWORD}"
  echo -e "\t\tPlanka Default Login:\t\tadmin@planka.local // ${ACTPASSWORD}"
  echo
  echo -e "\t\tGitLab Default Can be set by using:"
  echo -e "\t\tGitLab Default Login at http://$HOSTIP:$GITLABPORT:\troot // <your inputed password>"
  echo
  echo -e "\t\tdocker exec -it GitLab gitlab-rake "gitlab:password:reset[root]""
  echo -e " Here is an Example: ERqx&xK5xkN2GP2fsMYH"
  echo
  echo -e "\t\tPaperless default login at http://$HOSTIP:$PAPERLESSPORT. Create new user:"
  echo -e "\t\tdocker exec -it Paperless-NGX "./manage.py createsuperuser""
  echo
  echo -e "\t\tVaultWarden Default Login:\tUse Password on http://$HOSTIP:$VAULTPORT/admin  // L7G\$DF8@@SA5SA*PAPVWK7SQUF\$N#J"
  echo
  echo -e "\t\tPortainer Default Login:\t<You can create your own>"
  echo -e "\t\t You will however have to restart the docker if you wait to long"
  echo
  echo -e "\t\tN8N Default Login:\t\t${LOGINUSER} // ${ACTPASSWORD}"
  echo
  echo -e "Check Logs at http://$HOSTIP:$PORTAINERPORT"
}


check_root_access ## CHECKING FOR ROOT ACCESS...
check_system_resources ## CHECKING SYSTEM RESOURCES
cpu_check
mem_check
 
print_tools_to_install     ## TOOLS TO BE INSTALLED
create_prerequisites      ## UPDATES AND PREREQUISITES SETUP
folder_variables_check     ## Data Folder Creation
network_creation           ## Creating Network...

dashboard_SED

create_portainer         ## Creating Portainer...
create_bookstack_db      ## Creating BookStack-DB...
create_planka_db         ## Creating Planka-DB...
create_homer             ## Installing Dashboard...
create_vaultwarden       ## Installing Vaultwarden...
create_portainer         ## Installing Portainer...
create_bookstack         ## Installing Wiki...
create_planka            ## Installing KanBan...
create_paperless         ## Installing Paperless...
create_ollama            ## Installing Ollama...
create_openwebui         ## Installing OpenWebUI...
create_webpage           ## Installing Ollama-OCR...
create_ittools           ## Installing IT Tools...
create_codimd            ## Installing Codimd...
create_n8n               ## Installing N8N...
create_gitlab            ## Installing GitLab...
create_drawio            ## Installing Drawio...
create_cyberchef         ## Installing CyberChef...
create_regex101          ## Installing Regex101...
create_etherpad          ## Installing Etherpad...

fn_summary_cleanup && dockerpss # docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | sort -k 2

default_logins_summary    # VISIT $HOSTIP:$HOMERPORT TO ACCESS HOMER

chmod -R 777 "${DOCPATH}"

echo "Profit"
echo
sudo docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | sort -k 2
