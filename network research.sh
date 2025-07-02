#!/bin/bash

# Function to check if a tool is installed
is_installed() {
  command -v "$1" &>/dev/null
}

# Function to install a tool using apt-get (if not installed)
install_tool() {
  if ! is_installed "$1"; then
    echo "$1 is not installed. Installing..."
    sudo apt-get install -y "$1"
  else
    echo "$1 is already installed."
  fi
}

# Function to update the system package list
update_system() {
  echo "Updating the system..."
  sudo apt-get update
}

# Function to check if the network connection is anonymous
check_anonymity() {
  echo "Checking if the network is anonymous..."

  # Get the public IP address
  IP=$(curl -s ifconfig.me)

  if [[ -z "$IP" || "$IP" =~ "<html>" ]]; then
    echo "Unable to fetch your public IP. You are not anonymous."
    exit 1
  fi

  echo "Your IP address is: $IP"

  # Check the country using ipinfo.io
  COUNTRY=$(curl -s http://ipinfo.io/country)

  if [[ -z "$COUNTRY" ]]; then
    echo "Unable to determine country for IP: $IP. You are not anonymous."
    exit 1
  fi

  echo "Spoofed country: $COUNTRY"

  # Save the country to a log file
  LOG_FOLDER="/home/kali/Desktop/logs"
  mkdir -p "$LOG_FOLDER"
  echo "$COUNTRY" > "$LOG_FOLDER/target_country.log"

  # Check if the spoofed country is IL (Israel)
  if [ "$COUNTRY" == "IL" ]; then
    echo "You are not anonymous. Exiting..."
    exit 1
  fi
}

# Function to install necessary tools and check anonymity
install_and_check() {
  # Install necessary tools
  install_tool "curl"
  install_tool "whois"
  install_tool "nmap"

  # Check network anonymity
  check_anonymity
}

# Function to handle SSH connection and collect details
run_remote_script() {
  read -p "Enter the remote server IP: " REMOTE_SERVER
  read -p "Enter the remote server username: " REMOTE_USER
  read -sp "Enter SSH password for $REMOTE_USER@$REMOTE_SERVER: " SSH_PASS
  echo

  # Local log directory
  LOCAL_LOG_FOLDER="/home/kali/Desktop/logs"
  mkdir -p "$LOCAL_LOG_FOLDER"

  echo "Connecting to remote server and collecting details..."

  # Execute remote commands and save results locally
  sshpass -p "$SSH_PASS" ssh \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o StrictHostKeyChecking=no \
    "$REMOTE_USER@$REMOTE_SERVER" bash <<EOF
    # Fetch public IP
    echo "Public IP: $(curl -s ifconfig.me)"

    # Get country information using ipinfo.io
    echo "Country: $(curl -s http://ipinfo.io/country)"

    # Fetch system uptime and save to file
    echo "Fetching uptime..."
    uptime > /tmp/${REMOTE_SERVER}_uptime.txt

    # Get network interface details using ifconfig and save to file
    echo "Fetching ifconfig details..."
    if command -v ifconfig &>/dev/null; then
      ifconfig > /tmp/${REMOTE_SERVER}_ifconfig.txt
    else
      echo "ifconfig command not available." > /tmp/${REMOTE_SERVER}_ifconfig.txt
    fi

    # Run nmap scan and save the results
    echo "Running nmap scan on $REMOTE_SERVER..."
    nmap -sV -oN /tmp/scan_result_${REMOTE_SERVER}.txt $REMOTE_SERVER
EOF

  # Use scp to copy the uptime, ifconfig, and nmap scan results to the local logs directory
  echo "Downloading uptime, ifconfig, and nmap scan results to $LOCAL_LOG_FOLDER..."
  sshpass -p "$SSH_PASS" scp \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o StrictHostKeyChecking=no \
    "$REMOTE_USER@$REMOTE_SERVER:/tmp/${REMOTE_SERVER}_uptime.txt" "$LOCAL_LOG_FOLDER/${REMOTE_SERVER}_uptime.txt"

  sshpass -p "$SSH_PASS" scp \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o StrictHostKeyChecking=no \
    "$REMOTE_USER@$REMOTE_SERVER:/tmp/${REMOTE_SERVER}_ifconfig.txt" "$LOCAL_LOG_FOLDER/${REMOTE_SERVER}_ifconfig.txt"

  sshpass -p "$SSH_PASS" scp \
    -o PubkeyAcceptedAlgorithms=+ssh-rsa \
    -o HostKeyAlgorithms=+ssh-rsa \
    -o StrictHostKeyChecking=no \
    "$REMOTE_USER@$REMOTE_SERVER:/tmp/scan_result_${REMOTE_SERVER}.txt" "$LOCAL_LOG_FOLDER/scan_result_${REMOTE_SERVER}.txt"

  echo "Results saved to $LOCAL_LOG_FOLDER/"
}

# Main function to execute the script
main() {
  # Update system package list
  update_system

  # Install tools and check anonymity
  install_and_check

  # Run the remote interaction script
  run_remote_script

  echo "Script execution completed."
}

# Run the main function
main
