#!/bin/bash
# Surgat Ramos 0.2.5

BLUE='\033[0;34m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m' 
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
GRAY='\033[0;37m'
LIGHT_BLUE='\033[1;34m'
LIGHT_GREEN='\033[1;32m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_RED='\033[1;31m'
LIGHT_CYAN='\033[1;36m'
LIGHT_PURPLE='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No color

ipvictima=$1
nombre=$2

# Function to validate if a string is an IP address
is_valid_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to handle the interrupt signal (CTRL+C)
handle_interrupt() {
    echo
    read -p "Are you sure you want to exit? (y/n): " confirm
    if [ "$confirm" == "y" ]; then
        exit 0
    fi
}

# Assign the interrupt signal handling function to the SIGINT signal (CTRL+C)
trap handle_interrupt SIGINT

figlet The Player
echo "                           Surgat"

if [ -z "$ipvictima" ] || [ -z "$nombre" ]; then
    echo "Usage: ./theplayer.sh <IP> <NAME OF MACHINE>"
    echo "Example: ./theplayer.sh 10.10.10.129 easymachine"
    exit 1
fi

if ! is_valid_ip $ipvictima; then
    echo "Invalid IP address. The first argument should be a valid IP address."
    exit 1
fi

if ! [[ $nombre =~ ^[[:alpha:]]+$ ]]; then
    echo "Invalid name. The second argument should be a word."
    exit 1
fi

echo -e "${LIGHT_BLUE}[+]       Pinging victim IP... ${NC}"
while ! is_valid_ip $ipvictima || ! ping -c 1 $ipvictima >/dev/null; do
    echo "Ping unsuccessful. Retrying in 1 second..."
    sleep 1
done

echo -e "${LIGHT_BLUE}[+]       Fast Scan... ${NC}"
sudo nmap -T4 -F $ipvictima
echo -e "${YELLOW}                80/443 port... Time to Firefox and Burpsuite Manually${NC}"

echo -e "${LIGHT_BLUE}[-]       Starts complete NMAP... search all open ports${NC}"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo -e "${LIGHT_BLUE}[+]       Complete NMAP... analizing open ports${NC}"
echo $ports

# Verify ports 80.443 is opens http https
if echo "$ports" | grep -q "80\|443"; then
    echo -e "${YELLOW}[+] Find 80 and 443 ports open in IP $ipvictima${NC}"
    echo -e "${GREEN}You should run nikto in other terminal${NC}"
    echo -e "${GREEN}nikto -h http://$ipvictima -C all${NC}"
    echo ""
    echo -e "${GREEN}nikto -h https://$ipvictima -C all${NC}"
    echo ""
    echo "-----------------------"
    echo -e "${LIGHT_CYAN}[+]          Curl to IP $ipvictima${NC}"
    echo -e "${YELLOW}"
    curl -vvv $ipvictima
    echo -e "${NC}"
fi

# Verify ports 139 o 445 are open smb
if echo "$ports" | grep -q "139\|445"; then
    echo -e "${GREEN}[+] Find 139 o 445 open, en IP $ipvictima${NC}"
    echo -e "${YELLOW}[-] Runing enumeration SMB withowt Credentials${NC}"
    nbtscan $ipvictima
    smbmap -H $ipvictima
    smbmap -H $ipvictima -u null -p null
    smbmap -H $ipvictima -u guest
    smbclient -N -L //$ipvictima
    crackmapexec smb $ipvictima
    crackmapexec smb $ipvictima --pass-pol -u "" -p ""
    crackmapexec smb $ipvictima --pass-pol -u guest
fi
echo -e "${LIGHT_CYAN}[+]       launch NMAP -sV -sC -Pn ${NC}"
nmap -p$ports -sV -sC -Pn $ipvictima -oX ResultNmap$nombre

# Searching hostnames in Nmap output
echo -e "${YELLOW}[+] Searching for hostnames in Nmap output...${NC}"
hostnames=$(xmllint --xpath '//host/hostnames/hostname/@name' ResultNmap$nombre | sed -n 's/ name="\([^"]*\)"/\1/p')

for hostname in $hostnames; do
    if ! grep -q "$hostname" /etc/hosts; then
        echo ""
        echo -e "${GREEN}       Adding ${YELLOW} $hostname ${GREEN}to /etc/hosts ${NC}"
        echo "$ipvictima $(dig +short "$hostname") $nombre.htb # added by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo ""
        echo -e "${GREEN}        Skipping${YELLOW} $hostname ${GREEN}because it already exists in /etc/hosts${NC}"
    fi
done

if [ -z "$hostnames" ]; then
    echo -e "${LIGHT_CYAN}No hostnames found in the results of Nmap.${NC}"
else
    echo ""
    echo -e "${YELLOW}[+]   Hostnames found:${NC}"
    echo "$hostnames"
fi
    for host in $hostnames; do
        echo ""
        echo -e "${LIGHT_CYAN}[+]       Curl to $hostname${NC}"
        curl -vvv $hostname
        echo ""
        echo -e "${LIGHT_CYAN}[+]       Directory and archive fuzz (wfuzz combined_words) $hostname${NC}"
        echo ""
        wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u "$hostname/FUZZ"
        echo ""
        echo -e "${LIGHT_CYAN}[+]       Subdomain Virtualhosts fuzz (wfuzz combined_subdomains) $hostname ${NC}"
        echo ""
        wfuzz -c -w /usr/share/wordlists/seclists/Discovery/DNS/combined_subdomains.txt --hc 400,404,403 -H "Host: FUZZ.$hostname" -u http://$hostname -t 100
    done

foldername="ftp$nombre"
# Find the <port> tag with the attribute portid="21" and state="open"
port_info=$(xmllint --xpath '//port[@portid="21" and state/@state="open"]' ResultNmap$nombre)

# Check if the <port> tag was found.
if [[ -n $port_info ]]; then
  # Search if anonymous login is allowed in the <script> tag with id="ftp-anon"
  anon_login=$(echo "$port_info" | grep -o 'Anonymous FTP login allowed')

  if [[ -n $anon_login ]]; then
    echo -e "${GREEN}Port 21 is open and anonymous login is allowed.${NC}"
    echo -e "${LIGHT_BLUE}      Downloading FTP content...${NC}"

    # FTP content download
    wget --user=anonymous --password=anonymous -r "ftp://$ipvictima" -P "$foldername"
    echo -e "${GREEN}FTP content downloaded to $foldername${NC}"
  else
    echo -e "${BLUE}[-] Port 21 is open but anonymous login is not allowed.${NC}"
  fi
else
  echo -e "${BLUE}[-] Port 21 is not open.${NC}"
fi
echo " "
echo " "

# echo -e "${YELLOW}[+] Searching exploitdb...${NC}"
# searchsploit --nmap ResultNmap$nombre --id
# echo " "
# Buscar alternativas
# echo -e "${YELLOW}[+] Search Vulns with NMAP...${NC}"
# nmap -sV -Pn -n -A --script vuln $ipvictima
