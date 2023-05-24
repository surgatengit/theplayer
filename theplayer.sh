#!/bin/bash
# Surgat Ramos 0.1.1

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

# -e in echo for ANSI escapes

if [ -z "$1" ]
then
        echo "Usage: ./theplayer.sh <IP> <NAME OF MACHINE>"
        echo "Example: ./theplayer.sh 10.10.10.129 easymachine"
        exit 1
fi

ipvictima=$1
nombre=$2

figlet The Player
echo "                           Surgat"

echo -e "${YELLOW}[+] Fast Scan... ${NC}"
sudo nmap -T4 -F $ipvictima
echo -e "${YELLOW}If you look a 80 o 443 go quick open firefox and Burpsuite or ZAP${NC}"

echo -e "${YELLOW}[-] Starts complete NMAP... search all ports open${NC}"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo -e "${GREEN}[+] Complete Scan... analizing open ports${NC}"
echo $ports

# Verify ports 80.443 is opens http https
if echo "$ports" | grep -q "80\|443"; then
    echo -e "${YELLOW}[+] Find 80 and 443 ports open in IP $ipvictima${NC}"
    echo -e "${GREEN}You should run nikto in other terminal${NC}"
    echo -e "${GREEN}nikto -h http://$ipvictima -C all${NC}"
    echo -e "${BLUE}o ${NC}"
    echo -e "${GREEN}nikto -h https://$ipvictima -C all${NC}"
    echo -e "${GREEN}[+] curl to IP $ipvictima${NC}"
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
echo -e "${LIGHT_CYAN}[+] launch NMAP -sV -sC -Pn ${NC}"
nmap -p$ports -sV -sC -Pn $ipvictima -oA ResultNmap$nombre

# Searching URLs in nmap and add to /host file if no exist
echo -e "${YELLOW}[+] Searching for URLs in Nmap output...${NC}"
urls=$(grep -oP '(http|https)://[\w\-\.]+\.[a-zA-Z]+(:\d+)?(/[\w/_\.]*)?' ResultNmap$nombre.xml)
for url in $urls; do
    if ! grep -q "$url" /etc/hosts; then
        echo "Adding $url to /etc/hosts"
        echo "$ipvictima $(dig +short "$(echo "$url" | sed 's/http[s]*:\/\///' | cut -d/ -f1)") $nombre.htb # add by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo -e "${GREEN}Skipping${BLUE} $url ${GREEN}because it already exists in /etc/hosts${NC}"
    fi
done
if [ -z "$urls" ]
then
    echo -e "${BLUE}No URLs found in results of nmap.${NC}"
else
    echo "[+] URLs founds: "
    echo "$urls"
    for url in $urls
    do
        echo "[+] Directory and archive fuzz $url"
        wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u "$url/FUZZ"
    done
fi
# foldername
foldername="ftp$nombre"
# Buscar la etiqueta <port> con el atributo portid="21" y estado state="open"
port_info=$(xmllint --xpath '//port[@portid="21" and state/@state="open"]' ResultNmap$nombre.xml)

# Verificar si se encontró la etiqueta <port>
if [[ -n $port_info ]]; then
  # Buscar si el inicio de sesión anónimo está permitido en la etiqueta <script> con id="ftp-anon"
  anon_login=$(echo "$port_info" | grep -o 'Anonymous FTP login allowed')

  if [[ -n $anon_login ]]; then
    echo -e "${GREEN}El puerto 21 está abierto y el inicio de sesión anónimo está permitido.${NC}"

    # Descargar el contenido
    wget --user=anonymous --password=anonymous -r "ftp://$ipvictima" -P "$foldername"
    echo -e "${GREEN}FTP content downloaded to $foldername${NC}"
  else
    echo "El puerto 21 está abierto pero el inicio de sesión anónimo no está permitido."
  fi
else
  echo "El puerto 21 no está abierto."
fi
echo " "
echo " "

echo -e "${YELLOW}[+] Searching exploitdb...${NC}"
searchsploit --nmap ResultNmap$nombre.xml --id
echo " "
# Buscar alternativas
# echo "${YELLOW}[+] Search Vulns with NMAP...${NC}"
# nmap -sV -Pn -n -A --script vuln $ipvictima
