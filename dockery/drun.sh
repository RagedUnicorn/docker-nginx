#!/bin/bash
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description run script for docker-nginx container

# abort when trying to use unset variable
set -o nounset

WD="${PWD}"

# variable setup
DOCKER_NGINX_TAG="ragedunicorn/nginx"
DOCKER_NGINX_NAME="nginx"
DOCKER_NGINX_ID=0

# get absolute path to script and change context to script folder
SCRIPTPATH="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "${SCRIPTPATH}"

# check if there is already an image created
docker inspect ${DOCKER_NGINX_NAME} &> /dev/null

if [ $? -eq 0 ]; then
  # start container
  docker start "${DOCKER_NGINX_NAME}"
else
  ## run image:
  # -p expose port
  # -d run in detached mode
  # --name define a name for the container(optional)
  DOCKER_NGINX_ID=$(docker run \
  -p 80:80 \
  -dit \
  --name "${DOCKER_NGINX_NAME}" "${DOCKER_NGINX_TAG}")
fi

if [ $? -eq 0 ]; then
  # print some info about containers
  echo "$(date) [INFO]: Container info:"
  docker inspect -f '{{ .Config.Hostname }} {{ .Name }} {{ .Config.Image }} {{ .NetworkSettings.IPAddress }}' ${DOCKER_NGINX_NAME}
else
  echo "$(date) [ERROR]: Failed to start container - ${DOCKER_NGINX_NAME}"
fi

cd "${WD}"
