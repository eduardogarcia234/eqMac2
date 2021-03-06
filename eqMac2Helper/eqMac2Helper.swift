//
//  eqMac2Helper.swift
//  eqMac2Helper
//
//  Created by Romans Kisils on 09/10/2017.
//  Copyright © 2017 Romans Kisils. All rights reserved.
//

import Foundation
import CoreAudio
import AppKit

@discardableResult
func checkErr(_ err : @autoclosure () -> OSStatus, file: String = #file, line: Int = #line) -> OSStatus! {
    let error = err()
    if (error != noErr) {
        print("CAPlayThrough Error: \(error) ->  \(file):\(line)\n")
        return error
    }
    return nil
}


class eqMac2Helper {
    var lastSelectedAudioDeviceID: AudioDeviceID = 0
    var checkTimer: Timer? = Timer()
    
    init () {
        
    }
    
    func start() {
        self.checkTimer = Timer.scheduledTimer(timeInterval: 1,
                                               target: self,
                                               selector: #selector(check),
                                               userInfo: nil,
                                               repeats: true)
    }
    
    @objc func check() {
        let currentDeviceID: AudioDeviceID = getCurrentOutputAudioDeviceID()
        let currentDeviceName = getNameOfOutputAudioDeviceWithID(currentDeviceID)
        let appRunning = eqMac2IsRunning()
        
        let eqMacDeviceName = "eqMac2"
        
        if (currentDeviceName == eqMacDeviceName && appRunning == false) {
            if (lastSelectedAudioDeviceID == 0 || lastSelectedAudioDeviceID == currentDeviceID) {
                lastSelectedAudioDeviceID = getBuiltInOutputDeviceID()
            }
            
            switchToOutputDeviceWithID(lastSelectedAudioDeviceID)
            
        } else {
            lastSelectedAudioDeviceID = currentDeviceID
        }
    }
    
    func eqMac2IsRunning () -> Bool {
        let eqMac2 = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.bitgapp.eqMac2" })
        return eqMac2 != nil
    }
    
    func getAllDeviceIDs() -> Array<AudioDeviceID> {
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        var propsize: UInt32 = 0
        checkErr(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &theAddress, 0, nil, &propsize))
        let nDevices = Int(propsize) / MemoryLayout<AudioDeviceID>.size
        
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: nDevices)
        deviceIDs.withUnsafeMutableBufferPointer {
            (buffer: inout UnsafeMutableBufferPointer<AudioDeviceID>) -> () in
            checkErr(AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &theAddress,
                0,
                nil,
                &propsize,
                buffer.baseAddress! )
            )
        }
        
        return deviceIDs
    }
    
    func audioDeviceIsInput(_ deviceID: AudioDeviceID) -> Bool {
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: 0
        )
        var propsize: UInt32 = 0
        checkErr(AudioObjectGetPropertyDataSize(deviceID, &theAddress, 0, nil, &propsize))
        let streamCount = Int(propsize) / MemoryLayout<AudioStreamID>.size
        return (streamCount > 0)
    }
    
    func getAllOutputDeviceIDs () -> Array<AudioDeviceID> {
        return getAllDeviceIDs().filter { !audioDeviceIsInput($0) }
    }
    
    func getAudioDeviceTransportType (_ deviceID: AudioDeviceID) -> UInt32{
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        
        var propsize = UInt32(MemoryLayout<UInt32>.size)
        
        var transportType: UInt32 = kAudioDeviceTransportTypeUnknown
        checkErr(AudioObjectGetPropertyData(deviceID, &theAddress, 0, nil, &propsize, &transportType))
        
        return transportType
    }
    
    func getBuiltInOutputDeviceID () -> AudioDeviceID {
        return getAllOutputDeviceIDs().first( where: { getAudioDeviceTransportType($0) == kAudioDeviceTransportTypeBuiltIn })!
    }
    
    func getCurrentOutputAudioDeviceID() -> AudioDeviceID {
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        var outputDevice: AudioDeviceID = 0
        var propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        checkErr(AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &theAddress,
            0,
            nil,
            &propsize,
            &outputDevice)
        )
        
        return outputDevice
    }
    
    func getNameOfOutputAudioDeviceWithID(_ deviceID: AudioDeviceID) -> String {
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        
        var maxlen = UInt32(1024)
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(maxlen))
        checkErr(AudioObjectGetPropertyData(deviceID, &theAddress, 0, nil, &maxlen, buf))
        if let str = String(bytesNoCopy: buf, length: Int(maxlen) - 1, encoding: String.Encoding.utf8, freeWhenDone: true) {
            return str
        }
        return ""
    }
    
    func switchToOutputDeviceWithID(_ deviceID: AudioDeviceID) {
        var id = deviceID
        var theAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        
        checkErr(AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &theAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id))
    }
    
    
}

