#!/bin/bash
set -euo pipefail
apple_pay_root="$(cd "$(dirname "$0")/.." && pwd)"
node "$apple_pay_root/Tests/ApplePayBridgeChecks.js"
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcrun >/dev/null 2>&1; then
    echo 'Bridge checks passed; native checks require macOS with Xcode Command Line Tools.' >&2
    exit 2
fi
apple_pay_tmp="$(mktemp -d "${TMPDIR:-/tmp}/sms-apple-pay.XXXXXX")"
trap 'rm -rf "$apple_pay_tmp"' EXIT
xcrun --sdk macosx clang -fobjc-arc -fmodules -fblocks -framework Foundation \
    -I "$apple_pay_root/SlotMachineSuite/SlotMachineSuite" \
    "$apple_pay_root/SlotMachineSuite/SlotMachineSuite/SMSApplePayAPI.m" \
    "$apple_pay_root/SlotMachineSuite/SlotMachineSuite/SMSApplePayStore.m" \
    "$apple_pay_root/Tests/ApplePayProtocolChecks.m" \
    -o "$apple_pay_tmp/apple-pay-checks"
"$apple_pay_tmp/apple-pay-checks"
