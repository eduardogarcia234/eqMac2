#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# uninstall old drivers
kextunload /System/Library/Extensions/eqMacDriver.kext
rm -rf /System/Library/Extensions/eqMacDriver.kext
kextunload /System/Library/Extensions/eqMacDriver2.kext
rm -rf /System/Library/Extensions/eqMacDriver2.kext

# install new driver
cp -R $DIR/eqMacAudio.kext /System/Library/Extensions/
kextload -tv /System/Library/Extensions/eqMacAudio.kext
touch /System/Library/Extensions

