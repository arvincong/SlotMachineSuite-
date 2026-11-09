#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcrun >/dev/null 2>&1; then
    echo 'Run this check on macOS with Xcode Command Line Tools installed.' >&2
    exit 2
fi
routing_root="$(cd "$(dirname "$0")/.." && pwd)"
routing_tmp="$(mktemp -d "${TMPDIR:-/tmp}/sms-routing.XXXXXX")"
trap 'rm -rf "$routing_tmp"' EXIT
xcrun --sdk macosx clang -fobjc-arc -fmodules -fblocks -framework Foundation \
    -I "$routing_root/SlotMachineSuite/SlotMachineSuite" \
    "$routing_root/SlotMachineSuite/SlotMachineSuite/SMSRemoteConfiguration.m" \
    "$routing_root/Tests/LaunchRoutingChecks.m" \
    -o "$routing_tmp/launch-routing-checks"
"$routing_tmp/launch-routing-checks"
