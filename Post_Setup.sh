#!/bin/bash

source ./Setup.sh

echo "Running from file: $0"

echo "--------------------------------------------------------------------------"
figlet -f slant -w 140 "   Post Setup" | lolcat
echo "--------------------------------------------------------------------------"

## Planka

echo "Replacing Planka Splash Screen Image..."
# Using SED, look in the file /app/public/static/css/main.*.css and not the main.*.css.map file and replace "../../static/media/*.jpg" with "../../static/media/cover.jpg"
    docker exec -it Planka bash -c "sed -i 's/..\/..\/static\/media\/.*.jpg/..\/..\/static\/media\/cover.jpg/g' /app/public/static/css/main.*.css" && log_success "Planka Splash Screen Image Replaced Successfully" || log_error "Failed to Replace Planka Splash Screen Image"
# Copy an Image from project image to media cover to replace the Splash Screen Image.
    docker exec -it Planka bash -c "cp /app/public/project-background-images/HALp-Ai-1.jpg /app/public/static/media/cover.jpg" && log_success "Planka Splash Screen Image Copied Successfully" || log_error "Failed to Copy Planka Splash Screen Image"

## Replace DFIR-IRIS Logo and Blue Color to Orange
    echo "Replacing DFIR-IRIS Logo and Blue Color to Orange..."
docker exec -it iriswebapp_app bash -c "sed -i 's/#013479, #011d40/794d01, #b4770e/g' /iriswebapp/app/static/assets/css/login/login.css" && log_success "DFIR-IRIS Logo and Blue Color Replaced Successfully" || log_error "Failed to Replace DFIR-IRIS Logo and Blue Color"
docker exec -it iriswebapp_app bash -c "sed -i 's/05316a/794d01/g' /iriswebapp/app/static/assets/css/login/login.css" && log_success "DFIR-IRIS Logo and Blue Color Replaced Successfully" || log_error "Failed to Replace DFIR-IRIS Logo and Blue Color"

docker cp ./Images/iris-logo-white.png iriswebapp_app:/iriswebapp/app/static/assets/img/logo-white.png && log_success "DFIR-IRIS Logo Copied Successfully" || log_error "Failed to Copy DFIR-IRIS Logo"

## Remove Extra Apt Packages
echo "Removing Extra Apt Packages..."
sudo apt-get autoremove -y > /dev/null &&
    log_success "Extra Apt Packages Removed Successfully" || log_error "Failed to Remove Extra Apt Packages"

# Restart Portainer
echo "Restarting Portainer..."
docker restart Portainer > /dev/null &&
    log_success "Portainer Restarted Successfully" || log_error "Failed to Restart Portainer"

