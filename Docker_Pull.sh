#!/bin/bash

source ./Setup.sh

echo "Running from file: $0"

echo "--------------------------------------------------------------------------"
figlet -f slant -w 140 "   Pulling Containers" | lolcat
echo "--------------------------------------------------------------------------"

docker_pull_q() {
    # Step 1: Grep for Docker run commands and extract image names
    images=$(grep -oP '^[^-].*\/.*:?.*(?=>/dev/null 2>&1 &&)' ./Docker-Runs.sh | grep -v '^\s*-' | sort | uniq | grep -Ev "(openssl|docker compose|sudo|docker\s|pull\s|git checkout|git clone|git\s)")

    # Step 2: Prompt the user if they want to pull all these images
    echo "The following Docker images are used in Docker-Runs:"
    echo "--------------------------------------------------------"
    echo -e "\t Docker Images to pull"
    echo "--------------------------------------------------------"
    count=1
    for image in $images; do
        echo -e "\t$count. $image"
        count=$((count + 1))
    done
    echo "--------------------------------------------------------"
    read -r -p "Do you want to continue and check which docker images you have? (y/N): " pull_all

    if [[ "$pull_all" != "y" && "$pull_all" != "Y" && "$pull_all" != [yY].. ]]; then
        log_success "Exiting without pulling any images."
        echo "Exiting without pulling any images."
        #exit 0
    else
        # Step 3: Check which images do not exist locally
    missing_images=()
    for image in $images; do
        if ! docker image inspect "$image" > /dev/null 2>&1; then
            missing_images+=("$image")
        fi
    done

    # Step 4: Confirm with the user if they want to continue pulling the missing images
    if [ ${#missing_images[@]} -eq 0 ]; then
        echo "All images are already present locally."
        log_success "All images are already present locally."
    else
        echo "The following images are missing and need to be pulled:"
        count=1
        for image in "${missing_images[@]}"; do
            echo -e "\e[3$((count % 8))m\t\t$count. $image\e[0m"
            count=$((count + 1))
        done
        read -r -p "Do you want to continue pulling the missing images? (y/N): " pull_missing

        if [ "$pull_missing" != "y" ] && [ "$pull_missing" != "Y" ]; then
            log_success "Exiting without pulling any images."
            echo "Exiting without pulling any images."
            #exit 0
        fi

        # Pull the missing images
        for image in "${missing_images[@]}"; do
            if [ "$image" = "nvidia-smi" ]; then
            create_llm_install && log_success "nvidia-smi Pulled successfully" || log_error "Failed to pull nvidia-smi"
            fi
            echo -e "\e[3$((count % 8))mPulling image: $image\e[0m"
            docker pull "$image" > /dev/null &&
                log_success "$image Pulled successfully" || log_error "Failed to pull $image"
            count=$((count + 1))
        done
    fi

        echo "Docker images pull process completed."
    fi


}

docker_build_q() {
    echo "--------------------------------------------------------------------------"
    echo "--------------------------------------------------------------------------"
    # Step 5: Pull/Build all Building Images

    images=$(grep -oP 'docker build -t\s+\K\S+' ./Docker-Runs.sh | sort | uniq)

    echo "The following Docker images are built in Docker-Runs:"
    echo "--------------------------------------------------------"
    echo -e "\tDocker Images to build"

    count=1
    for image in $images; do
        echo -e "\t$count. $image"
        count=$((count + 1))
    done
    echo "--------------------------------------------------------"
    echo " These images can be build manually by running the following commands:"
    echo "--------------------------------------------------------"
    echo "$(grep -oP 'docker build -t \w.*/ ' ./Docker-Runs.sh | sort | uniq)"
    echo "--------------------------------------------------------"
    # Needs to be reworked
    read -p "Do you want to build all these Docker images? (y/n): " build_all

    if [ "$build_all" = "y" ]; then
        for image in $images; do
            echo "Building image: $image"
            build_a_docker() {
                docker build -t $image "${DOCPATH}"/$image/ &&
        log_success "$image Built successfully" || log_error "Failed to Build $image"
            }
            case $image in
                "stego-toolkit")
                    git clone https://github.com/DominicBreuker/stego-toolkit.git "${DOCPATH}"/stego-toolkit || true
                    build_a_docker
                    ;;
                "iris-web")
                    git clone https://github.com/dfir-iris/iris-web.git "${DOCPATH}/iris-web" || true
                    build_a_docker
                    ;;
                "b-b-shuffle")
                    git clone https://github.com/p3hndrx/B-B-Shuffle.git "${DOCPATH}"/b-b-shuffle || true
                    build_a_docker
                    ;;
                "sift-remnux")
                    git clone https://github.com/digitalsleuth/sift-remnux.git "${DOCPATH}"/sift-remnux || true
                    build_a_docker
                    ;;
                *)
                    echo "No specific instructions for $image. Attempting to build locally..."
                    build_a_docker
                    ;;
            esac
        done
    else
        echo "Exiting without building any images."
        #exit 0
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    docker_pull_q
    docker_build_q
fi
