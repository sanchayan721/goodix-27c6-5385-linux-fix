#!/usr/bin/env bash

install_udev_rule() {
    info "Deploying udev rule to prevent cdc_acm hijack..."
    sudo cp -f "$DRIVER_DIR/91-goodix-fingerprint.rules" "$UDEV_RULE"
    sudo udevadm control --reload-rules
    success "udev rule installed at $UDEV_RULE."
}

unbind_cdc_acm_if_needed() {
    info "Attempting to unbind cdc_acm from the sensor (if currently bound)..."

    local iface devpath vendor ifname
    for iface in /sys/bus/usb/drivers/cdc_acm/*:*; do
        [[ -L "$iface" ]] || continue
        devpath=$(readlink -f "$iface")
        vendor=$(cat "$devpath/../idVendor" 2>/dev/null || true)

        if [[ "$vendor" == "27c6" ]]; then
            ifname=$(basename "$iface")
            info "  Unbinding $ifname from cdc_acm..."
            echo "$ifname" | sudo tee /sys/bus/usb/drivers/cdc_acm/unbind > /dev/null 2>&1 || true
        fi
    done
}

restart_fprintd() {
    info "Restarting fprintd..."
    sudo systemctl restart fprintd
    sleep 2
}
