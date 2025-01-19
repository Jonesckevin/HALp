# **SIFT-REMnux**
SIFT and REMnux Docker based on Ubuntu 20.04 LTS 
~~22.04 LTS Does have some fails and would require `|| true` to skip failed programs~~

## **Build Docker**

**To build the docker using the dockerfile, run the following commands:**

```bash
## Clone the repo
git clone https://github.com/digitalsleuth/sift-remnux.git

## Change to the directory
cd sift-remnux

## Build the docker
docker build -t sift-remnux .

## Run the docker (Port 33 is your SSH port)
docker run -d -p 33:22 sift-remnux

## SSH into the docker
#ssh -X forensics@localhost -p 33
ssh -X forensics@$(hostname -I | awk '{print $1}') -p 33

```
**You can also interact with the docker using the following command:**
```bash
docker exec -it sift-remnux /bin/bash
```

**If you need or want access to a mapped folder, you can use the following command:**
```bash
mkdir {pwd}/files

docker run -d -p 33:22 -v {pwd}/files:/home/forensics sift-remnux
```

## **Running in Docker-Compose**

**To run the docker in docker-compose, use the following commands:**

```bash
## Clone the repo
git clone https://github.com/digitalsleuth/sift-remnux.git

## Change to the directory
cd sift-remnux

## Run the docker-compose
docker-compose up -d
```

I reccomend using SSH using the MOBAXTERM or another SSH client that supports X11 forwarding.

This will provide GUI functionality from within the docker.
