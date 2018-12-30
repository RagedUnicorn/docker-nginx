#!/bin/bash
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description build script for docker-nginx container

# abort when trying to use unset variable
set -o nounset

WD="${PWD}"

# variable setup
DOCKER_NGINX_TAG="ragedunicorn/nginx"
DOCKER_NGINX_NAME="nginx"

# get absolute path to script and change context to script folder
SCRIPTPATH="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
cd "${SCRIPTPATH}"

echo "$(date) [INFO]: Building container: ${DOCKER_NGINX_NAME}"

# build mysql container
docker build -t "${DOCKER_NGINX_TAG}" ../

cd "${WD}"
