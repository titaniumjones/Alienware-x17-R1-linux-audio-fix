#!/bin/bash

set -euo pipefail

# Ensure the installer is running with sudo
if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
    echo "Run this installer using sudo from your normal user account."
    exit 1
fi

TARGET_USER="$SUDO_USER"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check that hda-verb is installed
if [ ! -x /usr/bin/hda-verb ]; then
    echo "hda-verb is not installed."
    echo "On Debian, Ubuntu or Linux Mint, run:"
    echo "sudo apt install alsa-tools"
    exit 1
fi

# Verify the expected audio codec
if ! grep -qx 'Codec: Realtek ALC289' /proc/asound/card1/codec#0 2>/dev/null; then
    echo "Realtek ALC289 not found at the expected address."
    echo "Detected codecs:"
    grep -H '^Codec:' /proc/asound/card*/codec* || true
    echo "Please refer to the README before continuing."
    exit 1
fi

if [ ! -c /dev/snd/hwC1D0 ]; then
    echo "Expected HDA hardware device not found."
    exit 1
fi

# Check that all configuration files are present
for FILE in woofer-fix.service alienware-woofer-watch alienware-audio.conf alienware-woofer woofer-fix.sudoers
do
    if [ ! -f "$SCRIPT_DIR/config/$FILE" ]; then
        echo "Missing configuration file: $FILE"
        exit 1
    fi
done

# Prepare and validate sudoers configuration
TEMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TEMP_SUDOERS"' EXIT

sed "s/YOUR_USERNAME/$TARGET_USER/g" \
    "$SCRIPT_DIR/config/woofer-fix.sudoers" > "$TEMP_SUDOERS"

visudo -cf "$TEMP_SUDOERS"

# Create user directories
install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/.local/bin"

install -d -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$TARGET_HOME/.config/systemd/user"

# Install watcher
install -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$SCRIPT_DIR/config/alienware-woofer-watch" \
    "$TARGET_HOME/.local/bin/alienware-woofer-watch"

# Install systemd user service
install -m 0644 -o "$TARGET_USER" -g "$TARGET_GROUP" \
    "$SCRIPT_DIR/config/woofer-fix.service" \
    "$TARGET_HOME/.config/systemd/user/woofer-fix.service"

# Install power-saving configuration
install -m 0644 \
    "$SCRIPT_DIR/config/alienware-audio.conf" \
    /etc/modprobe.d/alienware-audio.conf

# Install suspend/resume hook
install -m 0755 \
    "$SCRIPT_DIR/config/alienware-woofer" \
    /usr/lib/systemd/system-sleep/alienware-woofer

# Install restricted sudo permissions
install -m 0440 -o root -g root \
    "$TEMP_SUDOERS" \
    /etc/sudoers.d/woofer-fix

# Enable the user service
sudo -u "$TARGET_USER" \
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
    systemctl --user daemon-reload

sudo -u "$TARGET_USER" \
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
    systemctl --user enable --now woofer-fix.service

# Update initramfs
update-initramfs -u

echo ""
echo "Alienware woofer fix installed successfully."
echo "Please reboot your computer."
