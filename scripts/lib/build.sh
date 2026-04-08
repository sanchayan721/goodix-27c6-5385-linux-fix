#!/usr/bin/env bash

configure_build() {
    info "Configuring build..."
    if [[ -d "$LIBFPRINT_DIR/builddir" ]]; then
        info "Removing previous builddir..."
        rm -rf "$LIBFPRINT_DIR/builddir"
    fi

    pushd "$LIBFPRINT_DIR" >/dev/null
    meson setup builddir
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
