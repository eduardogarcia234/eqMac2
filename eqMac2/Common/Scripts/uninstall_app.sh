#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

kextunload /System/Library/Extensions/eqMacAudio.kext
rm -r /System/Library/Extensions/eqMacAudio.kext
touch /System/Library/Extensions
rm -r $DIR/../../../eqMac2.app
