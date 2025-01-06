#!/bin/bash

echo "Running from file: $0"
echo
echo "--------------------------------------------------------------------------------------"

## Planka

echo "Replacing Planka Splash Screen Image..."
# Using SED, look in the file /app/public/static/css/main.*.css and not the main.*.css.map file and replace "../../static/media/*.jpg" with "../../static/media/cover.jpg"
    docker exec -it Planka bash -c "sed -i 's/..\/..\/static\/media\/.*.jpg/..\/..\/static\/media\/cover.jpg/g' /app/public/static/css/main.*.css"
# Copy an Image from project image to media cover to replace the Splash Screen Image.
    docker exec -it Planka bash -c "cp /app/public/project-background-images/HALp-Ai-1.jpg /app/public/static/media/cover.jpg"

## Replace DFIR-IRIS Logo and Blue Color to Orange
    echo "Replacing DFIR-IRIS Logo and Blue Color to Orange..."
docker exec -it iriswebapp_app bash -c "sed -i 's/#013479, #011d40/794d01, #b4770e/g' /iriswebapp/app/static/assets/css/login/login.css"
docker exec -it iriswebapp_app bash -c "sed -i 's/05316a/794d01/g' /iriswebapp/app/static/assets/css/login/login.css"

docker cp ./Images/iris-logo-white.png iriswebapp_app:/iriswebapp/app/static/assets/img/logo-white.png

## Remove Extra Apt Packages
echo "Removing Extra Apt Packages..."
sudo apt-get autoremove -y

# Restart Portainer
echo "Restarting Portainer..."
docker restart Portainer
