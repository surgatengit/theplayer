#!/bin/bash

# Surgat Ramos 0.0.4

if [ -z "$1" ]
then
        echo "Usage: ./theplayer.sh <IP> <NAME OF MACHINE>"
        echo "Example: ./theplayer.sh 10.10.10.129 pikathree"
        exit 1
fi

ipvictima=$1
nombre=$2

# Mas abajo queda solucionado agregar a host urls, si no da problemas borrar
#echo "[+] Revisando si exite $nombre.htb en el archivo Host"
#if [ $(cat /etc/hosts | grep -c "$ipvictima $nombre.htb") = 1 ]
#    then
#        echo
#        echo "Existe $ipvictima $nombre.htb en /etc/hosts con lo que no se agregara."
#    else
#        echo "Agregando $ipvictima $nombre.htb a /etc/hosts"
#        echo "$ipvictima $nombre.htb" | sudo tee -a /etc/hosts
#    fi
#echo

echo "[+] Escaneo rapido"
sudo nmap -T4 -F $ipvictima

echo "[+] Empezando el escaneo completo... Detectando puertos"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo "[+] Escaneo completo... Analizando los Puertos Abiertos"
echo $ports
nmap -p$ports -n -sV -sC $ipvictima -oA ResultNmap$nombre

# Buscar URLs en nmap, y agregarlas a host si no existen
echo "[+] Searching for URLs in Nmap output..."
urls=$(grep -oP '(http|https)://[\w\-\.]+\.[a-zA-Z]+(:\d+)?(/[\w/_\.]*)?' ResultNmap$nombre.xml)
for url in $urls; do
    if ! grep -q "$url" /etc/hosts; then
        echo "Adding $url to /etc/hosts"
        echo "$ipvictima $(dig +short "$(echo "$url" | sed 's/http[s]*:\/\///' | cut -d/ -f1)") $nombre.htb # added by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo "Skipping $url because it already exists in /etc/hosts"
    fi
done
echo "[+] Buscando URLs en el resultado de nmap..."
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
        gnome-terminal -- wfuzz -c -w /usr/share/seclists/Discovery/Web-Content/combined_words.txt --hc 404,302,400 -u "$url/FUZZ"
    done
fi

echo "[+] Searching eXploiTs..."
gnome-terminal --working-directory="$PWD" --title="searchsploit Results for $nombre" -- "searchsploit --nmap ResultNmap$nombre.xml"
