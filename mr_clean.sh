#!/usr/bin/env bash

# This is a cleanup script for linux systems

SCRIPT_VERSION="1.0-1"
AUTHOR="TWFkZTJGbGV4"

# Exit on error, trace unset vars
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Color definitions
GREEN='\033[0;32m'
ORANGE='\033[1;33m'
BRIGHT_YELLOW='\033[1;93m'
RED='\033[0;31m'
BLUE='\033[1;34m'
LIGHT_BLUE='\033[1;36m'
NC='\033[0m' # No color

# Header
header() {
    cat << 'EOF'
 /$$      /$$                /$$$$$$  /$$                               /$$
| $$$    /$$$               /$$__  $$| $$                              | $$
| $$$$  /$$$$  /$$$$$$     | $$  \__/| $$  /$$$$$$   /$$$$$$  /$$$$$$$ | $$
| $$ $$/$$ $$ /$$__  $$    | $$      | $$ /$$__  $$ |____  $$| $$__  $$| $$
| $$  $$$| $$| $$  \__/    | $$      | $$| $$$$$$$$  /$$$$$$$| $$  \ $$|__/
| $$\  $ | $$| $$          | $$    $$| $$| $$_____/ /$$__  $$| $$  | $$
| $$ \/  | $$| $$       /$$|  $$$$$$/| $$|  $$$$$$$|  $$$$$$$| $$  | $$ /$$
|__/     |__/|__/      |__/ \______/ |__/ \_______/ \_______/|__/  |__/|__/
EOF
}

show_version() {
    echo -e "${GREEN}Version $SCRIPT_VERSION${NC}"
}

show_author() {
    local _timestamped_log

    if [[ -n "$AUTHOR" ]]; then
        local decoded_author
        decoded_author=$(echo "$AUTHOR" | base64 --decode 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            echo -e "${ORANGE}${decoded_author}${NC}"
        else
            echo -e "${RED}[ERROR]${NC} ${ORANGE}Failed to decode AUTHOR (not valid base64?)${NC}"
        fi
    else
        echo -e "${RED}[ERROR]${NC} ${ORANGE}AUTHOR variable is unset.${NC}"
    fi
}

help_me() {
    echo -e "${GREEN}This script runs maintainance for Linux system.${NC}"
    echo
    echo -e "${BLUE}Usage:${NC}"
    echo -e "  bash $0 ${BLUE}[OPTIONS]${NC}"
    echo
    echo -e "${BLUE}Options:${NC}"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version       Shows the script's version number"
    echo "  -a, --author        Display author's name"
    echo
    echo -e "${ORANGE}Note:${NC} This script requires root privilege for certain operations."
    echo -e "      It comes as is, with ${RED}NO GUARANTEE!${NC}"
}

display_header() {
    echo -e "${BRIGHT_YELLOW}"
    header
    echo -e "${NC}"
}

# Function to greet the user
greet_user() {
    echo -e "${BRIGHT_YELLOW}Hello, $USER ${NC}"
}

# Function to remove orphans
rm_orphans() {
    local orphans_list
    local answer=""

    orphans_list="$(pacman -Qdtq 2>/dev/null || true)"

    while true; do
        printf "%bDo You Want To Remove Orphaned Packages? (yes/no): %b" \
            "${BRIGHT_YELLOW}" "${NC}"

        read -r answer || answer=""
        answer="${answer,,}"

        case "${answer}" in
            y|yes|"")
                echo -e "${ORANGE}==>> Removing orphans..${NC}"
                sudo pacman -Rnsu --noconfirm ${orphans_list} || true
                echo -e "${GREEN}==>> Orphaned packages removed.${NC}"
                break
                ;;
            n|no)
                echo -e "${BRIGHT_YELLOW}==>> Skipping orphan removal.${NC}"
                break
                ;;
            *)
                echo -e "${RED}==>> Please answer yes or no.${NC}"
                ;;
        esac
    done
}


# Function to run arch cleanup
pacman_cleanup() {
    if ! command -v pacman >/dev/null 2>&1; then
        return
    fi

    echo -e "${LIGHT_BLUE}==>> Pacman Cleanup in progress..${NC}"

    # Ensure paccache exists
    if ! command -v paccache >/dev/null 2>&1; then
        echo -e "${ORANGE}==>> pacman-contrib not installed; skipping cache cleanup.${NC}"
        return
    fi

    echo -e "${ORANGE}==>> Cleaning Pacman cache...${NC}"

    sudo paccache -ruk0 || true

    if [[ -d /var/cache/pacman/pkg ]]; then
        sudo find /var/cache/pacman/pkg \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -name 'download-*' \
            -exec rm -rf -- {} + 2>/dev/null || true
    fi

    if command -v yay >/dev/null 2>&1; then
        echo -e "${ORANGE}==>> Cleaning yay build cache...${NC}"
        yay -Yc --noconfirm || true
    fi
}

# Function to run pamac cleanup
pamac_cleanup() {
    if command -v pamac &> /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}==>> Pamac Cleanup in progress..${NC}"
        sudo pamac clean -v --keep 0 --no-confirm > /dev/null 2>&1 || true
        sudo pamac clean -v --build-files --keep 0 --no-confirm > /dev/null 2>&1 || true
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
        local rc_packages
        rc_packages="$(dpkg -l | awk '/^rc/ { print $2 }')"
        if [[ -n "${rc_packages}" ]]; then
            sudo apt-get purge -y ${rc_packages}
        fi

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
    if [[ ! -t 0 ]]; then
        echo -e "${BRIGHT_YELLOW}==>> Non-interactive shell detected. Skipping orphan removal.${NC}"
        return
    fi

    if command -v pacman &> /dev/null 2>&1; then
        local orphans
        orphans="$(pacman -Qdtq 2>/dev/null || true)"
        if [[ -n "${orphans}" ]]; then
            echo -e "${ORANGE}==>> Orphaned packages detected:${NC}"
            echo "${orphans}"
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
    df -h /
    sleep 1

    echo -e "${BRIGHT_YELLOW}==>> House-Keeping in progress..${NC}"
    echo -e "${LIGHT_BLUE}==>> Please enter your password to continue...${NC}"
    sudo -v

    echo -e "${ORANGE}==>> Clearing Cache...${NC}"
    [[ -d "${HOME}/.cache" ]] && rm -rf "${HOME}/.cache/"*
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

    echo -e "${ORANGE}==>> Housekeeping Complete.${NC}"
}

# Function to install libnotify dependency
install_notify-send() {
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
        install_notify-send
    fi
}

arg_parser() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                help_me
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -a|--author)
                show_author
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                echo -e "Use ${BLUE}--help${NC} for usage information"
                exit 1
                ;;
            *)
                echo -e "${RED}Unexpected argument: $1${NC}"
                echo -e "Use ${BLUE}--help${NC} for usage information"
                exit 1
                ;;
        esac
        shift
    done
}

# Main function
main() {
    arg_parser "$@"
    check_dependencies

    {
        notify-send -t 5000 -u normal "Mr. Clean" "System Cleanup Started" --icon=/usr/share/icons/Papirus-Dark/64x64/categories/administration.svg
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

        notify-send -t 9000 -u normal "Mr. Clean" "System Cleanup Completed" --icon=/usr/share/icons/Papirus-Dark/64x64/categories/administration.svg
    } 2>&1 | tee >(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" >> "$SCRIPT_DIR/mr_clean.log")
}

# Clean me!
main "$@"
