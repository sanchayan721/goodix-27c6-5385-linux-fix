#!/usr/bin/env bash

set -euo pipefail

umask 077

STATE_DIR="$HOME/.local/share/tpm-keyring"
CREDENTIAL_FILE="$STATE_DIR/login.keyring.jwe"
BINDING_FILE="$STATE_DIR/binding.json"
ENCRYPT_HELPER="/usr/local/libexec/tpm-keyring-clevis-encrypt.sh"
DECRYPT_HELPER="/usr/local/libexec/tpm-keyring-clevis-decrypt.sh"
SUDO_BIN="/usr/bin/sudo"

PCR_IDS="${TPM_PCR_IDS:-7}"
PCR_BANK="${TPM_PCR_BANK:-sha256}"
BINDING_JSON=$(printf '{"pcr_bank":"%s","pcr_ids":"%s"}' "$PCR_BANK" "$PCR_IDS")

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

print_warning_and_confirm() {
    echo
    echo "WARNING: This setup uses your current GNOME login keyring password."
    echo "If you later reset the login keyring to recover access, saved logins"
    echo "and secrets stored in that keyring will be lost."
    echo
    read -r -p "Type CONTINUE to confirm you understand: " CONFIRM
    [[ "$CONFIRM" == "CONTINUE" ]] || {
        echo "Aborted."
        exit 1
    }
}

main() {
    [[ -x "$SUDO_BIN" ]] || {
        echo "Missing required command: $SUDO_BIN" >&2
        exit 1
    }
    require_command install
    require_command mktemp

    [[ -x "$ENCRYPT_HELPER" ]] || {
        echo "Missing required helper: $ENCRYPT_HELPER" >&2
        exit 1
    }
    [[ -x "$DECRYPT_HELPER" ]] || {
        echo "Missing required helper: $DECRYPT_HELPER" >&2
        exit 1
    }

    print_warning_and_confirm

    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"

    read -rsp "Enter your GNOME keyring password: " KEYRING_PASSWORD
    printf '\n'
    read -rsp "Re-enter your GNOME keyring password: " KEYRING_PASSWORD_2
    printf '\n'

    if [[ "$KEYRING_PASSWORD" != "$KEYRING_PASSWORD_2" ]]; then
        echo "Passwords do not match." >&2
        exit 1
    fi

    WORKDIR="$(mktemp -d)"
    trap 'rm -rf "$WORKDIR"' EXIT

    PLAIN_FILE="$WORKDIR/plain.txt"
    TMP_CREDENTIAL_FILE="$WORKDIR/login.keyring.jwe"

    printf '%s' "$KEYRING_PASSWORD" > "$PLAIN_FILE"
    unset KEYRING_PASSWORD KEYRING_PASSWORD_2

    "$SUDO_BIN" -n -u tss "$ENCRYPT_HELPER" "$BINDING_JSON" < "$PLAIN_FILE" > "$TMP_CREDENTIAL_FILE"

    if [[ "$("$SUDO_BIN" -n -u tss "$DECRYPT_HELPER" < "$TMP_CREDENTIAL_FILE")" != "$(cat "$PLAIN_FILE")" ]]; then
        echo "TPM credential verification failed." >&2
        exit 1
    fi

    install -m 600 "$TMP_CREDENTIAL_FILE" "$CREDENTIAL_FILE"
    printf '%s\n' "$BINDING_JSON" > "$BINDING_FILE"
    chmod 600 "$BINDING_FILE"

    rm -f "$STATE_DIR/sealed.pub" "$STATE_DIR/sealed.priv" "$STATE_DIR/pcr.policy" "$STATE_DIR/pcrs"

    echo "TPM keyring credential stored successfully with binding: $BINDING_JSON"
    echo "You can now run: ~/.local/bin/tpm-keyring-unlock.sh"
}

main "$@"