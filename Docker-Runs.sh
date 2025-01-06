#!/bin/bash

source ./Setup.sh

echo "Running from file: $0"

echo "--------------------------------------------------------------------------"
figlet "               Containers" | lolcat
echo "--------------------------------------------------------------------------"

create_bookstack() {
    echo -e "\t\tCreating MySQL - BookStack-DB"
    docker run -d \
        --name BookStack-DB \
        --hostname bookstack-db \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -e PUID=1000 \
        -e PGID=1000 \
        -e MYSQL_ROOT_PASSWORD=bookstackrootpassword \
        -e TZ=America/Toronto -v "${DOCPATH}"/bookstack/db_data:/config \
        -e MYSQL_DATABASE=bookstackapp \
        -e MYSQL_USER=bookstack \
        -e MYSQL_PASSWORD=bookstackpassword \
        lscr.io/linuxserver/mariadb >/dev/null 2>&1 &&
        log_success "BookStack-DB created successfully" || log_error "Failed to create BookStack-DB"

    echo -e "\t\tCreating Bookstack"
    docker run -d \
        --name BookStack \
        --hostname bookstack \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$ALLOWEDIPS":"$BOOKSTACKPORT":80 \
        -v "${DOCPATH}"/bookstack/app_data:/config \
        -v "${DOCPATH}"/bookstack/public:/var/www/bookstack/public:rw \
        -e PUID=1000 \
        -e PGID=1000 \
        -e DB_PORT=3306 \
        -e DB_HOST=BookStack-DB \
        -e APP_URL=http://"$HOSTIP":"$BOOKSTACKPORT" \
        -e DB_USER=bookstack \
        -e DB_PASS=bookstackpassword \
        -e DB_DATABASE=bookstackapp \
        lscr.io/linuxserver/bookstack:24.05.4 >/dev/null 2>&1 &&
        log_success "BookStack created successfully" || log_error "Failed to create BookStack"
}

create_planka() {
    echo -e "\t\tCreating PostGres - Planka-DB"
    docker run -d \
        --name Planka-DB \
        --hostname planka-db \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -v "${DOCPATH}"/planka/db-data:/var/lib/postgresql/data:rw \
        -e POSTGRES_DB=planka \
        -e POSTGRES_HOST_AUTH_METHOD=trust postgres:14-alpine >/dev/null 2>&1 &&
        log_success "Planka-DB created successfully" || log_error "Failed to create Planka-DB"
    echo -e "\t\tCreating Planka"
    docker run -d \
        --name Planka \
        --hostname planka \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$ALLOWEDIPS":"$PLANKAPORT":1337 \
        -e BASE_URL=http://"$HOSTIP":"$PLANKAPORT" \
        -e DATABASE_URL=postgresql://postgres@Planka-DB/planka \
        -e SECRET_KEY=secretofkeys \
        -e DEFAULT_ADMIN_EMAIL="${LOGINUSER}"@planka.local \
        -e DEFAULT_ADMIN_PASSWORD="${ACTPASSWORD}" \
        -e DEFAULT_ADMIN_NAME=Admin \
        -e DEFAULT_ADMIN_USERNAME=admin \
        -v "${DOCPATH}"/planka/user-avatars:/app/public/user-avatars \
        -v "${DOCPATH}"/planka/project-background-images:/app/public/project-background-images \
        -v "${DOCPATH}"/planka/attachments:/app/private/attachments \
        ghcr.io/plankanban/planka:latest >/dev/null 2>&1 &&
        log_success "Planka created successfully" || log_error "Failed to create Planka"
}

create_portainer() {
    echo -e "\t\tCreating Portainer"
    docker run -d \
        --name Portainer \
        --hostname portainer \
        --restart "${DOCKERSTART}" \
        -p "$ALLOWEDIPS":"$PORTAINERPORT":9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        portainer/portainer-ce:latest >/dev/null 2>&1 &&
        log_success "Portainer created successfully" || log_error "Failed to create Portainer"
}

