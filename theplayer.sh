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

## Fast Scan and scan al open ports

echo -e "${LIGHT_BLUE}[+]       Fast Scan... ${NC}"
sudo nmap -T4 -F $ipvictima
echo -e "${YELLOW}                80/443 port... Time to Firefox and Burpsuite Manually${NC}"

echo -e "${LIGHT_BLUE}[-]       Starts complete NMAP... search all open ports${NC}"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo -e "${LIGHT_BLUE}[+]       Complete NMAP in background... analizing open ports${NC}"
echo -e "${LIGHT_CYAN}[+]       launch NMAP -sV -sC -Pn ${NC}"
nmap -p$ports -sV -sC -Pn $ipvictima -oX ResultNmap$nombre &
echo $ports

    # Verify ports 80 is open http
    # todo in full scan filter for open ssl/http para https y open http para http
    
if echo "$ports" | grep -q "^80$"; then
    echo -e "${YELLOW}[+] Find 80 port open in IP $ipvictima${NC}"
    echo -e "${GREEN}You should run nikto in other terminal${NC}"
    echo -e "${GREEN}nikto -h http://$ipvictima -C all${NC}"
    echo "-----------------------"
    echo -e "${LIGHT_CYAN}[+]          Curl to IP $ipvictima${NC}"
    echo -e "${YELLOW}"
    curl -vvv $ipvictima
    echo -e "${NC}"
fi
    # Verify port 443 is open https
    
if echo "$ports" | grep -q "^443$"; then
    echo -e "${YELLOW}[+] Find 443 port open in IP $ipvictima${NC}"
    echo -e "${GREEN}You should run nikto in other terminal${NC}"
    echo -e "${GREEN}nikto -h https://$ipvictima -C all${NC}"
    echo ""
    echo "-----------------------"
    echo -e "${LIGHT_CYAN}[+]          Curl to IP $ipvictima${NC}"
    echo -e "${YELLOW}"
    curl -k -vvv https://$ipvictima
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
echo -e "${GREEN}[+] Waiting to finish complete Nmap in background...${NC}"
wait

## Host name to /etc/hosts
echo -e "${YELLOW}[+] Searching for hostnames in Nmap output...${NC}"

# Searching hostnames in Nmap output
if echo "$ports" | grep -q "80"; then
urls=$(xmllint --xpath '//host/ports/port/script[@id="http-title" and @output!=""]/@output' ResultNmap$nombre | sed -n -E 's/.*(https?|http):\/\/([^/]+).*/\2/p')

for hostname in $urls; do
    if ! grep -q "$hostname" /etc/hosts; then
        echo ""
        echo -e "${GREEN}       Adding ${YELLOW} $hostname ${GREEN}to /etc/hosts ${NC}"
        echo "$ipvictima $(dig +short "$hostname") $hostname # added by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo ""
        echo -e "${GREEN}        Skipping${YELLOW} $hostname ${GREEN}because it already exists in /etc/hosts${NC}"
    fi
done

if [ -z "$urls" ]; then
    echo -e "${LIGHT_CYAN}No hostnames found in the results of Nmap.${NC}"
else
    echo ""
    echo -e "${YELLOW}[+]   Hostnames found:${NC}"
    echo "$urls"
fi

## Curl on screen, ffuf subdomanin and wfuzz virtualhosts

    for host in $urls; do
        echo ""
        echo -e "${LIGHT_CYAN}[+]       Curl to $hostname${NC}"
        curl -vvv $hostname
        echo ""
        echo -e "${LIGHT_CYAN}[+]       Directory and archive fuzz (wfuzz combined_words) $hostname${NC}"
        echo ""
        wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u "$hostname/FUZZ"
        echo ""
        echo -e "${LIGHT_CYAN}[+]       Subdomain Virtualhosts fuzz (ffuf combined_subdomains) $hostname ${NC}"
        echo "" # ffuf with autocalibrate
        ffuf -u http://$hostname -H "Host:FUZZ.$hostname" -w /usr/share/wordlists/seclists/Discovery/DNS/combined_subdomains.txt -mc all -c -v -ac true -o fuff$hostname
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

## DNS server
# Find the <port> tag with the attribute portid="21" and state="open"
port_info53=$(xmllint --xpath '//port[@portid="53" and state/@state="open"]' ResultNmap$nombre)
# Check if the <port> tag was found.
echo -e "${BLUE}[-] Port 53 DNS is open, try to grab the banner and run metasploit modules dns_amp and enum_dns${NC}"
if [[ -n $port_info53 ]]; then
  # launch domain dns search and dig banner grab
   dig version.bind CHAOS TXT @$1
   msfconsole -q -x "use auxiliary/scanner/dns/dns_amp; set RHOSTS $ipvictima; set RPORT 53; run; exit" && msfconsole -q -x "use auxiliary/gather/enum_dns; set RHOSTS $ipvictima; set RPORT 53; run; exit"
else
  echo -e "${BLUE}[-] port 53 DNS is not open.${NC}"
fi
echo " "
echo " "

# echo -e "${YELLOW}[+] Searching exploitdb...${NC}"
# searchsploit --nmap ResultNmap$nombre --id
# echo " "
# Buscar alternativas
# echo -e "${YELLOW}[+] Search Vulns with NMAP...${NC}"
# nmap -sV -Pn -n -A --script vuln $ipvictima
