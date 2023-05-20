#!/bin/bash
# Surgat Ramos 0.0.4

BLUE='\033[0;34m' # Color azul
GREEN='\033[0;32m' # Color verde
YELLOW='\033[1;33m' # Color amarillo
NC='\033[0m' # No color

# usare -e para poder usar las secuencias de escape ANSI

if [ -z "$1" ]
then
        echo "Usage: ./theplayer.sh <IP> <NAME OF MACHINE>"
        echo "Example: ./theplayer.sh 10.10.10.129 pikathree"
        exit 1
fi

ipvictima=$1
nombre=$2

echo -e "${YELLOW}[+] Escaneo rapido... ${NC}"
sudo nmap -T4 -F $ipvictima

echo -e "${YELLOW}[-] Empezando el escaneo completo... detectando puertos${NC}"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo -e "${GREEN}[+] Escaneo completo... analizando los puertos abiertos${NC}"
echo $ports

# Verificar si los puertos 80 o 443 están abiertos http https
if echo "$ports" | grep -q "80\|443"; then
    echo "${GREEN}[+] Se encontraron puertos 80 o 443 abiertos en la IP $ipvictima${NC}"
    echo -e "${BLUE}Lanza en otro terminal nikto:${NC}"
    echo -e "${BLUE}nikto -h http:$ipvictima -C all${NC}"
    echo -e "${BLUE}o ${NC}"
    echo -e "${BLUE}nikto -h https:$ipvictima -C all${NC}"
    echo "[+] Lanzando curl a la IP $ipvictima"
    curl -vvv $ipvictima
fi
# Verificar si los puertos 139 o 445 estan abiertos smb
if echo "$ports" | grep -q "139\|445"; then
    echo "${GREEN}[+] Se encontraron puertos 139 o 445 abiertos en la IP $ipvictima${NC}"
    echo "${YELLOW}[-] Lanzando enumeraciones SMB Sin Credenciales${NC}"
    nbtscan $ipvictima
    smbmap -H $ipvictima
    smbmap -H $ipvictima -u null -p null
    smbmap -H $ipvictima -u guest
    smbclient -N -L //$ipvictima
    crackmapexec smb $ipvictima
    crackmapexec smb $ipvictima --pass-pol -u "" -p ""
    crackmapexec smb $ipvictima --pass-pol -u guest
fi
echo "[+] lanzando nmap tipo ippsec quitando ping"
nmap -p$ports -sV -sC -Pn $ipvictima -oA ResultNmap$nombre

# Buscar URLs en nmap, y agregarlas a host si no existen
echo "[+] Searching for URLs in Nmap output..."
urls=$(grep -oP '(http|https)://[\w\-\.]+\.[a-zA-Z]+(:\d+)?(/[\w/_\.]*)?' ResultNmap$nombre.xml)
for url in $urls; do
    if ! grep -q "$url" /etc/hosts; then
        echo "Adding $url to /etc/hosts"
        echo "$ipvictima $(dig +short "$(echo "$url" | sed 's/http[s]*:\/\///' | cut -d/ -f1)") $nombre.htb # agregada por eljugador.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo "Skipping $url because it already exists in /etc/hosts"
    fi
done
if [ -z "$urls" ]
then
    echo -e "${BLUE}No se encontraron URLs en el resultado de nmap.${NC}"
else
    echo "[+] URLs encontradas: "
    echo "$urls"
    for url in $urls
    do
        echo "[+] Ejecutando wfuzz en $url"
        wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u "$url/FUZZ"
    done
fi

echo "[+] Searching eXploiTs..."
searchsploit --nmap ResultNmap$nombre.xml -v --id
echo "[+] Vulnerabilidades con nmap..."
nmap -sV -Pn -A --script vuln $ipvictima