create_homer() {
    echo -e "\t\tCreating Homer"
    docker run -d \
        --name Homer \
        --hostname homer \
        --restart "${DOCKERSTART}" \
        -p "$HOMERPORT":8080 -u 0:0 -v "${DOCPATH}"/homer:/www/assets:rw -v "${DOCPATH}"/homer/tools:/www/assets/tools:rw \
        -e INIT_ASSETS=1 \
        b4bz/homer:latest >/dev/null 2>&1 &&
        log_success "Homer created successfully" || log_error "Failed to create Homer"
}

create_vaultwarden() {
    echo -e "\t\tCreating VaultWarden Cert Folder"
    mkdir -p "${DOCPATH}"/vaultwarden/ssl
    echo -e "\t\tCreating VaultWarden Self-Sign SSL Certificates"
    openssl req -nodes -x509 -newkey rsa:4096 -keyout "${DOCPATH}"/vaultwarden/ssl/bitwarden.key -out "${DOCPATH}"/vaultwarden/ssl/bitwarden.crt -days 365 -subj "/C=CA/ST=Ontario/L=Ottawa/O=TF/CN=bitwarden.local" >/dev/null 2>&1 && log_success "Created SSL Certificates" || log_error "Failed to create SSL Certificates"

    # Replace your Argon Key here with a new one using https://argon2.online/
    ls "${DOCPATH}"/vaultwarden/ssl/
    echo -e "\t\tCreating VaultWarden"
    docker run -d \
        --name VaultWarden \
        --hostname vaultwarden \
        --restart "${DOCKERSTART}" \
        -e SIGNUPS_ALLOWED=true \
        -e INVITATIONS_ALLOWED=true \
        -e DISABLE_ADMIN_TOKEN=false \
        -e ADMIN_TOKEN='$argon2i$v=19$m=1024,t=1,p=2$em5qbXZ0OWtxQjcySHFINA$4ru65itAqedJVRs2C23JkQ' \
        -e WEBSOCKET_ENABLED=false \
        -p "$VAULTPORT":80 \
        -e ROCKET_TLS='{certs="/ssl/bitwarden.crt",key="/ssl/bitwarden.key"}' \
        -v "${DOCPATH}"/vaultwarden/data:/data/:rw \
        -v "${DOCPATH}"/vaultwarden/ssl:/ssl/:rw \
        vaultwarden/server:latest >/dev/null 2>&1 &&
        log_success "VaultWarden created successfully" || log_error "Failed to create VaultWarden"
}

create_dfir_iris() {
    echo -e "\t\tCreating DFIR-IRIS"
    git clone https://github.com/dfir-iris/iris-web.git "${DOCPATH}/iris-web" >/dev/null 2>&1
    cd "${DOCPATH}"/iris-web || exit
    git checkout v2.4.12 >/dev/null 2>&1 && log_success "Checked out DFIR-IRIS v2.4.12" || log_error "Failed to checkout DFIR-IRIS v2.4.12"
    cp .env.model .env
    sed -i "s/#IRIS_ADM_USERNAME=administrator/IRIS_ADM_USERNAME=$LOGINUSER/" ./.env
    sed -i "s/#IRIS_ADM_PASSWORD=MySuperAdminPassword!/IRIS_ADM_PASSWORD=$ACTPASSWORD/" ./.env
    sed -i "s/INTERFACE_HTTPS_PORT=443/INTERFACE_HTTPS_PORT=$DFIRIRISPORT/" ./.env
    docker compose pull >/dev/null 2>&1 && log_success "Pulled DFIR-IRIS" || log_error "Failed to pull DFIR-IRIS"
    docker compose up -d >/dev/null 2>&1 && log_success "DFIR-IRIS created successfully" || log_error "Failed to create DFIR-IRIS"
    cd ../..
}

