#!/usr/bin/bash

# ASCII Art Header
ascii_art_header() {
    cat << 'EOF'
 /$$      /$$                /$$$$$$  /$$                               /$$
| $$$    /$$$               /$$__  $$| $$                              | $$
| $$$$  /$$$$  /$$$$$$     | $$  \__/| $$  /$$$$$$   /$$$$$$  /$$$$$$$ | $$
| $$ $$/$$ $$ /$$__  $$    | $$      | $$ /$$__  $$ |____  $$| $$__  $$| $$
| $$  $$$| $$| $$  \__/    | $$      | $$| $$$$$$$$  /$$$$$$$| $$  \ $$|__/
| $$\  $ | $$| $$          | $$    $$| $$| $$_____/ /$$__  $$| $$  | $$
| $$ \/  | $$| $$       /$$|  $$$$$$/| $$|  $$$$$$$|  $$$$$$$| $$  | $$ /$$
|__/     |__/|__/      |__/ \______/ |__/ \_______/ \_______/|__/  |__/|__/'
EOF
}

# Color definitions
GREEN='\033[0;32m'
ORANGE='\033[1;33m'
BRIGHT_YELLOW='\033[1;93m'
RED='\033[0;31m'
BLUE='\033[0;34m'
LIGHT_BLUE='\033[1;36m'
NC='\033[0m' # No color

# Function to greet the user
greet_user() {
    local username=$(whoami)
    echo -e "${BRIGHT_YELLOW}Hello, $username-sama!${NC}"
}

# Function to ask y/n and kill orphans
askuser() {
    read -rp "Do You Want To Remove Orphaned Packages? (yes/no): " answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

    case "$answer" in
        y|yes|"")  # Accept 'y', 'yes', or empty input (Enter key)
            echo -e "${BRIGHT_YELLOW}==>> Now Witness Meow POWA!!!!!!${NC}"
            sudo pacman -Rnsu $(pacman -Qdtq)
            echo -e "${GREEN}==>> Orphaned Packages Removed.${NC}"
            ;;
        n|no)      # Accept 'n' or 'no'
            echo -e "${BRIGHT_YELLOW}==>> Continuing Without Removing Orphaned Packages!${NC}"
            ;;
        *)         # Any other input
            echo -e "${RED}==>> Invalid Input. Please Enter 'yes' or 'no'.${NC}"
            askuser  # Recursively call the function to retry
            ;;
    esac
}

# Function to detect and run arch specific cleanup
arch_cleanup() {
    if command -v pacman &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Arch Cleanup in progress!!${NC}"
        echo -e "${ORANGE}==>> Cleaning Pacman Cache...${NC}"
        sudo pacman -Scc --noconfirm
        if command -v yay &> /dev/null 2>&1; then
            echo -e "${ORANGE}==>> Cleaning yay build files...${NC}"
            yay -Sc --noconfirm
        else
            echo -e "${RED}!!! yay not found!${NC}"
            echo -e "${ORANGE}==>> Skipping yay build files cleanup.${NC}"
        fi
    else
        echo -e "${RED}!!! pacman not found!${NC}"
        echo -e "${ORANGE}==>> Skipping arch cleanup.${NC}"
    fi
}

# Function to detect and run manjaro specific cleanup
manjaro_cleanup() {
    if command -v pamac &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Manjaro Specific Cleanup in progress!!${NC}"
        sudo pamac clean --keep 0 --no-confirm
        sudo pamac clean -v --build-files --keep 0 --no-confirm
    else
        echo -e "${RED}!!! pamac not found!${NC}"
        echo -e "${ORANGE}==>> Skipping Manjaro cleanup.${NC}"
    fi
}

# Function to detect and run debian specific cleanup
debian_cleanup() {
    if command -v apt &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Debian Cleanup in progress!!${NC}"

        echo -e "${ORANGE}==>> Clearing APT Cache...${NC}"
        sudo apt-get clean

        echo -e "${ORANGE}==>> Removing Orphan Configurations...${NC}"
        sudo apt-get purge -y $(dpkg -l | awk '/^rc/ { print $2 }')

        echo -e "${ORANGE}==>> Removing Old Kernels and Unneeded packages...${NC} "
        sudo apt-get autoremove --purge -y
        echo -e "${GREEN}==>> Debian Cleanup Completed!${NC}"
    else
        echo -e "${RED}!!! apt not found!${NC}"
        echo -e "${ORANGE}==>> Skipping Debian specific cleanup.${NC}"
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
            askuser
        else
            echo -e "${GREEN}==>> No Pacman orphaned packages found.${NC}"
        fi
    else
        echo -e "${RED}!!! pacman not found!${NC}"
        echo -e "${ORANGE}==>> Skipping orphaned packages check.${NC}"
    fi
}

# Function to perform housekeeping tasks
perform_housekeeping() {
    # Ensure log directory exists and is writable
    LOG_FILE="/tmp/mr_clean.log"

    echo -e "${ORANGE}==>> Current disk usage...${NC}"
    df / ~
    sleep 1

    echo -e "${BRIGHT_YELLOW}==>> House-Keeping in progress!!${NC}"
    echo -e "${BLUE}==>> Please enter your password to continue...${NC}"
    sudo -v

    echo -e "${ORANGE}==>> Cleaning Temporary Files...${NC}"
    # Remove all files except mr_clean.log
    find /tmp -type f -not -name "mr_clean.log" -delete 2>/dev/null
    sudo rm -rf /var/tmp/*
    sudo rm -rf ~/.old
	sudo rm -rf /var/log/apt/*

    echo -e "${ORANGE}==>> Clearing Cache...${NC}"
    rm -rf ~/.cache/*
    #du -sh ~/.cache/*

    echo -e "${ORANGE}==>> Clearing Thumbnail Cache...${NC}"
    rm -rf ~/.cache/thumbnails/*

    echo -e "${ORANGE}==>> Deleting Logs older than 5 days...${NC}"
    #sudo rm -rf /var/log/*
    # Romove logs older than 5 days
    sudo find /var/log -type f -name "*.log" -mtime +5 -delete 2>/dev/null

    echo -e "${ORANGE}==>> Journal Current Size...${NC}"
    journalctl --disk-usage
    echo -e "${ORANGE}==>> Vaccumming Journal To ~10MBs...${NC}"
    journalctl --vacuum-size=10M

    echo -e "${ORANGE}==>> Rotating Logs...${NC}"
    sudo logrotate -f /etc/logrotate.conf

    arch_cleanup
    manjaro_cleanup
    debian_cleanup

    echo -e "${ORANGE}==>> Listing orphans, if any...${NC}"
    list_orphans

    echo -e "${GREEN}==>> Housekeeping Complete!${NC}"
}

# Main function
main() {
    # Redirect output to log file and console
    {
        notify-send "Mr. Clean" "System Cleanup Started" --icon=system-cleanup
        echo -e "${BRIGHT_YELLOW}"
        ascii_art_header
        echo -e "${NC}"
        greet_user

        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        echo "-------------------------------------------"
        echo "Mr. Clean Started: $TIMESTAMP"
        echo "-------------------------------------------"

        perform_housekeeping

        echo "-------------------------------------------"
        echo "Mr. Clean Completed: $(date "+%Y-%m-%d %H:%M:%S")"
        echo "-------------------------------------------"

        notify-send "Mr. Clean" "System Cleanup Completed" --icon=system-cleanup
    } 2>&1 | tee >(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> $HOME/scripts/mr_clean.log)
}

# Clean Me!
main
