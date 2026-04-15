#!/usr/bin/env bash

install_build_dependencies() {
    info "Installing build dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y "${BUILD_DEPS[@]}"
    success "Build dependencies installed."
}

install_runtime_dependencies() {
    info "Installing runtime fingerprint packages..."
    sudo apt-get install -y "${RUNTIME_DEPS[@]}"
    success "Runtime fingerprint packages installed."
}
