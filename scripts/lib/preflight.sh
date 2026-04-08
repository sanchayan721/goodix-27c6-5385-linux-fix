#!/usr/bin/env bash

require_non_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Do not run this script as root. It will call sudo where needed."
    fi
}

check_sensor_or_confirm() {
    info "Checking for Goodix HTK32 fingerprint sensor..."

    if lsusb | grep -qE '27c6:(5385|5395)'; then
        USB_ID=$(lsusb | grep -oE '27c6:(5385|5395)' | head -1)
        success "Sensor found: USB ID $USB_ID"
        return
    fi

    echo
    warn "No Goodix HTK32 sensor detected (lsusb shows no 27c6:5385 or 27c6:5395)."
    warn "This script is specifically for that sensor."
    echo
    read -rp "Continue anyway? [y/N] " CONT
    [[ "${CONT,,}" == "y" ]] || exit 0
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        info "Detected OS: $PRETTY_NAME"

        if [[ "$ID" != "ubuntu" && "$ID" != "debian" && "$ID_LIKE" != *"ubuntu"* && "$ID_LIKE" != *"debian"* ]]; then
            warn "This script was tested on Ubuntu and Debian. Proceed with caution on $PRETTY_NAME."
        fi
    fi
}

ensure_apt_get() {
    if ! command -v apt-get >/dev/null 2>&1; then
        error "apt-get not found. This installer currently supports Ubuntu/Debian only."
    fi
}

prepare_workdir() {
    info "Working directory: $BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}
