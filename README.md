# Mr._Clean: Linux System Cleanup Utility

## 🧹 Overview

Mr._Clean is a comprehensive system cleanup and maintenance script designed for modern Linux systems. It provides an interactive way to perform system housekeeping tasks, helping you maintain a clean and optimized system.

## ✨ Features

- 🗑️ Temporary file cleanup
- 🧹 Cache clearing
- 📋 Log management
- 🗂️ Orphaned package detection and removal
- 🔍 Disk usage reporting
- 📣 Desktop notifications

## 🛠️ Prerequisites

- Linux system
- `sudo` access
- Packages: 
  - `pacman` (for Arch based systems)
  - `yay` (optional, for AUR cleanup)
  - `pamac` (optional, for Manjaro-specific cleanup)
  - `apt` (optional, for Debian-specific cleanup)
  - `notify-send` (for desktop notifications)

## 🚀 Installation

1. Clone the repository:

git clone https://github.com/Made2Flex/Mr._Clean.git

2. Make the script executable:

chmod +x -v mr_clean.sh

3. Run the script:

./mr_clean.sh

## Set-up Systemd timer

1. run the script:

./mr_Clean_timer.sh

It will clone mr_clean.sh and set-up a systemd timer.


### What Mr._Clean Does

- Removes temporary files
- Clears system and user caches
- Manages system logs
- Identifies and optionally removes orphaned packages
- Provides disk usage information
- Sends desktop notifications

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. see the [LICENSE](LICENSE) file for details.

## 🙌 Acknowledgments

- Inspired by the need for simple, effective system maintenance
