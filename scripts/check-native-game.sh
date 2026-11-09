#!/bin/bash
set -euo pipefail
native_root="$(cd "$(dirname "$0")/.." && pwd)"
native_tmp="$(mktemp -d "${TMPDIR:-/tmp}/sms-native.XXXXXX")"
trap 'rm -rf "$native_tmp"' EXIT
if ! command -v cc >/dev/null 2>&1; then
    echo 'A C compiler is required (install Xcode Command Line Tools on macOS).' >&2
    exit 2
fi
cc -std=c11 -Wall -Wextra -Werror -fsanitize=undefined \
    -I "$native_root/SlotMachineSuite/SlotMachineSuite" \
    "$native_root/Tests/GameRulesChecks.c" -o "$native_tmp/game-rule-checks"
"$native_tmp/game-rule-checks"
