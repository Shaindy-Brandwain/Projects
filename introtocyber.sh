#!/bin/bash

# Ask for the filename
read -p "Enter the name of the output file (without extension): " FILE_NAME
OUTPUT_FILE="${FILE_NAME}.txt"

# Check and set the correct network interface
INTERFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$INTERFACE" ]; then
    echo "Error: Could not detect active network interface."
    exit 1
fi

# Enable promiscuous mode
sudo ip link set $INTERFACE promisc on

echo "=== Network Mapping ===" | tee $OUTPUT_FILE

# Get Internal & External IP
INTERNAL_IP=$(hostname -I | awk '{print $1}')
EXTERNAL_IP=$(curl -s https://api64.ipify.org)

echo "Internal IP Address: $INTERNAL_IP" | tee -a $OUTPUT_FILE
echo "External IP Address: $EXTERNAL_IP" | tee -a $OUTPUT_FILE

# Get Router Name
ROUTER_NAME=$(nmap -O $INTERNAL_IP | grep "Device type" | awk -F: '{print $2}' | xargs)
if [ -z "$ROUTER_NAME" ]; then
    ROUTER_NAME=$(nbtscan -r $INTERNAL_IP | awk '{print $2}' | head -n 1)
fi
echo "Router Name: ${ROUTER_NAME:-Unknown}" | tee -a $OUTPUT_FILE

# MAC Addresses and Vendors
echo "MAC Addresses and Vendors:" | tee -a $OUTPUT_FILE
arp -a | awk '{print $1, $4}' | tee -a $OUTPUT_FILE

# ISP, DNS, DHCP
ISP_INFO=$(whois $EXTERNAL_IP | grep -E "descr|netname" | head -n 3)
DNS_INFO=$(cat /etc/resolv.conf | grep "nameserver" | awk '{print $2}')
echo "ISP: $ISP_INFO" | tee -a $OUTPUT_FILE
echo "DNS Servers: $DNS_INFO" | tee -a $OUTPUT_FILE
echo "DHCP: $DHCP_INFO" |tee -a $OUTPUT_FILE

# Connection Type
CONNECTION_TYPE=$(nmcli -t -f DEVICE,TYPE,STATE connection show --active | grep -E 'wifi|ethernet' | awk -F: '{print $2}')
echo "Connection Type: ${CONNECTION_TYPE:-Unknown}" | tee -a $OUTPUT_FILE

echo "=== Information Gathering ===" | tee -a $OUTPUT_FILE

# Use the stored API key securely
SHODAN_API_KEY=${SHODAN_API_KEY:-"MISSING_KEY"}

if [[ "$SHODAN_API_KEY" != "MISSING_KEY" ]]; then
    echo "Fetching Shodan info for $EXTERNAL_IP..." | tee -a $OUTPUT_FILE
    SHODAN_RESULT=$(curl -s "https://api.shodan.io/shodan/host/$EXTERNAL_IP?key=$OeGMYIURpvF3LDQX9pg0W7JEAheGx6dy")
    
    # Extract key information from JSON output
    OPEN_PORTS=$(echo "$SHODAN_RESULT" | jq '.ports')
    OS_INFO=$(echo "$SHODAN_RESULT" | jq -r '.os // "Unknown"')
    ISP=$(echo "$SHODAN_RESULT" | jq -r '.isp')
    
    echo "Shodan Results:" | tee -a $OUTPUT_FILE
    echo "Open Ports: $OPEN_PORTS" | tee -a $OUTPUT_FILE
    echo "Operating System: $OS_INFO" | tee -a $OUTPUT_FILE
    echo "ISP: $ISP" | tee -a $OUTPUT_FILE
else
    echo "Warning: No Shodan API key found. Skipping lookup..." | tee -a $OUTPUT_FILE
fi

# WHOIS Lookup
echo "WHOIS Information for $EXTERNAL_IP:" | tee -a $OUTPUT_FILE
whois $EXTERNAL_IP | head -n 20 | tee -a $OUTPUT_FILE

# Protocol Sniffing (10 seconds per port)
echo "=== Protocol Sniffing ===" | tee -a $OUTPUT_FILE
PORTS=(80 21 53)  # List of ports to monitor

for PORT in "${PORTS[@]}"; do
    echo "Sniffing traffic on port $PORT for 10 seconds..." | tee -a $OUTPUT_FILE
    sudo timeout 10 tcpdump -i $INTERFACE port $PORT -nn -q | tee -a $OUTPUT_FILE
    echo "Finished sniffing on port $PORT." | tee -a $OUTPUT_FILE
done

echo "Results saved to: $OUTPUT_FILE"
echo "Script Execution Complete!"
