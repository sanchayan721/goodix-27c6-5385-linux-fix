#!/usr/bin/env bash

set -euo pipefail

export TPM2TOOLS_TCTI="${TPM_KEYRING_TCTI:-device:/dev/tpm0}"

exec /usr/bin/clevis-decrypt-tpm2 "$@"