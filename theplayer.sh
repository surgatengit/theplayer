#!/bin/bash
# Surgat Ramos 0.0.4, vs in english for Yuma

BLUE='\033[0;34m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m' 
NC='\033[0m' # No color

# use -e para los colores las secuencias -amsi

if [ -z "$1" ]
then
        echo "Usage: ./theplayer.sh <IP> <NAME OF MACHINE>"
        echo "Example: ./theplayer.sh 10.10.10.129 pikathree"
        exit 1
fi

ipvictima=$1
nombre=$2

echo -e "${YELLOW}[+] Fast Escan... ${NC}"
sudo nmap -T4 -F $ipvictima

echo -e "${YELLOW}[-] Starts complete NMAP... detect ports${NC}"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo -e "${GREEN}[+] Complete Scan... analizing open ports${NC}"
echo $ports

# Verify ports 80.443 is opens http https
if echo "$ports" | grep -q "80\|443"; then
    echo "${GREEN}[+] Find 80 and 443 ports opnen in IP $ipvictima${NC}"
    echo -e "${BLUE}you should run nikto: in other terminal${NC}"
    echo -e "${BLUE}nikto -h http:$ipvictima -C all${NC}"
    echo -e "${BLUE}o ${NC}"
    echo -e "${BLUE}nikto -h https:$ipvictima -C all${NC}"
    echo "[+] curl to IP $ipvictima"
    curl -vvv $ipvictima
fi
# Verify ports 139 o 445 are open smb
if echo "$ports" | grep -q "139\|445"; then
    echo "${GREEN}[+] Find 139 o 445 open, en IP $ipvictima${NC}"
    echo "${YELLOW}[-] Runing enumeration SMB withowt Credentials${NC}"
    nbtscan $ipvictima
    smbmap -H $ipvictima
    smbmap -H $ipvictima -u null -p null
    smbmap -H $ipvictima -u guest
    smbclient -N -L //$ipvictima
    crackmapexec smb $ipvictima
    crackmapexec smb $ipvictima --pass-pol -u "" -p ""
    crackmapexec smb $ipvictima --pass-pol -u guest
fi
echo "[+] launch NMAP -sV -sC -Pn nmap"
nmap -p$ports -sV -sC -Pn $ipvictima -oA ResultNmap$nombre

# Searching URLs in nmap and add to /host file if no exist
echo "[+] Searching for URLs in Nmap output..."
urls=$(grep -oP '(http|https)://[\w\-\.]+\.[a-zA-Z]+(:\d+)?(/[\w/_\.]*)?' ResultNmap$nombre.xml)
for url in $urls; do
    if ! grep -q "$url" /etc/hosts; then
        echo "Adding $url to /etc/hosts"
        echo "$ipvictima $(dig +short "$(echo "$url" | sed 's/http[s]*:\/\///' | cut -d/ -f1)") $nombre.htb # add by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo "Skipping $url because it already exists in /etc/hosts"
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
        echo "[+] LAunching wfuzz in $url"
        wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u "$url/FUZZ"
    done
fi

echo "[+] Searching eXploiTs..."
searchsploit --nmap ResultNmap$nombre.xml -v --id
echo "[+] Search Vulns con nmap..."
nmap -sV -Pn -A --script vuln $ipvictima