create_paperless() {
    echo -e "\t\tCreating Paperless"
    #docker volume create paperless_{data, media, pgdata, redisdata}
    docker run -d \
        --name Paperless-Redis \
        --hostname paperless-redis \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -v "${DOCPATH}"/paperless/redisdata:/data \
        docker.io/library/redis:7 >/dev/null 2>&1 &&
        log_success "Paperless-Redis created successfully" || log_error "Failed to create Paperless-Redis"
    chmod -R 777 "${DOCPATH}"/paperless/redisdata

    docker run -d \
        --name Paperless-DB \
        --hostname paperless-db \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB -v "${DOCPATH}"/paperless/pgdata:/var/lib/postgresql/data \
        -e POSTGRES_DB=paperless \
        -e POSTGRES_USER=paperless \
        -e POSTGRES_PASSWORD=paperless \
        docker.io/library/postgres:16 >/dev/null 2>&1 &&
        log_success "Paperless-DB created successfully" || log_error "Failed to create Paperless-DB"

    docker run -d \
        --name Paperless-NGX \
        --hostname paperless-ngx \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$PAPERLESSPORT":8000 -v "${DOCPATH}"/paperless/data:/usr/src/paperless/data -v "${DOCPATH}"/paperless/media:/usr/src/paperless/media -v "${DOCPATH}"/paperless/export:/usr/src/paperless/export -v "${DOCPATH}"/paperless/consume:/usr/src/paperless/consume \
        -e PAPERLESS_REDIS=redis://Paperless-Redis:6379 \
        -e PAPERLESS_DBHOST=Paperless-DB \
        -e PAPERLESS_OCR_LANGUAGE=eng \
        -e USERMAP_UID=1000 \
        -e USERMAP_GID=1000 \
        -e PAPERLESS_OCR_LANGUAGES=fra \
        ghcr.io/paperless-ngx/paperless-ngx:latest >/dev/null 2>&1 &&
        log_success "Paperless-NGX created successfully" || log_error "Failed to create Paperless-NGX"
    #-e PAPERLESS_URL=https://paperless.example.com
    #-e PAPERLESS_SECRET_KEY=change-me
}

create_llm_gpu_cuda() {
    ## Set up the repository for Docker Engine
    app_list=(
        apt-transport-https
        ca-certificates curl
        software-properties-common)
    for app in "${app_list[@]}"; do sudo apt-get install -y "$app" >/dev/null 2>&1; done
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    ## Install Docker Engine
    sudo apt-get update >/dev/null 2>&1
    app_list=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-compose
    )
    for app in "${app_list[@]}"; do sudo apt-get install -y "$app" >/dev/null 2>&1; done

    ## Add user to docker group
    sudo usermod -aG docker "$USER"
    sudo service docker start

    distribution=$(
        . /etc/os-release
        echo "$ID""$VERSION_ID"
    )
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/"$distribution"/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y nvidia-docker2 >/dev/null 2>&1
    sudo apt-get install -y nvidia-container-runtime >/dev/null 2>&1
    sudo apt-get install -y nvidia-utils-550 >/dev/null 2>&1
    sudo systemctl restart docker >/dev/null 2>&1

    # Create Ollama LLM and OpenWebUI
    # https://github.com/ollama/ollama
    echo -e "\t\tCreating Ollama LLM"
    docker run -d \
        --name Ollama-LLM \
        --hostname ollama-llm \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --gpus=all \
        -v "${DOCPATH}"/ollama:/root/.ollama \
        -p 11434:11434 \
        ollama/ollama >/dev/null 2>&1 &&
        log_success "Ollama-LLM created successfully" || log_error "Failed to create Ollama-LLM"

    # https://github.com/open-webui/open-webui
    echo -e "\t\tCreating OpenWebUI"
    docker run -d \
        --name Ollama-WebUI \
        --hostname ollama-webui \
        --restart "${DOCKERSTART}" \
        --gpus all \
        --add-host=host.docker.internal:host-gateway \
        -p "$ALLOWEDIPS":"$OPENWEBUIPORT":8080 \
        -v ./open-webui:/app/backend/data \
        ghcr.io/open-webui/open-webui:cuda >/dev/null 2>&1 &&
        log_success "OpenWebUI created successfully" || log_error "Failed to create OpenWebUI"
    #nvidia-smi

    sudo apt-get update  >/dev/null 2>&1 && sudo apt-get install -y nvidia-container-toolkit >/dev/null 2>&1
    sudo nvidia-ctk runtime configure --runtime=docker >/dev/null 2>&1

    sudo docker run --rm --runtime=nvidia --gpus all ubuntu \
        nvidia-smi >/dev/null 2>&1 &&
        log_success "Docker Nvidia-SMI is working" || log_error "Docker Nvidia-SMI is not working"

    echo '#!/bin/bash' | sudo tee /usr/local/bin/dockercuda
    printf 'sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi' | sudo tee -a /usr/local/bin/dockercuda
    sudo chmod +x /usr/local/bin/dockercuda
    echo "You can use the 'dockercuda' or 'nvidia-smi' command to check if the GPU is working."
}

