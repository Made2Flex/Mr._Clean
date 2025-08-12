#!/usr/bin/env bash

# This is a cleanup script for linux systems


# exit on error
# add || true at the end of commands that are expected to fail
set -euo pipefail


# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# ASCII Art Header
ascii_header() {
    cat << 'EOF'
 /$$      /$$                /$$$$$$  /$$                               /$$
| $$$    /$$$               /$$__  $$| $$                              | $$
| $$$$  /$$$$  /$$$$$$     | $$  \__/| $$  /$$$$$$   /$$$$$$  /$$$$$$$ | $$
| $$ $$/$$ $$ /$$__  $$    | $$      | $$ /$$__  $$ |____  $$| $$__  $$| $$
| $$  $$$| $$| $$  \__/    | $$      | $$| $$$$$$$$  /$$$$$$$| $$  \ $$|__/
| $$\  $ | $$| $$          | $$    $$| $$| $$_____/ /$$__  $$| $$  | $$
| $$ \/  | $$| $$       /$$|  $$$$$$/| $$|  $$$$$$$|  $$$$$$$| $$  | $$ /$$
|__/     |__/|__/      |__/ \______/ |__/ \_______/ \_______/|__/  |__/|__/

                                                       Qnk6IE1hZGUyRmxleA==
EOF
}

display_header() {
    echo -e "${BRIGHT_YELLOW}"
    ascii_header
    echo -e "${NC}"
}

# Color definitions
GREEN='\033[0;32m'
ORANGE='\033[1;33m'
BRIGHT_YELLOW='\033[1;93m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;36m'
NC='\033[0m' # No color

# Function to greet the user
greet_user() {
    local username=$(whoami)
    echo -e "${BRIGHT_YELLOW}Hello, $username-sama${NC}"
}

# Function to remove orphans
rm_orphans() {
    printf "${BRIGHT_YELLOW}Do You Want To Remove Orphaned Packages? (yes/no): ${NC}"
    read -rp answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    case "$answer" in
        y|yes|"")  # Accept 'y', 'yes', or empty input (Enter key)
            echo -e "${ORANGE}==>> Removing orphans..${NC}"
            sudo pacman -Rnsu $(pacman -Qdtq) || true
            echo -e "${GREEN}==>> Orphaned packages have been removed.${NC}"
            ;;
        n|no)      # Accept 'n' or 'no'
            echo -e "${BRIGHT_YELLOW}==>> Continuing Without Removing Orphaned Packages!${NC}"
            ;;
        *)         # Any other input
            echo -e "${RED}==>> Invalid Input. Please Enter 'yes' or 'no'.${NC}"
            rm_orphans  # Recursively call the function to retry
            ;;
    esac
}

# Function to run arch cleanup
pacman_cleanup() {
    if command -v pacman &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Pacman Cleanup in progress..${NC}"
        echo -e "${ORANGE}==>> Cleaning Pacman Cache...${NC}"
        yes | sudo pacman -Scc || true
        echo -e "\n"  # needed for better formatting since the line above
        if command -v yay &> /dev/null 2>&1; then
            echo -e "${ORANGE}==>> Cleaning yay build files...${NC}"
            yay -Sc --noconfirm || true
        fi
    fi
}

# Function to run pamac cleanup
pamac_cleanup() {
    if command -v pamac &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Pamac Cleanup in progress..${NC}"
        sudo pamac clean -v --keep 0 --no-confirm > /dev/null 2>&1
        sudo pamac clean -v --build-files --keep 0 --no-confirm > /dev/null 2>&1
    fi
}

