sudo apt update
sudo apt install python3 python3-dev python3-pip python3-venv nmap smbmap john libsasl2-dev libldap2-dev libkrb5-dev ntpdate wget zip unzip systemd-timesyncd pipx swig curl jq openssl enum4linux-ng -y && sudo apt autoremove -y

pip3 install --user pipx PyYAML alive-progress xlsxwriter sectools typer --upgrade
pipx ensurepath
pipx install git+https://github.com/dirkjanm/ldapdomaindump.git --force
pipx install git+https://github.com/Pennyw0rth/NetExec.git --force
pipx install git+https://github.com/franc-pentest/ldeep.git --force
pipx install git+https://github.com/garrettfoster13/pre2k.git --force
pipx install git+https://github.com/p0dalirius/Coercer --force
pipx install git+https://github.com/p0dalirius/RDWAtool --force