create_ocr() {
    docker build -t ollama-ocr "${DOCPATH}"/OCR/  >/dev/null 2>&1
    docker run -d \
        --name Ollama-OCR \
        --hostname ollama-ocr \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB -v "${DOCPATH}"/OCR/html:/var/www/html:rw \
        -p "$ALLOWEDIPS":"$OCRPORT":5000 \
        ollama-ocr >/dev/null 2>&1 &&
        log_success "Ollama-OCR created successfully" || log_error "Failed to create Ollama-OCR"
}

create_drawio() {
    # https://github.com/jgraph/drawio
    echo -e "\t\tCreating Draw.io"
    docker run -d \
        --name Draw.io \
        --hostname drawio \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        -p "$ALLOWEDIPS":"$DRAWIOPORT":8080 \
        jgraph/drawio:latest >/dev/null 2>&1 &&
        log_success "Draw.io created successfully" || log_error "Failed to create Draw.io"
}

create_photopea() {
    echo -e "\t\tCreating Photopea"
    docker run -d \
        --name Photopea \
        --hostname photopea \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        -p "$ALLOWEDIPS":"$PHOTOPEAPORT":8887 \
        eorendel/photopea:latest >/dev/null 2>&1 &&
        log_success "Photopea created successfully" || log_error "Failed to create Photopea"
}

create_cyberchef() {
    # https://github.com/mpepping/docker-cyberchef
    echo -e "\t\tCreating CyberChef"
    docker run -d \
        --name CyberChef \
        --hostname cyberchef \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        -p "$ALLOWEDIPS":"$CYBERCHEFPORT":8000 \
        mpepping/cyberchef:latest >/dev/null 2>&1 &&
        log_success "CyberChef created successfully" || log_error "Failed to create CyberChef"
}

create_regex101() {
    # https://github.com/LoopSun/regex101-docker
    echo -e "\t\tCreating Regex101"
    docker run -d \
        --name Regex101 \
        --hostname regex101 \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        -p "$ALLOWEDIPS":"$REGEX101PORT":9090 \
        loopsun/regex101 >/dev/null 2>&1 &&
        log_success "Regex101 created successfully" || log_error "Failed to create Regex101"
}

create_ittools() {
    # https://it-tools.tech/docker-run-to-docker-compose-converter
    echo -e "\t\tCreating IT Tools"
    docker run -d \
        --name IT-Tools \
        --hostname it-tools \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        -p "$ALLOWEDIPS":"$ITTOOLSPORT":80 \
        corentinth/it-tools:latest >/dev/null 2>&1 &&
        log_success "IT Tools created successfully" || log_error "Failed to create IT Tools"
}

