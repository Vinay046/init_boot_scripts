#!/bin/sh

set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting first boot setup"

# 0. Run only if no real user other than root exists
USER_COUNT=$(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd | wc -l)
if [ "$USER_COUNT" -gt 0 ]; then
    log "Non-root user(s) already exist. Skipping first-boot setup."
    exit 0
fi

log "=== First Boot Setup ==="

# 1. Set root password
log "Setting password for root..."
passwd root || {
    log "Failed to set root password"
    exit 1
}

# 2. Create user vinay
read -p "Enter new username: " USERNAME
log "Creating user '$USERNAME'..."
useradd -m -s /bin/bash "$USERNAME" || {
    log "Failed to create user $USERNAME"
    exit 1
}
passwd "$USERNAME" || {
    log "Failed to set password for $USERNAME"
    exit 1
}
usermod -aG sudo "$USERNAME" || {
    log "Failed to add $USERNAME to sudo group"
    exit 1
}

# 3. Enable sudo group in /etc/sudoers if not already
if ! grep -q "^%sudo" /etc/sudoers; then
    echo "%sudo ALL=(ALL:ALL) ALL" >> /etc/sudoers
    log "Added %sudo rule to /etc/sudoers"
fi

# 4. Ensure openssh config allows password login
SSHD_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSHD_CONFIG" ]; then
    sed -i 's/^#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"

    grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
    grep -q "^PermitRootLogin" "$SSHD_CONFIG" || echo "PermitRootLogin yes" >> "$SSHD_CONFIG"

    log "Configured sshd_config for password and root login. Restart will take effect on reboot."
else
    log "Warning: $SSHD_CONFIG not found. Skipped SSH config."
fi

# 5. Set up locale
LOCALE_NAME="en_US.UTF-8"
LOCALE_DIR="/usr/lib/locale"

log "Ensuring $LOCALE_DIR exists..."
mkdir -p "$LOCALE_DIR"

if ! locale -a | grep -q "$LOCALE_NAME"; then
    log "Generating locale $LOCALE_NAME..."
    localedef -i en_US -f UTF-8 "$LOCALE_NAME" || {
        log "Failed to generate locale"
        exit 1
    }
fi

echo "LANG=$LOCALE_NAME" > /etc/locale.conf
export LANG=$LOCALE_NAME

log "=== First Boot Setup Complete ==="

# Note: We don't delete the script anymore as systemd handles the "run once" logic
exit 0
