#!/bin/bash

# Script Name: portainer.sh
# Copyright (C) 2025 darkexplosiveqwx
# Last updated: 19. January 2025
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Variables
CONTAINER_NAME="portainer"
IMAGE_NAME="portainer/portainer-ce"
PORTAINER_WEB_PORT="9000"
DATA_DIRECTORY=/volume1/docker/portainer

# Function to display help message
function show_help {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -n    Specify Container name. Default: $CONTAINER_NAME"
  echo "  -p    Specify web interface port (1-65535). Default: $PORTAINER_WEB_PORT"
  echo "  -d    Specify Data Directory. Default: $DATA_DIRECTORY"
  echo "  -h    Show this help message"
}

# Validate port number (1-65535)
function validate_port {
  local port=$1
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Error: Invalid port number: $port. Port must be between 1 and 65535."
    show_help
    exit 1
  fi
}

# Parse options using getopts
while getopts ":n:p:d:h" opt; do
  case $opt in
    n)
      CONTAINER_NAME="$OPTARG"
      ;;
    p)
      PORTAINER_WEB_PORT="$OPTARG"
      validate_port "$PORTAINER_WEB_PORT"  # Validate the port after parsing
      ;;
    d)
      DATA_DIRECTORY="$OPTARG"
      ;;
    h)
      show_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      show_help
      exit 1
      ;;
  esac
done


# Ensure the script runs as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Re-running with sudo..."
    exec sudo "$0" "$@"
    exit
fi

# Ensure the data directory exists
if [ ! -d "$DATA_DIRECTORY" ]; then
    echo "Warning: Data directory $DATA_DIRECTORY does not exist. Creating it..."
    sudo mkdir -p "$DATA_DIRECTORY" || { echo "Error: Failed to create directory $DATA_DIRECTORY"; exit 1; }
    echo "Created directory: $DATA_DIRECTORY"
fi

# Check if the Portainer container exists
container_status=$(sudo docker ps -a --format '{{.Names}}' | grep "^$CONTAINER_NAME$")
if [ -n "$container_status" ]; then
    echo "Portainer container exists."
    if sudo docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        echo "Portainer container is running. Stopping it..."
        sudo docker stop "$CONTAINER_NAME" || { echo "Error: Failed to stop container $CONTAINER_NAME"; exit 1; }
    fi
    echo "Removing the Portainer container..."
    sudo docker rm "$CONTAINER_NAME" || { echo "Error: Failed to remove container $CONTAINER_NAME"; exit 1; }
else
    echo "No existing Portainer container found."
fi

# Pull the latest Portainer image
echo "Pulling the latest Portainer CE image..."
sudo docker pull "$IMAGE_NAME" || { echo "Error: Failed to pull the Portainer image"; exit 1; }

# Deploy a new Portainer container
echo "Deploying a new Portainer container..."
sudo docker run -d --name "$CONTAINER_NAME" \
  -p "$PORTAINER_WEB_PORT:9000" \
  -p 8000:8000 \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$DATA_DIRECTORY:/data" \
  "$IMAGE_NAME" || { echo "Error: Failed to deploy Portainer container"; exit 1; }

  
  # Check if the new container is running
if sudo docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "Portainer container has been successfully deployed and is running."
  echo "Access Portainer at: http://localhost:$PORTAINER_WEB_PORT"
else
  echo "Failed to deploy the Portainer container."
  exit 1
fi
