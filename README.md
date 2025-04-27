# Scripts
Collection of scripts I regularly run on multiple of my machines
## fastfetch.sh
Installs and updates [Fastfetch](https://github.com/fastfetch-cli/fastfetch) on Debian- and RHEL-based distributions using the latest release from GitHub.
For uses see ```./fastfetch --help```.
## 40_reboot_poweroff
Adds "Poweroff" and "Reboot" entries to GRUB.   
Place it in ```/etc/grub.d``` and make it executable ```chmod +x /etc/grub.d/40_reboot_poweroff```.
## portainer.sh
Creates and updates a Docker container running [Portainer](https://www.portainer.io/), optimized for use on Synology NAS.
Usage: ```sudo ./portainer.sh -n [Container Name, default:portainer] -p [Port for Web Interface, default:9000] -d [Data directory, default:/volume1/docker/portainer]```
## tailscale_hosts.sh
Adds and updates hostnames and domains of devices in the current tailnet to `/etc/hosts`