#!/bin/bash

set -euo pipefail

# Ensure the uninstaller is running with sudo
if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
    echo "Run this uninstaller using sudo from your normal user account."
    exit 1
fi

TARGET_USER="$SUDO_USER"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER")"

# Stop and disable the user service
sudo -u "$TARGET_USER" \
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
    systemctl --user disable --now woofer-fix.service

# Remove installed configuration files
rm -f "$TARGET_HOME/.config/systemd/user/woofer-fix.service"
rm -f "$TARGET_HOME/.local/bin/alienware-woofer-watch"
rm -f /etc/modprobe.d/alienware-audio.conf
rm -f /usr/lib/systemd/system-sleep/alienware-woofer
rm -f /etc/sudoers.d/woofer-fix

# Reload systemd user configuration
sudo -u "$TARGET_USER" \
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
    systemctl --user daemon-reload

# Update initramfs
update-initramfs -u

echo ""
echo "Alienware woofer fix removed successfully."
echo "Please reboot your computer."
