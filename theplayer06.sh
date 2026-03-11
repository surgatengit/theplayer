#!/bin/bash
# theplayer.sh v0.7 - HTB Initial Recon Automation
# Features: parallel tasks, organized output, modern tools, credential support,
#           didactic command display, dependency install hints

set -o pipefail

# ── Colors ──
RED='\033[0;31m'    GREEN='\033[0;32m'  YELLOW='\033[1;33m'
BLUE='\033[0;34m'   CYAN='\033[0;36m'   PURPLE='\033[0;35m'
GRAY='\033[0;90m'   BOLD='\033[1m'      NC='\033[0m'

# ── Logging helpers ──
info()    { echo -e "${CYAN}[*]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[-]${NC} $*"; }
banner()  { echo -e "\n${BOLD}${PURPLE}═══════════════════════════════════════${NC}"; echo -e "${BOLD}${PURPLE}  $*${NC}"; echo -e "${BOLD}${PURPLE}═══════════════════════════════════════${NC}\n"; }

# ── Globals ──
BG_PIDS=()
IP=""
NAME=""
OUTDIR=""
PORTS=""
HOSTNAMES=()

# Credentials (optional)
CRED_USER=""
CRED_PASS=""
CRED_DOMAIN=""
HAS_CREDS=false

# ── Usage ──
usage() {
    echo "Usage: $0 <IP> <MACHINE_NAME> [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  IP              Target IP address"
    echo "  MACHINE_NAME    Name for organizing results"
    echo ""
    echo "Options (credentials):"
    echo "  -u USERNAME     Username for authenticated enumeration"
    echo "  -p PASSWORD     Password for authenticated enumeration"
    echo "  -d DOMAIN       Domain (for AD environments)"
    echo "  -H HASH         NT hash for pass-the-hash (alternative to -p)"
    echo ""
    echo "Examples:"
    echo "  $0 10.10.10.129 easymachine"
    echo "  $0 10.10.10.129 easymachine -u admin -p 'P@ssw0rd'"
    echo "  $0 10.10.10.129 easymachine -u admin -p 'P@ssw0rd' -d corp.local"
    echo "  $0 10.10.10.129 easymachine -u admin -H 'aad3b435b51404eeaad3b435b51404ee:hash'"
    exit 1
}

# ── Cleanup on exit / Ctrl+C ──
cleanup() {
    echo ""
    warn "Caught interrupt. Killing background jobs..."
    for pid in "${BG_PIDS[@]}"; do
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
    done
    warn "Done. Partial results may be in $OUTDIR"
    exit 1
}
trap cleanup SIGINT SIGTERM

# ── Show the exact command being run (didactic mode) ──
show_cmd() {
    local mode="$1"; shift
    local cmd_str=""
    for arg in "$@"; do
        if [[ "$arg" =~ [[:space:]] ]]; then
            cmd_str+="'$arg' "
        else
            cmd_str+="$arg "
        fi
    done
    if [ "$mode" = "bg" ]; then
        echo -e "  ${GRAY}▸ [background] ${cmd_str}${NC}"
    else
        echo -e "  ${GRAY}▸ ${cmd_str}${NC}"
    fi
}

# ── Run command in background, log to file ──
run_bg() {
    local label="$1"; shift
    local logfile="$OUTDIR/${label}.txt"
    info "Launching: ${BOLD}$label${NC} → $logfile"
    show_cmd "bg" "$@"
    ( "$@" ) > "$logfile" 2>&1 &
    BG_PIDS+=($!)
}

# ── Run command in foreground, showing the command first ──
run_show() {
    local label="$1"; shift
    info "Running: ${BOLD}$label${NC}"
    show_cmd "fg" "$@"
    "$@"
}

