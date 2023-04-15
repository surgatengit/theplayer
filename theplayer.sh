#!/bin/bash

# By Surgat Ramos
# version="0.0.2"
# Decidir español o ingles

# Parameters Fail
# Hay que mejorarlo, para que no acepte entradas no validas y si acaso que muestre la ayuda
if [ -z "$1" ]
then
        echo "Usage: ./surgathtb.sh <IP> <NAME OF MACHINE>"
        echo "Example: ./surgathtb.sh 10.10.10.129 pikathree"
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

echo "[+] Searching eXploiTs..."
searchsploit --nmap ResultNmap$nombre.xml
