#!/bin/sh

set -e

# 0. Run only if no real user other than root exists
USER_COUNT=$(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd | wc -l)
if [ "$USER_COUNT" -gt 0 ]; then
    echo "Non-root user(s) already exist. Skipping first-boot setup."
    exit 0
fi

echo "=== First Boot Setup ==="

# 1. Set root password
echo "Set password for root:"
passwd root

# 2. Create user vinay
read -p "Enter new username: " USERNAME
echo "Creating user '$USERNAME'..."
useradd -m -s /bin/bash "$USERNAME"
passwd "$USERNAME"
usermod -aG sudo "$USERNAME"

# 3. Enable sudo group in /etc/sudoers if not already
if ! grep -q "^%sudo" /etc/sudoers; then
    echo "%sudo ALL=(ALL:ALL) ALL" >> /etc/sudoers
    echo "Added %sudo rule to /etc/sudoers"
fi

# 4. Ensure openssh config allows password login
SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    sed -i 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"

    grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
    grep -q "^PermitRootLogin" "$SSHD_CONFIG" || echo "PermitRootLogin yes" >> "$SSHD_CONFIG"

    echo "Configured sshd_config for password and root login. Restart will take effect on reboot."
else
    echo "Warning: $SSHD_CONFIG not found. Skipped SSH config."
fi

# 5. Set up locale
LOCALE_NAME="en_US.UTF-8"
LOCALE_DIR="/usr/lib/locale"

echo "Ensuring $LOCALE_DIR exists..."
mkdir -p "$LOCALE_DIR"

if ! locale -a | grep -q "$LOCALE_NAME"; then
    echo "Generating locale $LOCALE_NAME..."
    localedef -i en_US -f UTF-8 "$LOCALE_NAME"
fi

echo "LANG=$LOCALE_NAME" > /etc/locale.conf
export LANG=$LOCALE_NAME

echo "=== First Boot Setup Complete ==="

# 6. Clean up
rm -- "$0"
