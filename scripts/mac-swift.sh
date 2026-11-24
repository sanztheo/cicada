#!/bin/bash
# The macOS 27 SDK declares @State as a macro. The standalone 27 CLT lack
# SwiftUIMacros; use the installed 26 SDK for this SwiftUI app in that case.
set -eu
action=$1
shift
developer=$(xcode-select -p)
sdk26="$developer/SDKs/MacOSX26.sdk"
if [[ "$developer" == */CommandLineTools && -d "$sdk26" && "$(xcrun --sdk macosx --show-sdk-version)" == 27.* && ! -e "$developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib" ]]; then
    exec swift "$action" --build-system native --sdk "$sdk26" "$@"
fi
exec swift "$action" "$@"
