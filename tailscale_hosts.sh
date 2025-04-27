#!/bin/bash

# This script parses Tailscale status and adds hostnames and IP addresses
# to /etc/hosts.  It will remove all existing entries between the
# TAILSCALE_START and TAILSCALE_END markers before adding new entries.

# Get the Tailscale status in JSON format
status=$(tailscale status --json)

# Check if tailscale is running
if [[ -z "$status" ]]; then
  echo "Tailscale is not running or is not properly configured."
  exit 1
fi

# Parse the JSON output using jq
local_dns_name=$(echo "$status" | jq -r '.Self.DNSName')
local_hostname=$(echo "$local_dns_name" | cut -d '.' -f 1)
# Remove trailing dot from DNS name
local_dns_name=$(echo "$local_dns_name" | sed 's/\.$//')
tailscale_ip4=$(echo "$status" | jq -r '.Self.TailscaleIPs[0]')
tailscale_ip6=$(echo "$status" | jq -r '.Self.TailscaleIPs[1]')

# Remove existing Tailscale entries from /etc/hosts
sudo sed -i '/# TAILSCALE_START/,/# TAILSCALE_END/d' /etc/hosts

# Add the start marker
echo "# TAILSCALE_START" | sudo tee -a /etc/hosts > /dev/null

# Check if the hostname and IP addresses were successfully extracted
if [[ -z "$local_hostname" || -z "$tailscale_ip4" ]]; then
  echo "Failed to extract hostname or IPv4 address from Tailscale status."
  exit 1
fi

# Add local machine entries
if [[ -n "$tailscale_ip4" ]]; then
  echo "$tailscale_ip4 $local_hostname $local_dns_name" | sudo tee -a /etc/hosts > /dev/null
fi

if [[ -n "$tailscale_ip6" ]]; then
  echo "$tailscale_ip6 $local_hostname $local_dns_name" | sudo tee -a /etc/hosts > /dev/null
fi

# Loop through peers and add them to /etc/hosts
for peer_key in $(echo "$status" | jq -r '.Peer | keys[]'); do
  peer_dns_name=$(echo "$status" | jq -r ".Peer.\"${peer_key}\".DNSName")
  peer_hostname=$(echo "$peer_dns_name" | cut -d '.' -f 1)
  # Remove trailing dot from peer DNS name
  peer_dns_name=$(echo "$peer_dns_name" | sed 's/\.$//')
  peer_ip4=$(echo "$status" | jq -r ".Peer.\"${peer_key}\".TailscaleIPs[0]")
  peer_ip6=$(echo "$status" | jq -r ".Peer.\"${peer_key}\".TailscaleIPs[1]")

  if [[ -n "$peer_ip4" ]]; then
    echo "$peer_ip4 $peer_hostname $peer_dns_name" | sudo tee -a /etc/hosts > /dev/null
  fi

  if [[ -n "$peer_ip6" ]]; then
    echo "$peer_ip6 $peer_hostname $peer_dns_name" | sudo tee -a /etc/hosts > /dev/null
  fi
done

# Add the end marker
echo "# TAILSCALE_END" | sudo tee -a /etc/hosts > /dev/null

echo "Script completed."

exit 0
