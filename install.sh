#!/bin/bash

version="1.1"
date="2023-10-17"
title="SSH TUI Panel v$version"

install_panel() {
    sudo rm -f ssh-panel.zip
    wget -O ssh-panel.zip https://github.com/vfarid/ssh-panel/archive/main.zip
    unzip ssh-panel.zip
    if [ ! -d "ssh-panel" ]; then
        sudo mkdir ssh-panel
    fi
    sudo rm -rf ssh-panel/*
    sudo mv ssh-panel-main/* ssh-panel/
    sudo rm -rf ssh-panel-main
    sudo rm -f ssh-panel.zip
    cd ssh-panel/
    curl -s "https://api.github.com/repos/vfarid/ssh-panel/commits/main" | jq -r .sha > version.info
    sudo mkdir -p /var/log/ssh-panel
    sudo chmod +x cron.sh panel.sh
    wget -O hogs.go https://raw.githubusercontent.com/boopathi/nethogs-parser/master/hogs.go
    sudo go build -o hogs hogs.go
    sudo rm -f hogs.go
    cron_job="*/5 * * * * sh $(pwd)/cron.sh"
    if ! crontab -l 2>/dev/null | grep -Fq "$cron_job"; then
        (crontab -l ; echo "$cron_job") | crontab
    fi
    sudo sh cron.sh
    cd ..
    sudo rm -f ssh-panel-install.sh
    echo -e "\n--------------------------------------------------------\nInstallation completed.\nYou may run \`cd ssh-panel && sh panel.sh\` to enter the panel.\n"
}

remove_panel() {
    sudo rm -rf ssh-panel
    cron_job="*/5 * * * * sh $(pwd)/ssh-panel/cron.sh"
    if crontab -l 2>/dev/null | grep -Fq "$cron_job"; then
        current_crontab=$(crontab -l 2>/dev/null)
        new_crontab=$(echo "$current_crontab" | grep -Fv "$cron_job")
        echo "$new_crontab" | crontab
    fi
}

echo "$title"
echo -e "Updating OS and installing required packages...\n--------------------------------------------------------\n"
if [ -x "$(command -v yum)" ]; then
    # CentOS/RHEL
    sudo yum -y update
    sudo yum -y install nethogs golang dialog bc coreutils unzip curl jq
elif [ -x "$(command -v apt-get)" ]; then
    # Debian/Ubuntu
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y update
    sudo apt-get -y install nethogs golang dialog bc coreutils unzip curl jq
    sudo DEBIAN_FRONTEND=interactive
else
    echo "Unsupported distribution or package manager"
    exit 1
fi

if [ -f "./ssh-panel/panel.sh" ]; then
    choice=$(dialog --clear --backtitle "$title" \
        --title "Upgrade/Uninstall Panel" \
        --menu "\nChoose an action:" 20 60 5 \
            1 "Upgrade Panel" \
            3 "Remove Existing Panel" \
            2 "Remove Existing Panel & Statistics" \
            4 "Exit" \
        2>&1 >/dev/tty)

    case "$choice" in
        1) # Upgrade Panel
            sudo rm -rf ssh-panel
            install_panel
            ;;
        
        2)
            remove_panel
            clear
            echo "SSH TUI Panel has been removed successfully."
            ;;
        
        3)
            prompt=$(dialog --clear --backtitle "$title" --title "Clear Statistics & Remove" \
                --inputbox "Enter \`REMOVE-ALL\` to confirm:" 10 60 2>&1 >/dev/tty)

            clear
            if [ "$prompt" = "REMOVE-ALL" ]; then
                remove_panel
                sudo rm -rf /var/log/ssh-panel
                echo "SSH TUI Panel and statistics have been removed successfully."
            else
                echo "Operation canceled!"
            fi
            ;;

        4)
            clear
            echo "Operation canceled!"
            ;;
    esac
else
    install_panel
fi