# ── Dependency check with install instructions ──
declare -A INSTALL_HINTS
INSTALL_HINTS=(
    [nmap]="sudo apt install nmap"
    [enum4linux-ng]="pip3 install enum4linux-ng  # or: sudo apt install enum4linux-ng"
    [smbclient]="sudo apt install smbclient"
    [nxc]="pip3 install netexec  # https://github.com/Penntest-drop/NetExec"
    [ffuf]="go install github.com/ffuf/ffuf/v2@latest  # or: sudo apt install ffuf"
    [feroxbuster]="sudo apt install feroxbuster  # or: curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh | bash"
    [whatweb]="sudo apt install whatweb"
    [curl]="sudo apt install curl"
    [wfuzz]="pip3 install wfuzz"
    [xmllint]="sudo apt install libxml2-utils"
    [dig]="sudo apt install dnsutils"
    [wget]="sudo apt install wget"
    [figlet]="sudo apt install figlet"
    [nuclei]="go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest  # https://github.com/projectdiscovery/nuclei"
    [kerbrute]="go install github.com/ropnop/kerbrute@latest  # https://github.com/ropnop/kerbrute/releases"
    [certipy-ad]="pip3 install certipy-ad  # https://github.com/ly4k/Certipy"
    [rdwatool]="pip3 install rdwatool  # https://github.com/yourrepo/rdwatool"
    [ldapsearch]="sudo apt install ldap-utils"
    [impacket-GetNPUsers]="pip3 install impacket  # https://github.com/fortra/impacket"
    [impacket-GetUserSPNs]="pip3 install impacket"
    [bloodhound-python]="pip3 install bloodhound  # https://github.com/dirkjanm/BloodHound.py"
)

