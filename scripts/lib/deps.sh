#!/usr/bin/env bash

install_build_dependencies() {
    info "Installing build dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y "${BUILD_DEPS[@]}"
    success "Build dependencies installed."
}
