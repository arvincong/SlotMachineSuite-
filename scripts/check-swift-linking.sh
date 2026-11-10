#!/bin/bash
# Run on the Mac used for the failing build. Optional SDK: iphonesimulator.
set -euo pipefail
swift_check_sdk="${1:-iphoneos}"
case "$swift_check_sdk" in
    iphoneos|iphonesimulator) ;;
    *) echo 'Usage: bash scripts/check-swift-linking.sh [iphoneos|iphonesimulator]' >&2; exit 2 ;;
esac
if ! command -v xcrun >/dev/null 2>&1 || ! command -v xcodebuild >/dev/null 2>&1; then
    echo 'Run this check on macOS with the full Xcode installation selected.' >&2
    exit 2
fi
xcodebuild -version
swift_check_compiler="$(xcrun --sdk "$swift_check_sdk" --find swiftc)"
"$swift_check_compiler" --version
swift_check_sdk_path="$(xcrun --sdk "$swift_check_sdk" --show-sdk-path)"
swift_check_toolchain="$(cd "$(dirname "$swift_check_compiler")/.." && pwd)"
echo "SDK: $swift_check_sdk_path"
echo "Swift compiler: $swift_check_compiler"
swift_check_missing=0
for swift_check_module in swift_Builtin_float swift_errno swift_math swift_signal swift_stdio swift_time swiftsys_time swiftunistd; do
    swift_check_found=0
    for swift_check_directory in "$swift_check_sdk_path/usr/lib/swift" "$swift_check_toolchain/lib/swift/$swift_check_sdk"; do
        for swift_check_extension in a tbd dylib; do
            if [[ -f "$swift_check_directory/lib${swift_check_module}.${swift_check_extension}" ]]; then
                echo "FOUND: $swift_check_directory/lib${swift_check_module}.${swift_check_extension}"
                swift_check_found=1
                break 2
            fi
        done
    done
    if [[ "$swift_check_found" -eq 0 ]]; then
        echo "MISSING: lib${swift_check_module} in the selected SDK/toolchain" >&2
        swift_check_missing=1
    fi
done
if [[ "$swift_check_missing" -ne 0 ]]; then
    echo 'The selected SDK/toolchain lacks libraries referenced by the installed binary SDKs.' >&2
    echo 'Use a complete, matching Xcode toolchain; Xcode 16.4 or newer is recommended for the installed AppsFlyer binary (built with Swift 6.1.2).' >&2
    echo 'Select that Xcode under Xcode > Settings > Locations > Command Line Tools, then clean and rebuild the workspace.' >&2
    echo 'Changing SWIFT_VERSION alone cannot supply these libraries.' >&2
    exit 1
fi
echo 'PASS: all eight library files are present. Confirm resolution with an actual Xcode build.'
