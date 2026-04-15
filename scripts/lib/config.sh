#!/usr/bin/env bash

LIBFPRINT_VERSION="v1.94.10"
BUILD_DIR="${BUILD_DIR:-$HOME/fpfix}"
LIBFPRINT_DIR="$BUILD_DIR/libfprint"
DRIVER_DIR="$BUILD_DIR/goodix53x5-libfprint"
UDEV_RULE="/etc/udev/rules.d/91-goodix-fingerprint.rules"

BUILD_DEPS=(
    git meson ninja-build pkg-config
    libglib2.0-dev libgusb-dev
    libssl-dev libopencv-dev
    gobject-introspection libgirepository1.0-dev
    libcairo2-dev libgudev-1.0-dev
    python3-gi-cairo gir1.2-glib-2.0
)

RUNTIME_DEPS=(
    fprintd
    libpam-fprintd
)
