#!/usr/bin/env bash

# Exit on any error
set -e

MAINTENANCE_SCRIPT="${HOME}/scripts/mr_clean.sh"

# Function to print colored text
print_color() {
    local color=$1
    local text=$2
    case $color in
        "red") echo -e "\033[1;31m${text}\033[0m" ;;
        "green") echo -e "\033[1;32m${text}\033[0m" ;;
        "yellow") echo -e "\033[1;33m${text}\033[0m" ;;
        "blue") echo -e "\033[34m${text}\033[0m" ;;
        "magenta") echo -e "\033[35m${text}\033[0m" ;;
        "cyan") echo -e "\033[36m${text}\033[0m" ;;
        "white") echo -e "\033[37m${text}\033[0m" ;;
        *) echo "${text}" ;;
    esac
}

# Utility function for color-changing a line
dynamic_color_line() {
    local message="$1"
    #local colors=("red" "yellow" "green" "cyan" "magenta" "blue")
    local colors=("\033[1;31m" "\033[1;33m" "\033[1;32m" "\033[1;36m" "\033[1;35m" "\033[1;34m")
    local NC="\033[0m"
    local delay=0.1
    local iterations=${2:-30}  # Default 30 iterations, but allow customization

    {
        for ((i=1; i<=iterations; i++)); do
            # Cycle through colors
            color=${colors[$((i % ${#colors[@]}))]}

            # Use \r to return to start of line, update with new color
            printf "\r${color}==>> ${message}${NC}"

            sleep "$delay"
        done

        # Final clear line
        #printf "\r\033[K"
        # Add a newline to move to the next line
        printf "\n"
    } >&2
}

# Github clone function
clone_github() {
    local repo_url="$1"
    local target_dir="$2"

    if git clone "${repo_url}" "${target_dir}"; then
        print_color "green" "✓ Repository cloned successfully!"
        return 0
    else
        print_color "red" "!! Failed to clone repository"
        return 1
    fi
}

# Function to check if service and timer files exits
check_files() {
    # Check if target script exists
    if [ ! -f "${MAINTENANCE_SCRIPT}" ]; then
        print_color "red" "!! mr_clean.sh script not found: $(print_color "blue" "${MAINTENANCE_SCRIPT}")"

        read -rp "$(print_color "magenta" "Would you like to download it from GitHub? (yes/no) ")" download_choice

        # Convert input to lowercase
        download_choice=$(echo "$download_choice" | tr '[:upper:]' '[:lower:]')

        case "$download_choice" in
            y|yes|"")
                # Check if git is installed, if not install it
                if ! command -v git &> /dev/null; then
                    print_color "yellow" "==>> Git is not installed. Installing git..."
                    if command -v apt &> /dev/null; then
                        sudo apt update && sudo apt install -y git
                    elif command -v pacman &> /dev/null; then
                        sudo pacman -S --noconfirm git
                    else
                        print_color "red" "!! Package manager not supported. Please install git manually."
                        exit 1
                    fi
                fi

                print_color "yellow" "==>> Downloading Mr. Clean script from GitHub..."

                if [ ! -d "$(dirname "${MAINTENANCE_SCRIPT}")" ]; then
                    print_color "red" "!! Directory does not exist!"
                    print_color "yellow" "==>> Creating directory..."
                    # Create directory if it doesn't exist
                    mkdir -p "$(dirname "${MAINTENANCE_SCRIPT}")"

                    # Verify directory creation
                    if [ -d "$(dirname "${MAINTENANCE_SCRIPT}")" ]; then
                        print_color "green" "✓ Directory created successfully: $(dirname "${MAINTENANCE_SCRIPT}")"
                    else
                        print_color "red" "!! Failed to create directory: $(dirname "${MAINTENANCE_SCRIPT}")"
                        exit 1
                    fi
                fi

                # Clone the repository (public URL)
                if clone_github "https://github.com/Made2Flex/Mr._Clean.git" "$(dirname "${MAINTENANCE_SCRIPT}")"/Mr._Clean; then
                    cd "$(dirname "${MAINTENANCE_SCRIPT}")/Mr._Clean"
                    cp mr_clean.sh "${MAINTENANCE_SCRIPT}"

                    # Verify the file was copied correctly
                    if [ -f "${MAINTENANCE_SCRIPT}" ]; then
                        print_color "green" "✓ Successfully copied script to: $(dirname "${MAINTENANCE_SCRIPT}")"
                        cd ..
                        rm -rf Mr._Clean
                        dynamic_color_line "Making the script executable..."
                        chmod +x -v "${MAINTENANCE_SCRIPT}"
                    else
                        print_color "red" "!! Failed to copy the script."
                        exit 1
                    fi
                else
                    print_color "red" "!! Failed to download the script."
                    print_color "magenta" "==>> Please clone the repository manually from $(print_color "blue" "https://github.com/Made2Flex/Mr._Clean.git")"
                    exit 1
                fi
                ;;
            n|no)
                print_color "red" "!! Script not found. Please manually source '$(print_color "white" "mr_clean.sh")' script."
                print_color "magenta" "==>> You can clone it from: $(print_color "blue" "https://github.com/Made2Flex/Mr._Clean.git")"
                exit 1
                ;;
            *)
                print_color "red" "Invalid input. Please answer 'yes' or 'no'."
                exit 1
                ;;
        esac
    fi
    # Check if service and timer files exist
    if [ -f /etc/systemd/system/mr-clean.service ] && [ -f /etc/systemd/system/mr-clean.timer ]; then
        print_color "red" "!! Service and timer files already exist!"
        sleep 1

        print_color "yellow" "==>> Stopping existing timer service..."
        sudo systemctl stop mr-clean.timer
        print_color "green" "==>> Timer service stopped successfully."
        print_color "yellow" "==>> Disabling existing timer service..."
        sudo systemctl disable mr-clean.timer
        print_color "green" "==>> Timer service disabled successfully."
        sleep 1

        print_color "yellow" "==>> Removing existing files..."
        sudo rm -fv /etc/systemd/system/mr-clean.service /etc/systemd/system/mr-clean.timer
        print_color "green" "==>> Existing files removed."
    fi
}

# Function to find an available terminal emulator
find_terminal_emulator() {
    local terminals=(
        "gnome-terminal"   # GNOME
        "konsole"          # KDE
        "xfce4-terminal"   # XFCE
        "mate-terminal"    # MATE
        "lxterminal"       # LXDE
        "alacritty"        # Alacritty
        "kitty"            # Kitty
        "terminator"       # Terminator
        "urxvt"            # URxvt
        "xterm"            # Fallback X11 terminal
    )

    for terminal in "${terminals[@]}"; do
        if command -v "$terminal" &> /dev/null; then
            echo "$terminal"
            return 0
        fi
    done

    print_color "red" "!! No compatible terminal emulator found."
    return 1
}

# Function to create the service file
srv_creation() {
    # Find the terminal emulator
    TERMINAL=$(find_terminal_emulator)
    
    if [ -z "$TERMINAL" ]; then
        notify-send "Error" "Cannot create service: No terminal emulator found" --icon=dialog-error
        print_color "red" "!! Cannot create service."
        exit 1
    fi

    local username=$(whoami)

    print_color "yellow" "==>> Creating service with terminal: $(print_color "blue" "$TERMINAL")"

    sudo bash -c "cat > /etc/systemd/system/mr-clean.service << EOL
[Unit]
Description=Mr. Clean System Maintenance
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
ExecStart=$TERMINAL -e ${MAINTENANCE_SCRIPT}
User=$username
StandardOutput=journal
StandardError=journal
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL"
    print_color "green" "  >> Service file created at: $(print_color "blue" "/etc/systemd/system/mr-clean.service")"

    # create the timer file
    print_color "yellow" "==>> Creating timer..."
    sudo bash -c 'cat > /etc/systemd/system/mr-clean.timer << EOL
[Unit]
Description=Run Mr. Clean Weekly

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=15 seconds
AccuracySec=1us

[Install]
WantedBy=timers.target
EOL'
    print_color "green" "  >> Timer created at: $(print_color "blue" "/etc/systemd/system/mr-clean.timer")"

}

# Function to check if the timer is active
check_timer() {
    print_color "yellow" "==>> Checking if the timer sevice is active..."
    if sudo systemctl is-active mr-clean.timer | grep -q "active" ; then
        print_color "white" "  >> mr.clean timer is $(print_color "green" "Enabled") and $(print_color "green" "Active")."
    else
        print_color "red" "!! mr.clean timer is $(print_color "white" "Inactive")."
        sleep 1
        print_color "magenta" "==>> Please check " && print_color "white" "systemctl status mr-clean.timer" && print_color "magenta" " for more details."
    fi
}

# setup systemd timer service
setup_systemd() {

# Reload systemd configurations
print_color "yellow" "==>> Reloading systemd..."
sudo systemctl daemon-reload

# Enable timer
print_color "yellow" "==>> Enabling timer..."
sudo systemctl enable mr-clean.timer

# Start the timer
print_color "yellow" "==>> Starting timer service..."
sudo systemctl start mr-clean.timer

# check timer service
check_timer

print_color "green" "==>> mr.clean has been successfully set up!"

}

# Alchemy
main() {
    check_files
    srv_creation
    setup_systemd
}

# Mr.Clean!!!!
main
#Qnk6IE1hZGUyRmxleA==