create_codimd() {
    # https://hackmd.io/c/codimd-documentation/%2Fs%2Fcodimd-docker-deployment
    # https://github.com/hackmdio/codimd
    echo -e "\t\tCreating Codimd DB"
    docker run -d \
        --name Codimd-DB \
        --hostname codimd-db \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB -v "${DOCPATH}"/codimd/db-data:/var/lib/postgresql/data:rw \
        -e POSTGRES_DB=codimd \
        -e POSTGRES_USER=codimd \
        -e POSTGRES_PASSWORD="${ACTPASSWORD}" \
        postgres:14-alpine >/dev/null 2>&1 &&
        log_success "Codimd-DB created successfully" || log_error "Failed to create Codimd-DB"

    echo -e "\t\tCreating Codimd"
    docker run -d \
        --name Codimd \
        --hostname codimd \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$ALLOWEDIPS":"$CODIMDPORT":3000 \
        -e CMD_DB_URL=postgres://codimd:"${ACTPASSWORD}"@Codimd-DB/codimd \
        -e CMD_USECDN=false \
        -v "${DOCPATH}"/codimd/uploads:/home/hackmd/app/public/uploads \
        hackmdio/hackmd:2.5.4 >/dev/null 2>&1 &&
        log_success "Codimd created successfully" || log_error "Failed to create Codimd"
}

create_n8n() {
    # https://github.com/n8n-io/n8n
    echo -e "\t\tCreating N8N"
    docker run -d \
        --name N8N \
        --hostname n8n \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$ALLOWEDIPS":"$N8NPORT":5678 \
        -e N8N_BASIC_AUTH_ACTIVE=true \
        -e N8N_SECURE_COOKIE=false \
        -e N8N_BASIC_AUTH_USER="${LOGINUSER}"@n8n.local \
        -e N8N_BASIC_AUTH_PASSWORD="${ACTPASSWORD}" \
        -v "${DOCPATH}"/n8n:/home/node/.n8n \
        n8nio/n8n:latest >/dev/null 2>&1 &&
        log_success "N8N created successfully" || log_error "Failed to create N8N"
}

create_gitlab() {
    # https://docs.gitlab.com/ee/install/docker/installation.html
    echo -e "\t\tCreating GitLab"
    docker run -d \
        --name GitLab \
        --hostname gitlab \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$ALLOWEDIPS":"$GITLABPORT":80 -v "${DOCPATH}"/gitlab/config:/etc/gitlab:rw \
        -v "${DOCPATH}"/gitlab/logs:/var/log/gitlab:rw \
        -v "${DOCPATH}"/gitlab/data:/var/opt/gitlab:rw gitlab/gitlab-ce:latest >/dev/null 2>&1 &&
        log_success "GitLab created successfully" || log_error "Failed to create GitLab"
}

create_etherpad() {
    # https://github.com/ether/etherpad-lite
    echo -e "\t\tCreating Etherpad"
    docker run -d \
        --name EtherPad \
        --hostname etherpad \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB --pids-limit 2048 \
        -e TZ=America/New_York \
        -e NODE_VERSION=22.8.0 \
        -e YARN_VERSION=1.22.22 \
        -e TIMEZONE= \
        -e NODE_ENV=production \
        -e ETHERPAD_PRODUCTION=1 \
        -p "$ALLOWEDIPS":"$ETHERPADPORT":9001 etherpad/etherpad >/dev/null 2>&1 &&
        log_success "Etherpad created successfully" || log_error "Failed to create Etherpad"
}

create_remmina() {
    # https://github.com/linuxserver/docker-remmina
    echo -e "\t\tCreating Remmina"
    docker run -d \
        --name Remmina \
        --hostname remmina \
        -e PUID=1000 \
        -e PGID=1000 \
        -e TZ=Etc/UTC \
        -p "$ALLOWEDIPS":"$REMMINAPORT":3000 \
        -p "$ALLOWEDIPS":3001:3001 -v "${DOCPATH}"/remmina/config:/config \
        --restart unless-stopped lscr.io/linuxserver/remmina:latest >/dev/null 2>&1 &&
        log_success "Remmina created successfully" || log_error "Failed to create Remmina"
}

