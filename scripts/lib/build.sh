#!/usr/bin/env bash

configure_build() {
    info "Configuring build..."
    local -a meson_args

    if [[ -d "$LIBFPRINT_DIR/builddir" ]]; then
        info "Removing previous builddir..."
        rm -rf "$LIBFPRINT_DIR/builddir"
    fi

    # Newer Debian/Ubuntu releases may expose only libudev.pc (not udev.pc).
    # Patch the meson dependency name so configuration works across both layouts.
    if ! pkg-config --exists udev && pkg-config --exists libudev; then
        info "Applying libudev pkg-config compatibility patch..."
        sed -i "s/dependency('udev'/dependency('libudev'/g" "$LIBFPRINT_DIR/meson.build"

        # libudev.pc may not export udevdir. Set dirs explicitly for meson.
        meson_args+=("-Dudev_rules_dir=/usr/lib/udev/rules.d")
        meson_args+=("-Dudev_hwdb_dir=/usr/lib/udev/hwdb.d")
    fi

    # Install into /usr so fprintd uses the patched system library path.
    meson_args+=("--prefix=/usr")

    # Documentation tooling is optional and often missing on minimal systems.
    meson_args+=("-Ddoc=false")

    pushd "$LIBFPRINT_DIR" >/dev/null
    meson setup builddir "${meson_args[@]}"
    popd >/dev/null
}

compile_build() {
    info "Compiling (this may take a few minutes)..."
    meson compile -C "$LIBFPRINT_DIR/builddir" -j"$(nproc)"
    success "Build complete."
}

install_patched_libfprint() {
    info "Installing patched libfprint (requires sudo)..."
    sudo meson install -C "$LIBFPRINT_DIR/builddir"
    success "libfprint installed."
}

verify_patched_library() {
    local lib_path
    lib_path=$(find /usr/lib /usr/local/lib -name 'libfprint-2.so.2*' -not -type l 2>/dev/null | head -1)

    if [[ -z "$lib_path" ]]; then
        warn "Could not locate installed libfprint shared library for post-install verification."
        return
    fi

    if strings "$lib_path" | grep -q 'goodix53x5'; then
        success "Verified: patched libfprint ($lib_path) contains goodix53x5 driver."
    else
        warn "Installed library at $lib_path does not appear to contain the goodix53x5 driver."
        warn "The install may not have overridden the system library. Check meson install prefix."
    fi
}
