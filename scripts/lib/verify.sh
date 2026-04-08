#!/usr/bin/env bash

verify_device_detection() {
    echo
    echo -e "${BOLD}Verifying device detection...${NC}"

    if fprintd-list "$USER" 2>&1 | grep -qi 'goodix\|htk32\|27c6'; then
        success "fprintd detects the Goodix HTK32 sensor!"
    else
        local fprintd_out
        fprintd_out=$(fprintd-list "$USER" 2>&1 || true)
        warn "fprintd output: $fprintd_out"
        warn "Device not yet detected. A reboot may be needed to fully apply the udev rule."
        warn "After rebooting, run:  fprintd-list \$USER"
    fi
}

print_next_steps() {
    echo
    echo -e "${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo
    echo "  Next steps:"
    echo
    echo "  1. Enroll your fingerprint:"
    echo "       Option A (recommended): GNOME Settings -> Users -> Fingerprint Login"
    echo "       Option B (CLI):         fprintd-enroll -f right-index-finger \$USER"
    echo
    echo "  2. Enable fingerprint for sudo / login:"
    echo "       sudo pam-auth-update"
    echo "       (select 'Fingerprint authentication')"
    echo
    echo "  Note: If your distro upgrades libfprint via apt, re-run this script."
    echo "  To prevent apt from overwriting the library:"
    echo "       sudo apt-mark hold libfprint-2-2"
    echo
}
