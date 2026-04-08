#!/usr/bin/env bash
# install.sh — Orchestrator for the modular installer.
#
# Modules live under scripts/lib and are sourced in a fixed order.
# This keeps each phase focused and easier to maintain.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/config.sh
source "$SCRIPT_DIR/scripts/lib/config.sh"
# shellcheck source=scripts/lib/preflight.sh
source "$SCRIPT_DIR/scripts/lib/preflight.sh"
# shellcheck source=scripts/lib/deps.sh
source "$SCRIPT_DIR/scripts/lib/deps.sh"
# shellcheck source=scripts/lib/source.sh
source "$SCRIPT_DIR/scripts/lib/source.sh"
# shellcheck source=scripts/lib/build.sh
source "$SCRIPT_DIR/scripts/lib/build.sh"
# shellcheck source=scripts/lib/udev.sh
source "$SCRIPT_DIR/scripts/lib/udev.sh"
# shellcheck source=scripts/lib/verify.sh
source "$SCRIPT_DIR/scripts/lib/verify.sh"

main() {
    print_banner

    require_non_root
    check_sensor_or_confirm
    detect_distro
    ensure_apt_get
    prepare_workdir

    install_build_dependencies
    clone_or_update_sources
    apply_driver_sources_and_patch

    configure_build
    compile_build
    install_patched_libfprint
    verify_patched_library

    install_udev_rule
    unbind_cdc_acm_if_needed
    restart_fprintd

    verify_device_detection
    print_next_steps
}

main "$@"