create_b_b_shuffle() {
    # https://github.com/p3hndrx/B-B-Shuffle
    echo -e "\t\tCreating B-B-Shuffle"
    ## If you want to change the background image, you can replace the Orange-Background.png with your own image
    #cp Images/Orange-Background.png "${DOCPATH}"/B-B-Shuffle/App/img/page-back.png
    git clone https://github.com/p3hndrx/B-B-Shuffle.git "${DOCPATH}"/B-B-Shuffle >/dev/null 2>&1
    docker build -t b-b-shuffle "${DOCPATH}"/B-B-Shuffle/ >/dev/null 2>&1
    docker run -d \
        --name B-B-Shuffle \
        --hostname b-b-shuffle \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        -p "$ALLOWEDIPS":"${BBSHUFFLEPORT}":80 -v "${DOCPATH}"/B-B-Shuffle/html:/var/www/html:rw b-b-shuffle >/dev/null 2>&1 &&
        log_success "B-B-Shuffle created successfully" || log_error "Failed to create B-B-Shuffle"
}

create_stego_toolkit() {
    # https://github.com/DominicBreuker/stego-toolkit
    echo -e "\t\tCreating Stego-Toolkit"
    git clone https://github.com/DominicBreuker/stego-toolkit.git "${DOCPATH}"/stego-toolkit
    docker pull dominicbreuker/stego-toolkit:latest &&
        log_success "Stego-Toolkit pulled successfully" || log_error "Failed to pull Stego-Toolkit"
    #docker build -t stego-toolkit "${DOCPATH}"/stego-toolkit/
    #docker run -d --name Stego-Toolkit --hostname stego-toolkit --restart "${DOCKERSTART}" --network "${HALPNETWORK}" --network "${HALPNETWORK}"_DB -v "${DOCPATH}"/stego-toolkit:/root/stego-toolkit:rw stego-toolkit
    #docker run -it --rm -p 127.0.0.1:22:22 dominicbreuker/stego-toolkit /bin/bash -c "start_ssh.sh && ssh -X -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@localhost"
    #docker run -it --rm -p 127.0.0.1:6901:6901 dominicbreuker/stego-toolkit /bin/bash -c "start_vnc.sh && vncserver :1 -geometry 1280x800 -depth 24 && tail -f /root/.vnc/*:1.log"
    #docker run -d --name Stego-Toolkit --hostname stego-toolkit --restart "${DOCKERSTART}" --network "${HALPNETWORK}" --network "${HALPNETWORK}"_DB -p 6901:6901 -p 22:22 dominicbreuker/stego-toolkit
    # in browser, connect with: http://localhost:6901/?password=<password_from_start_vnc>
}

create_sift_remnux() {
    # Prompt the user if they want to build, pull the image from docker-hub, or skip
    echo -e "\t\tCreating SIFT-REMnux"
    echo -e "Building the image can take a while. Potentially 30-120 min. Pulling from Docker-Hub is faster."
    read -r -p "Do you want to build the image, pull from Docker-Hub, or skip? [b/p/S] (default: Skip): " build_pull_skip
    build_pull_skip=${build_pull_skip:-s}
    if [[ $build_pull_skip =~ ^[Bb][Uu][Ii][Ll][Dd]$ || $build_pull_skip =~ ^[Bb]$ ]]; then
        # Build the image
        echo "Building the image..."
        docker build -t sift-remnux -f "${DOCPATH}"/siftnux-docker/Dockerfile "${DOCPATH}"/siftnux-docker &&
            log_success "SIFT-REMnux built successfully" || log_error "Failed to build SIFT-REMnux"

        # Run the container
        docker run -d \
            --name SIFT-REMnux \
            --hostname sift-remnux \
            --restart "${DOCKERSTART}" \
            -p "$ALLOWEDIPS":33:22 -v "${DOCPATH}"/sift-remnux:/root sift-remnux >/dev/null 2>&1 &&
            log_success "SIFT-REMnux created successfully" || log_error "Failed to create SIFT-REMnux"

    elif [[ $build_pull_skip =~ ^[Pp][Uu][Ll][Ll]$ || $build_pull_skip =~ ^[Pp]$ ]]; then
        # Pull the image
        echo "Pulling the image..."
        docker pull digitalsleuth/sift-remnux:latest >/dev/null 2>&1 &&
            log_success "SIFT-REMnux pulled successfully" || log_error "Failed to pull SIFT-REMnux"

        # Run the container
        docker run -d \
            --name SIFT-REMnux \
            --hostname sift-remnux \
            --restart "${DOCKERSTART}" \
            -p "$ALLOWEDIPS":33:22 -v "${DOCPATH}"/sift-remnux:/root digitalsleuth/sift-remnux:latest >/dev/null 2>&1 &&
            log_success "SIFT-REMnux created successfully" || log_error "Failed to create SIFT-REMnux"

    else
        log_success "Skipping SIFT-REMnux setup."
    fi
}

