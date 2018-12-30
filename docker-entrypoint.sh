#!/bin/sh
# @author Michael Wiesendanger <michael.wiesendanger@gmail.com>
# @description launch script for nginx

# abort when trying to use unset variable
set -o nounset

echo "$(date) [INFO]: Starting nginx ..."
exec nginx -g "daemon off;"
