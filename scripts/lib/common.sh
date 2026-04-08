#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BOLD}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

print_banner() {
    echo
    echo -e "${BOLD}Goodix HTK32 Fingerprint Sensor Fix for Ubuntu/Debian${NC}"
    echo -e "${BOLD}================================================${NC}"
    echo
}
