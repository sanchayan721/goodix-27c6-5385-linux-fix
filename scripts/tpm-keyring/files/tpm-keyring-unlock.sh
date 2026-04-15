#!/usr/bin/env bash

set -euo pipefail

umask 077

STATE_DIR="$HOME/.local/share/tpm-keyring"
CREDENTIAL_FILE="$STATE_DIR/login.keyring.jwe"
DECRYPT_HELPER="/usr/local/libexec/tpm-keyring-clevis-decrypt.sh"
SUDO_BIN="/usr/bin/sudo"

if [[ ! -r "$CREDENTIAL_FILE" ]]; then
    exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0
[[ -x "$SUDO_BIN" ]] || exit 0

if [[ ! -x "$DECRYPT_HELPER" ]]; then
    exit 0
fi

if ! python3 -c 'import dbus' >/dev/null 2>&1; then
    exit 0
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export XDG_RUNTIME_DIR
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    export DBUS_SESSION_BUS_ADDRESS
fi

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    exit 0
fi

SECRET="$($SUDO_BIN -n -u tss "$DECRYPT_HELPER" < "$CREDENTIAL_FILE")"
export SECRET

if [[ ! -S "${XDG_RUNTIME_DIR}/keyring/control" ]]; then
    gnome-keyring-daemon --start --components=secrets >/dev/null 2>&1 || true
fi

python3 - <<'PY'
import os
import time

import dbus


def unlock_keyring(password: bytes) -> int:
    bus = dbus.SessionBus()
    service = bus.get_object("org.freedesktop.secrets", "/org/freedesktop/secrets")
    service_iface = dbus.Interface(service, "org.freedesktop.Secret.Service")

    collection = service_iface.ReadAlias("default")
    if collection == "/":
        return 1

    collection_obj = bus.get_object("org.freedesktop.secrets", collection)
    props = dbus.Interface(collection_obj, "org.freedesktop.DBus.Properties")

    if not bool(props.Get("org.freedesktop.Secret.Collection", "Locked")):
        return 0

    _, session_path = service_iface.OpenSession("plain", dbus.String(""))
    unlock_iface = dbus.Interface(
        service,
        "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface",
    )
    secret = dbus.Struct(
        (
            dbus.ObjectPath(session_path),
            dbus.ByteArray(b""),
            dbus.ByteArray(password),
            "text/plain",
        )
    )
    unlock_iface.UnlockWithMasterPassword(collection, secret)

    return 0 if not bool(props.Get("org.freedesktop.Secret.Collection", "Locked")) else 1


password = os.environ["SECRET"].encode()

for _ in range(10):
    try:
        if unlock_keyring(password) == 0:
            raise SystemExit(0)
    except dbus.DBusException:
        pass
    time.sleep(0.5)

raise SystemExit(1)
PY

unset SECRET