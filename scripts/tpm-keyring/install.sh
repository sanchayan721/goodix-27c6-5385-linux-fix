#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
FILES_DIR="$SCRIPT_DIR/files"

# shellcheck source=scripts/lib/common.sh
source "$REPO_DIR/scripts/lib/common.sh"

ensure_non_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this installer as root. It will call sudo where needed."
    fi
}

install_packages() {
    info "Installing TPM keyring unlock dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y clevis clevis-tpm2 python3-dbus
    success "TPM keyring unlock dependencies installed."
}

install_system_files() {
    info "Installing TPM helper wrappers and sudoers rule..."

    sudo install -D -m 755 -o root -g root \
        "$FILES_DIR/tpm-keyring-clevis-encrypt.sh" \
        /usr/local/libexec/tpm-keyring-clevis-encrypt.sh
    sudo install -D -m 755 -o root -g root \
        "$FILES_DIR/tpm-keyring-clevis-decrypt.sh" \
        /usr/local/libexec/tpm-keyring-clevis-decrypt.sh

    sed "s/__USER__/$USER/g" "$FILES_DIR/tpm-keyring-clevis.sudoers" |
        sudo tee /etc/sudoers.d/tpm-keyring-clevis >/dev/null
    sudo chown root:root /etc/sudoers.d/tpm-keyring-clevis
    sudo chmod 440 /etc/sudoers.d/tpm-keyring-clevis
    sudo visudo -cf /etc/sudoers.d/tpm-keyring-clevis >/dev/null

    success "System TPM helper wrappers installed."
}

install_user_files() {
    info "Installing user-side TPM keyring scripts..."

    install -d -m 700 "$HOME/.local/bin"
    install -d -m 700 "$HOME/.config/systemd/user"

    install -m 700 "$FILES_DIR/tpm-keyring-setup.sh" "$HOME/.local/bin/tpm-keyring-setup.sh"
    install -m 700 "$FILES_DIR/tpm-keyring-unlock.sh" "$HOME/.local/bin/tpm-keyring-unlock.sh"
    install -m 644 "$FILES_DIR/tpm-keyring-unlock.service" "$HOME/.config/systemd/user/tpm-keyring-unlock.service"

    success "User TPM keyring scripts installed."
}

enable_user_service() {
    info "Enabling TPM keyring unlock user service..."
    systemctl --user daemon-reload
    systemctl --user enable tpm-keyring-unlock.service >/dev/null
    success "TPM keyring unlock user service enabled."
}

print_next_steps() {
    echo
    echo -e "${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}  TPM Keyring Unlock Installed${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo
    echo "  Next steps:"
    echo
    echo "  1. Enroll your current GNOME login keyring password into TPM:"
    echo "       ~/.local/bin/tpm-keyring-setup.sh"
    echo
    echo "     The setup script will show a warning and require confirmation"
    echo "     that resetting the login keyring later will lose saved logins"
    echo "     and secrets stored in that keyring."
    echo
    echo "  2. Log out fully and log back in with fingerprint login."
    echo
    echo "  3. If needed, test manually:"
    echo "       ~/.local/bin/tpm-keyring-unlock.sh"
    echo
}

main() {
    print_banner
    ensure_non_root
    install_packages
    install_system_files
    install_user_files
    enable_user_service
    print_next_steps
}

main "$@"