#!/bin/bash

# Script Name: fastfetch.sh
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


# Initialize variables for options
SKIP_DEPENDENCY_CHECK=false
FORCE_REINSTALL=false

# Function to display help message
function show_help {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -f    Skip Dependency check"
  echo "  -i    Force reinstallation of fastfetch"
  echo "  -h    Show this help message"
}


# Parse options using getopts
while getopts ":fcri" opt; do
  case $opt in
    f)
      SKIP_DEPENDENCY_CHECK=true
      ;;
    i)
      FORCE_REINSTALL=true
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
    echo "This script must be run as root."
    exit 1
fi

# Detect architecture
ARCHITECTURE=$(uname -m)

# Map the architecture to the corresponding values used in the Fastfetch releases
case "$ARCHITECTURE" in
  aarch64) ARCHITECTURE="aarch64" ;;
  armv7l) ARCHITECTURE="armv7l" ;;
  x86_64) ARCHITECTURE="amd64" ;;
  ppc64le) ARCHITECTURE="ppc64le" ;;
  riscv64) ARCHITECTURE="riscv64" ;;
  *)
    echo "Unsupported architecture: $ARCHITECTURE"
    exit 1
    ;;
esac

# Internet connectivity check
if ! ping -c 1 -q github.com &>/dev/null; then
    echo "Internet connection is required. Please check your network."
    exit 1
fi

# Detect package manager (Debian/Ubuntu vs. RPM-based)
if command -v dpkg &> /dev/null; then
    # Debian/Ubuntu-based systems (use .deb)
    PACKAGE_TYPE="deb"
    PACKAGE_FILE="fastfetch-linux-$ARCHITECTURE.deb"
    INSTALL_CMD="sudo dpkg -i"
    
    # Detect if apt-get is available
    if command -v apt-get &> /dev/null; then
        FIX_CMD="sudo apt-get install -f"
        UPDATE_CMD="sudo apt-get update"
        PACKAGE_MANAGER="apt-get"
    elif command -v apt &> /dev/null; then
        FIX_CMD="sudo apt install -f"
        UPDATE_CMD="sudo apt update"
        PACKAGE_MANAGER="apt"
    else
        echo "Neither apt-get nor apt is available. Unable to fix dependencies."
        exit 1
    fi
elif command -v rpm &> /dev/null; then
    # RPM-based systems (use .rpm)
    PACKAGE_TYPE="rpm"
    PACKAGE_FILE="fastfetch-linux-$ARCHITECTURE.rpm"
    INSTALL_CMD="sudo rpm -i"
    
    # Detect if dnf or yum are available
    if command -v dnf &> /dev/null; then
        FIX_CMD="sudo dnf install -f"
        UPDATE_CMD="sudo dnf check-update"
        PACKAGE_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        FIX_CMD="sudo yum install -f"
        UPDATE_CMD="sudo yum check-update"
        PACKAGE_MANAGER="yum"
    else
        echo "Neither yum nor dnf are available. Unable to fix dependencies."
        exit 1
    fi
else
    echo "Unsupported package manager"
    exit 1
fi

# Detect if Dependencies are available
if command -v curl &> /dev/null && command -v jq &> /dev/null; then
    echo "Dependencies are already installed."
else
    echo "Dependencies missing, attempting to install curl, jq..."

    # Update the package list and attempt to install missing dependencies
    $UPDATE_CMD

    if [ "$PACKAGE_MANAGER" == "apt-get" ] || [ "$PACKAGE_MANAGER" == "apt" ]; then
        sudo $PACKAGE_MANAGER install -y curl jq
    elif [ "$PACKAGE_MANAGER" == "dnf" ] || [ "$PACKAGE_MANAGER" == "yum" ]; then
        sudo $PACKAGE_MANAGER install -y curl jq
    else
        echo "Package manager not recognized for installing dependencies."
        exit 1
    fi

    # Check if the dependencies were successfully installed
    if command -v curl &> /dev/null && command -v jq &> /dev/null; then
        echo "Dependencies installed successfully."
    else
        echo "Unable to install curl or jq."
        exit 1
    fi
fi


# Get the latest version of Fastfetch
VERSION=$(curl --silent "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" | jq -r .tag_name)

# Get the local version of fastfetch if installed
if command -v fastfetch &> /dev/null; then
  # fastfetch --version-raw prints just the verion number
  LOCAL_VERSION=$(fastfetch --version-raw)
  # Compare local version with the latest version
  if [ "$LOCAL_VERSION" == "$VERSION" ] && ! $FORCE_REINSTALL; then
    echo "fastfetch is already up-to-date (version $LOCAL_VERSION). Exiting."
    exit 0
  fi
else
  echo "fastfetch is not installed. Proceeding with installation."
fi

# Remove the old package file if it exists
if [ -f "$PACKAGE_FILE" ]; then
    rm "$PACKAGE_FILE"
fi

# Download the correct package based on the detected architecture and package type
# Use cURL with a simple progress bar instead of wget to minimize dependencies
curl -OL# "https://github.com/fastfetch-cli/fastfetch/releases/download/$VERSION/$PACKAGE_FILE"

# Install the package
$INSTALL_CMD "$PACKAGE_FILE"

# Update package list (for RPM-based systems, the update step is different)
$UPDATE_CMD

# Fix any missing dependencies if necessary (use the appropriate command for RPM-based systems)
$FIX_CMD

# Optionally, remove the package file after installation
rm "$PACKAGE_FILE"

