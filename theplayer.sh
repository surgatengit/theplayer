#!/bin/bash

# By Surgat Ramos
# version="0.0.4"
# Decidir español o ingles

# Parameters Fail
# Hay que mejorarlo, para que no acepte entradas no validas y si acaso que muestre la ayuda
if [ -z "$1" ]
then
        echo "Usage: ./theplayer.sh <IP> <NAME OF MACHINE>"
        echo "Example: ./theplayer.sh 10.10.10.129 pikathree"
        exit 1
fi

ipvictima=$1
nombre=$2

# En futuras versiones, revisando la salida xml de nmap, que lo agregue si es necesario
echo "[+] Revisando si exite $nombre.htb en el archivo Host"
if [ $(cat /etc/hosts | grep -c "$ipvictima $nombre.htb") = 1 ]
    then
        echo
        echo "Existe $ipvictima $nombre.htb en /etc/hosts con lo que no se agregara."
    else
        echo "Agregando $ipvictima $nombre.htb a /etc/hosts"
        echo "$ipvictima $nombre.htb" | sudo tee -a /etc/hosts
    fi
echo

echo "[+] rapid scan"
sudo nmap -T4 -F $ipvictima

echo "[+] Empezando el escaneo completo... Detectando puertos"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo "[+] Escaneo completo... Analizando los Puertos Abiertos"
nmap -p$ports -n -sV -sC $ipvictima -oA ResultNmap$nombre

# Check for URLs in Nmap output and add them to /etc/hosts
echo "[+] Searching for URLs in Nmap output..."
urls=$(grep -oP '(http|https)://[\w\-\.]+\.[a-zA-Z]+(:\d+)?(/[\w/_\.]*)?' ResultNmap$nombre.xml)
for url in $urls; do
    if ! grep -q "$url" /etc/hosts; then
        echo "Adding $url to /etc/hosts"
        echo "$(dig +short "$(echo "$url" | sed 's/http[s]*:\/\///' | cut -d/ -f1)") $nombre.htb # added by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    fi
done
echo "[+] Buscando URLs en el resultado de nmap..."
echo "[+] Searching for URLs in Nmap output..."
urls=$(grep -oP '(http|https)://[\w\-\.]+\.[a-zA-Z]+(:\d+)?(/[\w/_\.]*)?' ResultNmap$nombre.xml)

if [ -z "$urls" ]
then
    echo "No se encontraron URLs en el resultado de nmap."
else
    echo "[+] URLs encontradas: "
    echo "$urls"
    for url in $urls
    do
        echo "[+] Abriendo nueva terminal para ejecutar wfuzz en $url"
        x-terminal-emulator -e /usr/bin/zsh -hold -c "wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u '$url/FUZZ'"
    done
fi

echo "[+] Searching eXploiTs..."
x-terminal-emulator -e /usr/bin/zsh -hold -c "searchsploit --nmap ResultNmap$nombre.xml"