check_deps() {
    local missing_req=()
    local missing_opt=()
    local required=(nmap enum4linux-ng smbclient nxc ffuf feroxbuster whatweb curl xmllint dig wget)
    local optional=(nuclei kerbrute certipy-ad rdwatool ldapsearch impacket-GetNPUsers impacket-GetUserSPNs bloodhound-python figlet)

    for cmd in "${required[@]}"; do
        command -v "$cmd" &>/dev/null || missing_req+=("$cmd")
    done

    for cmd in "${optional[@]}"; do
        command -v "$cmd" &>/dev/null || missing_opt+=("$cmd")
    done

    if [ ${#missing_req[@]} -gt 0 ]; then
        error "Missing ${BOLD}required${NC} tools:"
        for cmd in "${missing_req[@]}"; do
            echo -e "  ${RED}✗${NC} ${BOLD}$cmd${NC}"
            echo -e "    ${GRAY}Install: ${INSTALL_HINTS[$cmd]:-"search your package manager for $cmd"}${NC}"
        done
        echo ""
        error "Install the required tools above and re-run."
        exit 1
    fi

    if [ ${#missing_opt[@]} -gt 0 ]; then
        warn "Missing ${BOLD}optional${NC} tools (some checks will be skipped):"
        for cmd in "${missing_opt[@]}"; do
            echo -e "  ${YELLOW}○${NC} ${BOLD}$cmd${NC}"
            echo -e "    ${GRAY}Install: ${INSTALL_HINTS[$cmd]:-"search your package manager for $cmd"}${NC}"
        done
        echo ""
    fi
}

# ── Validators ──
is_valid_ip() {
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'; read -ra octets <<< "$1"
    for o in "${octets[@]}"; do (( o <= 255 )) || return 1; done
    return 0
}

# ── Resolve redirect: extract hostname, add to /etc/hosts, return target URL ──
resolve_redirect() {
    local url="$1"
    local curl_opts="$2"
    local max_hops=5
    local current_url="$url"

    for ((i=0; i<max_hops; i++)); do
        local headers
        headers=$(curl -s -I -o /dev/null -w "%{http_code} %{redirect_url}" --max-time 15 $curl_opts "$current_url")
        local code="${headers%% *}"
        local redirect_url="${headers#* }"

        if [[ "$code" != 3* ]] || [ -z "$redirect_url" ]; then
            echo "$current_url"
            return 0
        fi

        info "Redirect $code: $current_url → ${BOLD}$redirect_url${NC}" >&2

        local new_host
        new_host=$(echo "$redirect_url" | sed -n 's|.*://\([^:/]*\).*|\1|p')

        if [ -n "$new_host" ] && ! is_valid_ip "$new_host"; then
            if ! grep -q "$new_host" /etc/hosts; then
                echo "$IP    $new_host  # theplayer-$NAME (redirect)" | sudo tee -a /etc/hosts >/dev/null
                success "Added to /etc/hosts: ${BOLD}$new_host${NC} (from redirect)" >&2
            else
                info "Already in /etc/hosts: $new_host" >&2
            fi

            if [[ ! " ${HOSTNAMES[*]} " =~ " ${new_host} " ]]; then
                HOSTNAMES+=("$new_host")
            fi
        fi

        current_url="$redirect_url"
    done

    warn "Too many redirects (max $max_hops). Last URL: $current_url" >&2
    echo "$current_url"
    return 1
}

# ── Port scanning ──
do_scan() {
    banner "PORT SCANNING"

    run_show "Quick scan (top ports)" sudo nmap -T4 -F "$IP" | tee "$OUTDIR/nmap_quick.txt"

    info "Full port scan (all 65535)..."
    show_cmd "fg" sudo nmap -p- -n -Pn --min-rate=4000 "$IP"
    PORTS=$(sudo nmap -p- -n -Pn --min-rate=4000 "$IP" | grep '^[0-9]' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')

    if [ -z "$PORTS" ]; then
        error "No open ports found. Exiting."
        exit 1
    fi
    success "Open ports: ${BOLD}$PORTS${NC}"
    echo "$PORTS" > "$OUTDIR/ports.txt"

    info "Detailed scan (-sV -sC) in background..."
    run_bg "nmap_full" sudo nmap -p"$PORTS" -sV -sC -Pn -oX "$OUTDIR/nmap_full.xml" -oN "$OUTDIR/nmap_full.txt" "$IP"
}

# ── Web enumeration (parallelized) ──
enum_web() {
    local port="$1"
    local scheme="$2"
    local base_url="${scheme}://${IP}"
    local curl_opts=""
    [ "$scheme" = "https" ] && curl_opts="-k"

    banner "WEB ENUM - ${scheme}://${IP}:${port}"

    run_show "Curl headers" curl -s -I --max-time 15 $curl_opts "$base_url" | tee "$OUTDIR/curl_${scheme}_headers.txt"

    local target_url
    target_url=$(resolve_redirect "$base_url" "$curl_opts")

    if [ "$target_url" != "$base_url" ]; then
        success "Final target after redirects: ${BOLD}$target_url${NC}"
        run_show "Curl headers (final)" curl -s -I --max-time 15 $curl_opts "$target_url" | tee "$OUTDIR/curl_${scheme}_final_headers.txt"
    fi

    local final_url="$target_url"
    local label
    label=$(echo "$final_url" | sed 's|https\?://||;s|[/:.]|_|g;s|_$||')

    info "Verifying connectivity to $final_url ..."
    show_cmd "fg" curl -s -o /dev/null -w "%{http_code}" $curl_opts --max-time 20 "$final_url"
    if ! curl -s -o /dev/null -w "%{http_code}" $curl_opts --max-time 20 "$final_url" | grep -qE '^[23]'; then
        error "Cannot reach $final_url — check /etc/hosts and DNS. Skipping web enum."
        return 1
    fi
    success "Target $final_url is reachable."

    run_show "WhatWeb" whatweb --color=never "$final_url" 2>/dev/null | tee "$OUTDIR/whatweb_${label}.txt"

    # Directory bruteforce in background
    run_bg "feroxbuster_${label}" feroxbuster -u "$final_url" \
        -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt \
        -t 50 -k --no-state --quiet -o "$OUTDIR/feroxbuster_${label}.txt"

    # Nuclei vuln scan in background (if available)
    if command -v nuclei &>/dev/null; then
        run_bg "nuclei_${label}" nuclei -u "$final_url" -severity medium,high,critical \
            -o "$OUTDIR/nuclei_${label}.txt" -silent
    fi

    warn "Tip: Consider running nikto manually: nikto -h ${final_url} -C all"
}

# ── Virtualhost / subdomain fuzzing (parallelized) ──
enum_vhosts() {
    local hostname="$1"
    banner "VHOST FUZZING - $hostname"

    run_bg "dirs_${hostname}" feroxbuster -u "http://${hostname}" \
        -w /usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt \
        -t 50 --no-state --quiet -o "$OUTDIR/dirs_${hostname}.txt"

    run_bg "vhost_${hostname}" ffuf -u "http://${hostname}" \
        -H "Host:FUZZ.${hostname}" \
        -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
        -mc all -ac -c -o "$OUTDIR/ffuf_${hostname}.json" -of json
}

# ── SMB enumeration ──
enum_smb() {
    banner "SMB ENUMERATION (anonymous / guest)"

    run_show "enum4linux-ng (full enum)" enum4linux-ng -Adv -oA "$OUTDIR/enum4linux" "$IP" 2>&1 | tee "$OUTDIR/enum4linux_live.txt"

    run_show "smbclient (null session)" smbclient -N -L "//$IP" 2>&1 | tee "$OUTDIR/smbclient.txt"

    run_show "NetExec - shares (READ/WRITE)" nxc smb "$IP" -u 'guest' -p '' --shares --filter-shares READ WRITE 2>&1 | tee "$OUTDIR/nxc_shares.txt"

    info "NetExec - RID brute (guest)..."
    run_bg "nxc_rid_guest" nxc smb "$IP" -u 'guest' -p '' --rid-brute 10000

    info "NetExec - vuln modules..."
    run_bg "nxc_vulns" nxc smb "$IP" -u 'guest' -p '' \
        -M enum_av -M shadowcoerce -M petitpotam -M dfscoerce -M gpp_autologin -M gpp_password -M zerologon -M ms17-010
}

# ── SMB with credentials ──
enum_smb_auth() {
    banner "SMB ENUMERATION (authenticated: ${CRED_USER})"

    local nxc_auth=(-u "$CRED_USER" -p "$CRED_PASS")
    [ -n "$CRED_DOMAIN" ] && nxc_auth+=(-d "$CRED_DOMAIN")

    # If we got an NT hash instead of password
    if [ -n "$CRED_HASH" ]; then
        nxc_auth=(-u "$CRED_USER" -H "$CRED_HASH")
        [ -n "$CRED_DOMAIN" ] && nxc_auth+=(-d "$CRED_DOMAIN")
    fi

    run_show "NetExec - shares (auth)" nxc smb "$IP" "${nxc_auth[@]}" --shares 2>&1 | tee "$OUTDIR/nxc_shares_auth.txt"

    run_show "NetExec - users (auth)" nxc smb "$IP" "${nxc_auth[@]}" --users 2>&1 | tee "$OUTDIR/nxc_users_auth.txt"

    run_show "NetExec - groups (auth)" nxc smb "$IP" "${nxc_auth[@]}" --groups 2>&1 | tee "$OUTDIR/nxc_groups_auth.txt"

    info "NetExec - RID brute (auth)..."
    run_bg "nxc_rid_auth" nxc smb "$IP" "${nxc_auth[@]}" --rid-brute 10000

    info "NetExec - logged-on users..."
    run_bg "nxc_loggedon" nxc smb "$IP" "${nxc_auth[@]}" --loggedon-users

    info "NetExec - password policy..."
    run_bg "nxc_passpol" nxc smb "$IP" "${nxc_auth[@]}" --pass-pol

    # Kerberoasting with impacket
    if command -v impacket-GetUserSPNs &>/dev/null && [ -n "$CRED_DOMAIN" ]; then
        local spn_auth="$CRED_DOMAIN/$CRED_USER:$CRED_PASS"
        [ -n "$CRED_HASH" ] && spn_auth="$CRED_DOMAIN/$CRED_USER" # will use -hashes below

        if [ -n "$CRED_HASH" ]; then
            run_bg "kerberoast" impacket-GetUserSPNs "$CRED_DOMAIN/$CRED_USER" \
                -hashes "$CRED_HASH" -dc-ip "$IP" -request -outputfile "$OUTDIR/kerberoast.txt"
        else
            run_bg "kerberoast" impacket-GetUserSPNs "$CRED_DOMAIN/$CRED_USER:$CRED_PASS" \
                -dc-ip "$IP" -request -outputfile "$OUTDIR/kerberoast.txt"
        fi
        warn "If kerberoast hashes found: hashcat -m 13100 $OUTDIR/kerberoast.txt wordlist"
    fi

    # BloodHound collection
    if command -v bloodhound-python &>/dev/null && [ -n "$CRED_DOMAIN" ]; then
        info "BloodHound data collection..."
        if [ -n "$CRED_HASH" ]; then
            warn "bloodhound-python doesn't support hashes natively. Skipping."
        else
            run_bg "bloodhound" bloodhound-python -c All \
                -u "$CRED_USER" -p "$CRED_PASS" -d "$CRED_DOMAIN" -ns "$IP" \
                --zip -o "$OUTDIR/"
        fi
    fi
}

# ── LDAP enumeration ──
enum_ldap() {
    banner "LDAP ENUMERATION (anonymous)"

    run_show "Attempting anonymous LDAP bind" ldapsearch -x -H "ldap://$IP" -b "" -s base namingContexts 2>&1 | tee "$OUTDIR/ldap_base.txt"

    info "NetExec LDAP - AS-REP roasting (no creds)..."
    run_bg "nxc_asrep_anon" nxc ldap "$IP" -u '' -p '' --asreproast "$OUTDIR/asreproast_anon.txt"

    if command -v certipy-ad &>/dev/null; then
        info "Certipy - ADCS check (anonymous)..."
        run_bg "certipy_anon" certipy-ad find -u '' -p '' -dc-ip "$IP" -stdout
    fi
}

# ── LDAP with credentials ──
enum_ldap_auth() {
    banner "LDAP ENUMERATION (authenticated: ${CRED_USER})"

    local nxc_auth=(-u "$CRED_USER" -p "$CRED_PASS")
    [ -n "$CRED_DOMAIN" ] && nxc_auth+=(-d "$CRED_DOMAIN")
    [ -n "$CRED_HASH" ] && nxc_auth=(-u "$CRED_USER" -H "$CRED_HASH") && [ -n "$CRED_DOMAIN" ] && nxc_auth+=(-d "$CRED_DOMAIN")

    # Full LDAP dump
    if [ -n "$CRED_DOMAIN" ]; then
        local base_dn
        base_dn=$(echo "$CRED_DOMAIN" | sed 's/\./,DC=/g;s/^/DC=/')
        run_show "LDAP full dump (auth)" ldapsearch -x -H "ldap://$IP" \
            -D "$CRED_USER@$CRED_DOMAIN" -w "$CRED_PASS" \
            -b "$base_dn" 2>&1 | tee "$OUTDIR/ldap_full_auth.txt"
    fi

    info "NetExec LDAP - AS-REP roasting (auth)..."
    run_bg "nxc_asrep_auth" nxc ldap "$IP" "${nxc_auth[@]}" --asreproast "$OUTDIR/asreproast_auth.txt"

    info "NetExec LDAP - Kerberoasting (auth)..."
    run_bg "nxc_kerb_auth" nxc ldap "$IP" "${nxc_auth[@]}" --kerberoasting "$OUTDIR/kerberoast_ldap.txt"

    # AS-REP roast with impacket
    if command -v impacket-GetNPUsers &>/dev/null && [ -n "$CRED_DOMAIN" ]; then
        if [ -n "$CRED_HASH" ]; then
            run_bg "asreproast_impacket" impacket-GetNPUsers "$CRED_DOMAIN/$CRED_USER" \
                -hashes "$CRED_HASH" -dc-ip "$IP" -outputfile "$OUTDIR/asreproast_impacket.txt"
        else
            run_bg "asreproast_impacket" impacket-GetNPUsers "$CRED_DOMAIN/$CRED_USER:$CRED_PASS" \
                -dc-ip "$IP" -outputfile "$OUTDIR/asreproast_impacket.txt"
        fi
        warn "If AS-REP hashes found: hashcat -m 18200 $OUTDIR/asreproast_impacket.txt wordlist"
    fi

    # Certipy with creds
    if command -v certipy-ad &>/dev/null && [ -n "$CRED_DOMAIN" ]; then
        info "Certipy - ADCS vuln scan (auth)..."
        run_bg "certipy_auth" certipy-ad find -u "$CRED_USER@$CRED_DOMAIN" -p "$CRED_PASS" \
            -dc-ip "$IP" -vulnerable -stdout
    fi
}

# ── FTP check ──
enum_ftp() {
    banner "FTP CHECK"
    info "Testing anonymous FTP login..."
    local ftpdir="$OUTDIR/ftp_loot"
    show_cmd "fg" wget --user=anonymous --password=anonymous -r -q "ftp://$IP" -P "$ftpdir"
    timeout 15 wget --user=anonymous --password=anonymous -r -q "ftp://$IP" -P "$ftpdir" 2>/dev/null
    if [ $? -eq 0 ] && [ -d "$ftpdir" ]; then
        success "Anonymous FTP content downloaded to $ftpdir"
    else
        warn "Anonymous FTP login failed or no content."
    fi

    # FTP with credentials
    if [ "$HAS_CREDS" = true ]; then
        info "Testing FTP with credentials ($CRED_USER)..."
        local ftpdir_auth="$OUTDIR/ftp_loot_auth"
        show_cmd "fg" wget --user="$CRED_USER" --password="$CRED_PASS" -r -q "ftp://$IP" -P "$ftpdir_auth"
        timeout 15 wget --user="$CRED_USER" --password="$CRED_PASS" -r -q "ftp://$IP" -P "$ftpdir_auth" 2>/dev/null
        if [ $? -eq 0 ] && [ -d "$ftpdir_auth" ]; then
            success "Authenticated FTP content downloaded to $ftpdir_auth"
        else
            warn "Authenticated FTP login failed or no content."
        fi
    fi
}

# ── DNS enum ──
enum_dns() {
    banner "DNS ENUMERATION"
    run_show "DNS version grab" dig version.bind CHAOS TXT "@$IP" 2>&1 | tee "$OUTDIR/dns_version.txt"

    info "Attempting zone transfer (if domain known)..."
    for hn in "${HOSTNAMES[@]}"; do
        local domain
        domain=$(echo "$hn" | awk -F. '{print $(NF-1)"."$NF}')
        if [ -n "$domain" ]; then
            show_cmd "fg" dig axfr "$domain" "@$IP"
            dig axfr "$domain" "@$IP" 2>&1 | tee -a "$OUTDIR/dns_axfr.txt"
        fi
    done

    # If we have a domain from credentials, also try zone transfer on it
    if [ -n "$CRED_DOMAIN" ]; then
        info "Zone transfer attempt on credential domain: $CRED_DOMAIN"
        show_cmd "fg" dig axfr "$CRED_DOMAIN" "@$IP"
        dig axfr "$CRED_DOMAIN" "@$IP" 2>&1 | tee -a "$OUTDIR/dns_axfr.txt"
    fi
}

# ── Kerberos enumeration (port 88) ──
enum_kerberos() {
    banner "KERBEROS ENUMERATION"

    if command -v kerbrute &>/dev/null; then
        local domain="${CRED_DOMAIN}"
        # Try to extract domain from enum4linux if not provided
        if [ -z "$domain" ] && [ -f "$OUTDIR/enum4linux_live.txt" ]; then
            domain=$(grep -oP 'Domain: \K[^\s]+' "$OUTDIR/enum4linux_live.txt" 2>/dev/null)
        fi
        if [ -n "$domain" ]; then
            run_bg "kerbrute_userenum" kerbrute userenum \
                /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt \
                -d "$domain" --dc "$IP" -o "$OUTDIR/kerbrute.txt"
        else
            warn "No domain found for kerbrute. Provide one with -d DOMAIN"
        fi
    fi

    # AS-REP roast without creds (needs a user list)
    if command -v impacket-GetNPUsers &>/dev/null && [ -n "$CRED_DOMAIN" ]; then
        info "AS-REP roast (no auth, user list)..."
        run_bg "asrep_noauth" impacket-GetNPUsers "$CRED_DOMAIN/" \
            -usersfile /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt \
            -dc-ip "$IP" -no-pass -outputfile "$OUTDIR/asreproast_noauth.txt"
    fi
}

# ── Hostname extraction & /etc/hosts ──
extract_hostnames() {
    banner "HOSTNAME DISCOVERY"

    info "Waiting for detailed nmap scan to finish..."
    for pid in "${BG_PIDS[@]}"; do
        if ps -p "$pid" &>/dev/null; then
            wait "$pid" 2>/dev/null
        fi
        break
    done

    local xmlfile="$OUTDIR/nmap_full.xml"
    if [ ! -f "$xmlfile" ]; then
        warn "Nmap XML not found. Skipping hostname extraction."
        return
    fi

    local urls
    urls=$(xmllint --xpath '//host/ports/port/script[@id="http-title"]/@output' "$xmlfile" 2>/dev/null \
        | sed -n -E 's/.*(https?):\/\/([^/"]+).*/\2/p' | sort -u)

    local ssl_names
    ssl_names=$(xmllint --xpath '//host/ports/port/script[@id="ssl-cert"]/@output' "$xmlfile" 2>/dev/null \
        | grep -oP 'commonName=\K[^\s/]+' | sort -u)

    local smb_names
    smb_names=$(xmllint --xpath '//host/hostscript/script[@id="smb-os-discovery"]/@output' "$xmlfile" 2>/dev/null \
        | grep -oP '(FQDN|Domain): \K[^\s\\]+' | sort -u)

    local all_hosts
    all_hosts=$(echo -e "${urls}\n${ssl_names}\n${smb_names}" | grep -v '^$' | sort -u)

    if [ -z "$all_hosts" ]; then
        warn "No hostnames discovered."
        return
    fi

    success "Discovered hostnames:"
    echo "$all_hosts"

    while IFS= read -r hostname; do
        [ -z "$hostname" ] && continue
        HOSTNAMES+=("$hostname")
        if ! grep -q "$hostname" /etc/hosts; then
            echo "$IP    $hostname  # theplayer-$NAME" | sudo tee -a /etc/hosts >/dev/null
            success "Added to /etc/hosts: ${BOLD}$hostname${NC}"
        else
            info "Already in /etc/hosts: $hostname"
        fi
    done <<< "$all_hosts"
}

# ══════════════════════════════════════════════
#                    MAIN
# ══════════════════════════════════════════════
main() {
    # ── Parse args: first two positional, then flags ──
    if [ $# -lt 2 ]; then
        usage
    fi

    IP="$1"; shift
    NAME="$1"; shift

    # Parse optional flags
    CRED_HASH=""
    while getopts "u:p:d:H:" opt; do
        case $opt in
            u) CRED_USER="$OPTARG" ;;
            p) CRED_PASS="$OPTARG" ;;
            d) CRED_DOMAIN="$OPTARG" ;;
            H) CRED_HASH="$OPTARG" ;;
            *) usage ;;
        esac
    done

    # Determine if we have usable credentials
    if [ -n "$CRED_USER" ] && { [ -n "$CRED_PASS" ] || [ -n "$CRED_HASH" ]; }; then
        HAS_CREDS=true
    elif [ -n "$CRED_USER" ]; then
        error "Credential user provided but no password (-p) or hash (-H). Provide one."
        exit 1
    fi

    # Validate
    is_valid_ip "$IP" || { error "Invalid IP: $IP"; exit 1; }
    [[ "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || { error "Invalid name: use alphanumeric/dash/underscore"; exit 1; }

    # Banner
    figlet -f slant "The Player" 2>/dev/null || echo "=== The Player ==="
    echo "  v0.7 - HTB Recon Automation"
    echo ""

    if [ "$HAS_CREDS" = true ]; then
        success "Credentials loaded: ${BOLD}${CRED_USER}${NC}"
        [ -n "$CRED_DOMAIN" ] && info "Domain: ${BOLD}${CRED_DOMAIN}${NC}"
        [ -n "$CRED_HASH" ] && info "Auth mode: ${BOLD}Pass-the-Hash${NC}" || info "Auth mode: ${BOLD}Password${NC}"
    else
        info "No credentials provided. Running unauthenticated enumeration only."
        info "Re-run with: $0 $IP $NAME -u USER -p PASS [-d DOMAIN]"
    fi
    echo ""

    # Check dependencies
    check_deps

    # Output directory
    OUTDIR="results/${NAME}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$OUTDIR"
    success "Results directory: ${BOLD}$OUTDIR${NC}"

    # Save run config for reference
    {
        echo "# theplayer run config"
        echo "target=$IP"
        echo "name=$NAME"
        echo "date=$(date -Iseconds)"
        echo "has_creds=$HAS_CREDS"
        [ "$HAS_CREDS" = true ] && echo "cred_user=$CRED_USER"
        [ -n "$CRED_DOMAIN" ] && echo "cred_domain=$CRED_DOMAIN"
        [ -n "$CRED_HASH" ] && echo "auth_mode=pth" || echo "auth_mode=password"
    } > "$OUTDIR/run_config.txt"

    # Connectivity check
    info "Pinging $IP..."
    if ! ping -c 2 -W 3 "$IP" &>/dev/null; then
        error "Host unreachable. Check VPN/connectivity."
        exit 1
    fi
    success "Host is up."

    # ── Port scan ──
    do_scan

    # ── Service-based enumeration ──

    # Web
    echo "$PORTS" | grep -qw "80"  && enum_web 80 http
    echo "$PORTS" | grep -qw "443" && enum_web 443 https

    # SMB (always anon/guest first)
    if echo "$PORTS" | grep -qE '\b(139|445)\b'; then
        enum_smb
        [ "$HAS_CREDS" = true ] && enum_smb_auth
    fi

    # LDAP (always anon first)
    if echo "$PORTS" | grep -qE '\b(389|636|3268|3269)\b'; then
        enum_ldap
        [ "$HAS_CREDS" = true ] && enum_ldap_auth
    fi

    # Kerberos
    echo "$PORTS" | grep -qw "88" && enum_kerberos

    # FTP
    echo "$PORTS" | grep -qw "21" && enum_ftp

    # DNS
    echo "$PORTS" | grep -qw "53" && enum_dns

    # ── Hostname extraction & vhost fuzzing ──
    extract_hostnames

    for hn in "${HOSTNAMES[@]}"; do
        enum_vhosts "$hn" &
        BG_PIDS+=($!)
    done

    # ── Wait for all background jobs with progress ──
    banner "WAITING FOR BACKGROUND TASKS"
    info "Background jobs running: ${#BG_PIDS[@]}"
    info "Check $OUTDIR/ for live output. Ctrl+C to abort."
    echo ""

    while true; do
        local still_running=()
        for pid in "${BG_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                still_running+=("$pid")
            fi
        done

        echo -e "${CYAN}[*]${NC} Jobs remaining: ${BOLD}${#still_running[@]}/${#BG_PIDS[@]}${NC}"
        for f in "$OUTDIR"/*.txt; do
            [ -f "$f" ] || continue
            local fname=$(basename "$f")
            local lines=$(wc -l < "$f" 2>/dev/null || echo 0)
            local size=$(du -h "$f" 2>/dev/null | cut -f1)
            if [ "$lines" -gt 0 ] 2>/dev/null; then
                echo -e "  ${GRAY}${fname}: ${lines} lines (${size})${NC}"
            fi
        done
        echo ""

        [ ${#still_running[@]} -eq 0 ] && break
        sleep 10
    done

    # ── Summary ──
    banner "RECON COMPLETE"
    success "All results saved to: ${BOLD}$OUTDIR/${NC}"
    echo ""
    info "Key files:"
    ls -lhS "$OUTDIR"/ 2>/dev/null | awk 'NR>1{printf "    %-45s %s\n", $NF, $5}'
    echo ""

    if [ "$HAS_CREDS" = true ]; then
        info "Authenticated results (look for _auth suffix):"
        ls "$OUTDIR"/*auth* 2>/dev/null | while read f; do
            echo -e "    ${GREEN}$(basename "$f")${NC}"
        done
        echo ""
    fi

    warn "Next steps:"
    echo "  1. Review nmap_full.txt for service versions"
    echo "  2. Check feroxbuster/ffuf results for interesting endpoints"
    echo "  3. Review enum4linux output for users/shares"
    echo "  4. Check nuclei output for known vulnerabilities"
    [ ${#HOSTNAMES[@]} -gt 0 ] && echo "  5. Discovered hostnames: ${HOSTNAMES[*]}"
    if [ "$HAS_CREDS" = true ]; then
        echo "  6. Check kerberoast/asreproast hashes for cracking"
        echo "  7. Review BloodHound ZIP for AD attack paths"
    else
        echo ""
        warn "Got credentials now? Re-run with:"
        echo "  $0 $IP $NAME -u USER -p PASS -d DOMAIN"
    fi
}

main "$@"
