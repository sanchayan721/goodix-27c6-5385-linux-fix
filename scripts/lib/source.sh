#!/usr/bin/env bash

clone_or_update_sources() {
    if [[ -d "$LIBFPRINT_DIR/.git" ]]; then
        info "libfprint already cloned, fetching latest..."
        git -C "$LIBFPRINT_DIR" fetch --tags -q
    else
        info "Cloning libfprint..."
        git clone https://gitlab.freedesktop.org/libfprint/libfprint.git "$LIBFPRINT_DIR"
    fi
    git -C "$LIBFPRINT_DIR" checkout "$LIBFPRINT_VERSION" -q
    success "libfprint $LIBFPRINT_VERSION checked out."

    if [[ -d "$DRIVER_DIR/.git" ]]; then
        info "Goodix driver already cloned, pulling latest..."
        git -C "$DRIVER_DIR" pull -q
    else
        info "Cloning Goodix53x5 driver..."
        git clone https://github.com/AndyHazz/goodix53x5-libfprint.git "$DRIVER_DIR"
    fi
    success "Goodix driver ready."
}

apply_driver_sources_and_patch() {
    info "Copying driver files into libfprint source tree..."
    mkdir -p "$LIBFPRINT_DIR/libfprint/drivers/goodix53x5"
    mkdir -p "$LIBFPRINT_DIR/libfprint/sigfm"
    cp -f "$DRIVER_DIR/drivers/goodix53x5/"* "$LIBFPRINT_DIR/libfprint/drivers/goodix53x5/"
    cp -f "$DRIVER_DIR/sigfm/"*              "$LIBFPRINT_DIR/libfprint/sigfm/"
    success "Driver files copied."

    info "Applying meson build integration patch..."
    pushd "$LIBFPRINT_DIR" >/dev/null
    # Revert any previous partial patch before applying (idempotent re-runs)
    git checkout -- libfprint/meson.build meson.build 2>/dev/null || true
    patch -p1 < "$DRIVER_DIR/meson-integration.patch"
    popd >/dev/null
    success "Patch applied."
}
