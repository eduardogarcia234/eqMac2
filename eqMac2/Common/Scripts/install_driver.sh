#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# uninstall old drivers
kextunload /System/Library/Extensions/eqMacDriver.kext
rm -rf /System/Library/Extensions/eqMacDriver.kext
kextunload /System/Library/Extensions/eqMac2Driver.kext
rm -rf /System/Library/Extensions/eqMac2Driver.kext

# install new driver
cp -R $DIR/eqMac2Driver.kext /System/Library/Extensions/
kextload -tv /System/Library/Extensions/eqMac2Driver.kext
touch /System/Library/Extensions