# Function to run debian cleanup
apt_cleanup() {
    if command -v apt &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Apt Cleanup in progress..${NC}"

        echo -e "${ORANGE}==>> Clearing APT Cache...${NC}"
        sudo apt-get clean
        sudo rm -rf /var/log/apt/*

        echo -e "${ORANGE}==>> Removing Orphan Configurations...${NC}"
        sudo apt-get purge -y $(dpkg -l | awk '/^rc/ { print $2 }')

        echo -e "${ORANGE}==>> Removing Unneeded packages...${NC} "
        sudo apt-get autoremove --purge -y
        echo -e "${GREEN}==>> Cleanup Completed!${NC}"
    fi
}

# Function to run dnf cleanup
dnf_cleanup() {
    if command -v dnf &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> DNF Cleanup in progress..${NC}"

        echo -e "${ORANGE}==>> Cleaning DNF cache...${NC}"
        sudo dnf clean all

        echo -e "${ORANGE}==>> Removing old kernels...${NC}"
        sudo dnf autoremove --oldinstallonly --setopt=installonly_limit=2 -y

        echo -e "${ORANGE}==>> Removing orphaned packages...${NC}"
        sudo dnf autoremove -y

        echo -e "${ORANGE}==>> Cleaning package cache...${NC}"
        sudo dnf clean packages

        echo -e "${GREEN}==>> DNF cleanup completed!${NC}"
    fi
}

# Function to run zypper cleanup (openSUSE)
zypper_cleanup() {
    if command -v zypper &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Zypper Cleanup in progress..${NC}"

        echo -e "${ORANGE}==>> Cleaning Zypper cache...${NC}"
        sudo zypper clean

        echo -e "${ORANGE}==>> Removing orphaned packages...${NC}"
        sudo zypper packages --orphaned | awk 'NR>2 {print $3}' | xargs -r sudo zypper remove -y

        echo -e "${ORANGE}==>> Removing old kernels...${NC}"
        sudo zypper purge-kernels

        echo -e "${ORANGE}==>> Cleaning package cache...${NC}"
        sudo zypper clean --all

        echo -e "${GREEN}==>> Zypper cleanup completed!${NC}"
    fi
}

# Function to run emerge cleanup (Gentoo)
emerge_cleanup() {
    if command -v emerge &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Emerge Cleanup in progress..${NC}"

        echo -e "${ORANGE}==>> Cleaning Portage cache...${NC}"
        sudo emerge --depclean

        echo -e "${ORANGE}==>> Removing unused packages...${NC}"
        sudo emerge --unmerge --ask=n $(emerge --depclean --pretend | grep -E "^WARNING: .* packages are no longer needed" | sed 's/.*packages are no longer needed: //' | tr ' ' '\n' | grep -v "^$")

        echo -e "${ORANGE}==>> Cleaning distfiles...${NC}"
        sudo eclean-dist --deep

        echo -e "${ORANGE}==>> Cleaning packages...${NC}"
        sudo eclean-pkg --deep

        echo -e "${ORANGE}==>> Updating Portage tree...${NC}"
        sudo emerge --sync

        echo -e "${GREEN}==>> Emerge cleanup completed!${NC}"
    fi
}

# Function to list orphans if any
list_orphans() {
    if command -v pacman &> /dev/null 2>&1; then
        # Suppress output and only show orphans if they exist
        local orphans=$(pacman -Qdtq 2>/dev/null)
        if [ -n "$orphans" ]; then
            echo -e "${ORANGE}==>> Orphaned packages detected:${NC}"
            echo "$orphans"
            rm_orphans
        else
            echo -e "${GREEN}==>> No Pacman orphaned packages found.${NC}"
        fi
    fi
}

# Function to perform housekeeping tasks
perform_housekeeping() {
    LOG_FILE="$SCRIPT_DIR/mr_clean.log"

    echo -e "${ORANGE}==>> Current disk usage...${NC}"
    df / ~
    sleep 1

    echo -e "${BRIGHT_YELLOW}==>> House-Keeping in progress..${NC}"
    echo -e "${LIGHT_BLUE}==>> Please enter your password to continue...${NC}"
    sudo -v

    echo -e "${ORANGE}==>> Clearing Cache...${NC}"
    rm -rf ~/.cache/*
    #du -sh ~/.cache/*

    echo -e "${ORANGE}==>> Clearing Thumbnail Cache...${NC}"
    rm -rf ~/.cache/thumbnails/*

    echo -e "${ORANGE}==>> Deleting Logs older than 5 days...${NC}"

    # Remove logs older than 5 days
    sudo find /var/log -type f -name "*.log" -mtime +5 -delete 2>/dev/null

    echo -e "${ORANGE}==>> Current Journal Size:${NC}"
    journalctl --disk-usage
    echo -e "${ORANGE}==>> Vacuuming Journal To ~10MBs...${NC}"
    sudo journalctl --vacuum-size=10M

    echo -e "${ORANGE}==>> Rotating Logs...${NC}"
    sudo logrotate -f /etc/logrotate.conf

    echo -e "${ORANGE}==>> Cleaning Temporary Files...${NC}"
    # Remove all files except mr_clean.log - suppress errors if no files found
    find /tmp -type f -not -name "mr_clean.log" -delete 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    sudo rm -rf ~/.old 2>/dev/null || true

    # Run distribution-specific cleanup
    pacman_cleanup
    pamac_cleanup
    apt_cleanup
    dnf_cleanup
    zypper_cleanup
    emerge_cleanup

    echo -e "${ORANGE}==>> Listing orphans, if any...${NC}"
    list_orphans

    echo -e "${GREEN}==>> Housekeeping Complete.${NC}"
}

# Function to install libnotify dependency
install_libnotify() {
    echo -e "${LIGHT_BLUE}==>> Installing libnotify dependency...${NC}"

    # Detect package manager and install libnotify
    if command -v pacman &> /dev/null 2>&1; then
        echo -e "${ORANGE}==>> Detected Arch Linux system${NC}"
        sudo pacman -S --noconfirm --color=auto libnotify
    elif command -v apt &> /dev/null 2>&1; then
        echo -e "${ORANGE}==>> Detected Debian/Ubuntu system${NC}"
        sudo apt-get update
        sudo apt-get install -y libnotify-bin
    elif command -v dnf &> /dev/null 2>&1; then
        echo -e "${ORANGE}==>> Detected Fedora/RHEL system${NC}"
        sudo dnf install -y libnotify
    elif command -v zypper &> /dev/null 2>&1; then
        echo -e "${ORANGE}==>> Detected openSUSE system${NC}"
        sudo zypper install -y libnotify-tools
    elif command -v emerge &> /dev/null 2>&1; then
        echo -e "${ORANGE}==>> Detected Gentoo system${NC}"
        sudo emerge --ask=n sys-apps/libnotify
    else
        echo -e "${RED}!!! Unsupported package manager detected!${NC}"
        echo -e "${ORANGE}==>> Please install libnotify manually for your distribution.${NC}"
        echo -e "${ORANGE}==>> Package name is usually 'libnotify' or 'libnotify-bin'.${NC}"
        exit 1
    fi

    # Verify installation
    if command -v notify-send &> /dev/null 2>&1; then
        echo -e "${GREEN}==>> libnotify successfully installed.${NC}"
    else
        echo -e "${RED}!!! Failed to install libnotify.${NC}"
        echo -e "${ORANGE}==>> Please install it manually and run the script again.${NC}"
        exit 1
    fi
}

# Function to check and install dependencies
check_dependencies() {
    if ! command -v notify-send &> /dev/null 2>&1; then
        echo -e "${BRIGHT_YELLOW}==>> notify-send not found. This script uses it to display visual notifications. Especially helpful when running the script in the background.${NC}"
        install_libnotify
    fi
}

# Main function
main() {
    # Check dependencies first
    check_dependencies

    # Redirect output to log file and console
    {
        notify-send -t 3000 -u normal "Mr. Clean" "System Cleanup Started" --icon=/usr/share/icons/Papirus-Dark/64x64/categories/administration.svg
        display_header
        greet_user

        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        echo "-------------------------------------------"
        echo "Mr. Clean Started: $TIMESTAMP"
        echo "-------------------------------------------"

        perform_housekeeping

        echo "-------------------------------------------"
        echo "Mr. Clean Completed: $(date "+%Y-%m-%d %H:%M:%S")"
        echo "-------------------------------------------"

        notify-send -t 4000 -u normal "Mr. Clean" "System Cleanup Completed" --icon=/usr/share/icons/Papirus-Dark/64x64/categories/administration.svg
    } 2>&1 | tee >(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> $SCRIPT_DIR/mr_clean.log)
}

# Clean me!
main