create_vscode() {
    echo -e "\t\tCreating VSCode"
    docker run -d \
        --name VSCode \
        --hostname vscode \
        --restart "${DOCKERSTART}" \
        --network "${HALPNETWORK}" \
        --network "${HALPNETWORK}"_DB \
        -p "$ALLOWEDIPS":"$VSCODEPORT":8443 \
        -e PUID=1000 \
        -e PGID=1000 \
        -e PASSWORD="${ACTPASSWORD}" \
        -e HASHED_PASSWORD= \
        -e SUDO_PASSWORD="${ACTPASSWORD}" \
        -e SUDO_PASSWORD_HASH= \
        -e DEFAULT_WORKSPACE=/config/workspace \
        -v "${DOCPATH}"/vscode:/config \
        lscr.io/linuxserver/code-server:latest >/dev/null 2>&1 &&
        log_success "VSCode created successfully" || log_error "Failed to create VSCode"

    # Install extensions
    echo "Installing VSCode Extensions..."
    extensions=(
        esbenp.prettier-vscode
        ms-python.debugpy
        redhat.vscode-yaml
        redhat.vscode-xml
        gitlab.gitlab-workflow
        vscode-icons-team.vscode-icons
        yzhang.markdown-all-in-one
        mechatroner.rainbow-csv
        oderwat.indent-rainbow
        shd101wyy.markdown-preview-enhanced
        grapecity.gc-excelviewer
        bierner.markdown-mermaid
        bpruitt-goddard.mermaid-markdown-syntax-highlighting
        timonwong.shellcheck
        foxundermoon.shell-format
        y-ysss.cisco-config-highlight
        nopeslide.vscode-drawio-plugin-mermaid
        ms-vscode.live-server
        alanwalk.markdown-navigation
        davidanson.vscode-markdownlint
        devnullsp.mhtml2md
    )

    for extension in "${extensions[@]}"; do
        docker exec -it VSCode /app/code-server/bin/code-server --install-extension "$extension" 2>&1 &&
            log_success "Installed $extension" || log_error "Failed to install $extension"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    FUNC_LIST=(
        create_bookstack
        create_planka
        create_portainer
        create_homer
        create_vaultwarden
        create_dfir_iris
        create_paperless
        create_llm_gpu_cuda
        create_ocr
        create_drawio
        create_photopea
        create_cyberchef
        create_regex101
        create_ittools
        create_codimd
        create_n8n
        create_gitlab
        create_etherpad
        create_remmina
        create_b_b_shuffle
        create_stego_toolkit
        create_sift_remnux
        create_vscode
    )

    echo "The bash source is ${BASH_SOURCE[0]}"

    PS3="Select your option via Number: "
    options=("Install All" "${FUNC_LIST[@]}" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
        "Install All")
            for create_docker in "${FUNC_LIST[@]}"; do
                set_color
                echo && echo "Running $create_docker" | lolcat
                $create_docker
            done
            break
            ;;
        "Quit")
            break
            ;;
        *)
            if [[ " ${FUNC_LIST[*]} " == *" $opt "* ]]; then
                set_color
                echo && echo "Running $opt" | lolcat
                $opt
            else
                echo "Invalid option $REPLY"
            fi
            ;;
        esac
    done
fi
