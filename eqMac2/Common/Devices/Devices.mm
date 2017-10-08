//
//  Devices.m
//  eqMac
//
//  Created by Romans Kisils on 12/12/2016.
//  Copyright © 2016 bitgapp. All rights reserved.
//

#import "Devices.h"

@implementation Devices

typedef enum {
    kChannelLeft, kChannelRight, kChannelMaster
} VOLUME_CHANNEL;

#pragma mark -
#pragma mark Getting Devices in Bulk

+(NSArray*)getAllDeviceIDs{
    //Get device IDs
    UInt32 propsize;
    AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster }; //Get devices memory address
    AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &theAddress, 0, NULL,&propsize); //Get property size of each device
    int nDevices = propsize / sizeof(AudioDeviceID); //Calculate the number of devices
    AudioDeviceID *devids = new AudioDeviceID[nDevices]; //Allocate new AudioDeviceID array
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &propsize, devids); //Get the device IDs
    
    //Convert C++ array to NSArray
    NSMutableArray *deviceIDs = [[NSMutableArray alloc] init];
    
    for(int i = 0; i < nDevices; ++i){
        AudioDeviceID deviceID = devids[i];
        [deviceIDs addObject: [NSNumber numberWithInt:deviceID] ];
    }
    
    delete[] devids;
    return deviceIDs;
}

+(NSArray*)getAllOutputDeviceIDs{

    NSArray *deviceIDs = [self getAllDeviceIDs];
    NSMutableArray *devices = [[NSMutableArray alloc] init];
    
    for (NSNumber *ID in deviceIDs) {
        AudioDeviceID deviceID = [ID intValue];
        if ([self deviceIsOutput:deviceID]) {
            [devices addObject: [NSNumber numberWithInt:deviceID] ];
        }
    }
    return devices;
}

+(NSArray*)getAllUsableDevices{
    NSArray *deviceIDs = [self getAllOutputDeviceIDs];
    NSMutableArray *devices = [[NSMutableArray alloc] init];
    
    for (NSNumber *ID in deviceIDs) {
        AudioDeviceID deviceID = [ID intValue];
        if ([self getDeviceTransportTypeByID: deviceID] != kAudioDeviceTransportTypeBuiltIn) {
            NSString *deviceName = [self getEQMacDeviceID] == deviceID ? BUILTIN_DEVICE_NAME : [self getDeviceNameByID: deviceID];
            [devices addObject:@{
                                 @"id": ID,
                                 @"name": deviceName
                                 }];
        }
    }
    
    return devices;
}

+(NSArray*)getAllUsableDeviceNames{
    NSArray *devices = [self getAllUsableDevices];
    
    NSMutableArray *deviceNames = [[NSMutableArray alloc] init];
    
    for (NSDictionary *device in devices) {
        [deviceNames addObject: [device objectForKey:@"name"]];
    }

   deviceNames = [deviceNames sortedArrayUsingComparator:^NSComparisonResult(NSString *firstString, NSString *secondString) {
        return [[firstString lowercaseString] compare:[secondString lowercaseString]];
    }];
    
    return deviceNames;
}


#pragma mark -
#pragma mark Getting specific Devices

+(AudioDeviceID)getCurrentDeviceID{
    AudioObjectPropertyAddress currentOutputDevicePropertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    AudioDeviceID currentOutputDeviceID;
    UInt32 currentOutputDeviceIDSize = sizeof(currentOutputDeviceID);
    AudioObjectGetPropertyData(kAudioObjectSystemObject,
                               &currentOutputDevicePropertyAddress,
                               0, NULL,
                               &currentOutputDeviceIDSize, &currentOutputDeviceID);
    return currentOutputDeviceID;
}

+(AudioDeviceID)getVolumeControllerDeviceID{
    return [EQHost EQEngineExists] ? [EQHost getSelectedOutputDeviceID] :  [self getCurrentDeviceID];
}

+(AudioDeviceID)getEQMacDeviceID{
    return [self getDeviceIDWithUID: DRIVER_UID];
}

+(AudioDeviceID)getBuiltInDeviceID{
    NSArray *deviceIDs = [self getAllOutputDeviceIDs];
    for(NSNumber *ID in deviceIDs){
        AudioDeviceID deviceID = [ID intValue];
        if ([self getDeviceTransportTypeByID: deviceID] == kAudioDeviceTransportTypeBuiltIn) return deviceID;
    }
    return 0;
}

#pragma mark -
#pragma mark Device Control


+(void)switchToDeviceWithID:(AudioDeviceID)ID{
    AudioObjectPropertyAddress devAddress = { kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };
    AudioObjectSetPropertyData(kAudioObjectSystemObject, &devAddress, 0, NULL, sizeof(ID), &ID);
}

#pragma mark -
#pragma mark Get Device Properties


+(Float32)getVolumeForDevice:(AudioDeviceID)deviceID andChannel:(VOLUME_CHANNEL)ch{
    UInt32 channel;
    
    switch(ch){
        case kChannelLeft:{
            channel = 1;
            break;
        }
        case kChannelRight:{
            channel = 2;
            break;
        }
        case kChannelMaster:{
            channel = kAudioObjectPropertyElementMaster;
            break;
        }
    }
    
    AudioObjectPropertyAddress volumePropertyAddress = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        channel
    };
    
    Float32 volume;
    UInt32 volumeSize = sizeof(volume);
    AudioObjectGetPropertyData(deviceID, &volumePropertyAddress,0, NULL, &volumeSize, &volume);
    return volume;
}

+(Float32)getVolumeForDeviceID:(AudioDeviceID)ID{
    Float32 volume = 0;
    if([self audioDeviceHasMasterVolume:ID]){
        volume = [self getVolumeForDevice:ID andChannel:kChannelMaster];
    }else{
        Float32 leftVolume = [self getVolumeForDevice:ID andChannel:kChannelLeft];
        Float32 rightVolume = [self getVolumeForDevice:ID andChannel:kChannelRight];
        volume = leftVolume > rightVolume ? leftVolume : rightVolume;
    }
    return volume;
}

+(Float32)getBalanceForDeviceID:(AudioDeviceID)ID{
    Float32 volume = [self getVolumeForDeviceID:ID];
    Float32 left = [self getVolumeForDevice:ID andChannel:kChannelLeft];
    Float32 right = [self getVolumeForDevice:ID andChannel:kChannelRight];
    Float32 balance = right - left;
    balance = [Utilities mapValue:balance withInMin:-volume InMax:volume OutMin:-1 OutMax:1];
    if(isnan(balance)) balance = 0;
    return balance;
}

+(BOOL)getIsMutedForDeviceID:(AudioDeviceID)ID{
    
    AudioObjectPropertyAddress mutedAddress;
    mutedAddress.mScope = kAudioDevicePropertyScopeOutput;
    mutedAddress.mSelector = kAudioDevicePropertyMute;
    mutedAddress.mElement = kAudioObjectPropertyElementMaster;
    
    //Check if Master Volume can be muted
    if (!AudioObjectHasProperty(ID, &mutedAddress)){
        mutedAddress.mElement = 1; //If not fallback to left channel and check again
        if (!AudioObjectHasProperty(ID, &mutedAddress)){
            mutedAddress.mElement = 2; //If not fallback to right channel and check again
            if (!AudioObjectHasProperty(ID, &mutedAddress)){
                return false; //If nothing can be muted return false
            }
        }
    }
        
    UInt32 data;
    UInt32 dataSize = sizeof(data);
    AudioObjectGetPropertyData(ID, &mutedAddress, 0, NULL, &dataSize, &data);
    return data == 1;
}

+(BOOL)getIsAliveForDeviceID:(AudioDeviceID)ID{
    
    AudioObjectPropertyAddress mutedAddress;
    mutedAddress.mScope = kAudioDevicePropertyScopeOutput;
    mutedAddress.mSelector = kAudioDevicePropertyDeviceIsAlive;
    mutedAddress.mElement = kAudioObjectPropertyElementMaster;
    
    UInt32 data;
    UInt32 dataSize = sizeof(data);
    AudioObjectGetPropertyData(ID, &mutedAddress, 0, NULL, &dataSize, &data);
    return data == 1;
}

+ (AudioDeviceID)getDeviceIDWithUID:(NSString *)uid{
    AudioDeviceID myDevice;
    AudioValueTranslation trans;
    
    CFStringRef myKnownUID = (__bridge CFStringRef )uid;
    trans.mInputData = &myKnownUID;
    
    trans.mInputDataSize = sizeof (CFStringRef);
    trans.mOutputData = &myDevice;
    trans.mOutputDataSize = sizeof(AudioDeviceID);
    
    UInt32 size = sizeof (AudioValueTranslation);
    AudioHardwareGetProperty (kAudioHardwarePropertyDeviceForUID,
                              &size,
                              &trans);
    return myDevice;
    
}

+(UInt32)getDeviceTransportTypeByID:(AudioDeviceID)ID{
    AudioObjectPropertyAddress transportAddress = { kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal, 0};
    UInt32 transportSize = sizeof(UInt32);
    UInt32 transportType = 0;
    AudioObjectGetPropertyData(ID, &transportAddress, 0, NULL, &transportSize, &transportType);
    return transportType;
}

+(NSString*)getDeviceNameByID:(UInt32)ID{
    AudioObjectPropertyAddress nameAddress = { kAudioDevicePropertyDeviceName, kAudioDevicePropertyScopeOutput, 0 };
    
    char name[64];
    UInt32 propsize = sizeof(name);
    AudioObjectGetPropertyData(ID, &nameAddress, 0, NULL, &propsize, &name);
    
    return [NSString stringWithFormat:@"%s", name];
}


#pragma mark -
#pragma mark Set Device Properties

//PRIVATE
+(void)setVolumeForDevice:(AudioDeviceID)deviceID andChannel:(VOLUME_CHANNEL)ch to:(Float32)vol{
    UInt32 channel;
    if(vol < 0) vol = 0;
    
    switch(ch){
        case kChannelLeft:{
            channel = 1;
            break;
        }
        case kChannelRight:{
            channel = 2;
            break;
        }
        case kChannelMaster:{
            channel = kAudioObjectPropertyElementMaster;
            break;
        }
    }
    
    AudioObjectPropertyAddress volumePropertyAddress = {
        kAudioDevicePropertyVolumeScalar,
        kAudioDevicePropertyScopeOutput,
        channel
    };
    
    AudioObjectSetPropertyData(deviceID, &volumePropertyAddress,0, NULL, sizeof(vol), &vol);
}

+(void)setDevice:(AudioDeviceID)ID isHidden:(BOOL)condition{
    UInt32 hidden = condition ? 1 : 0;
    
    AudioObjectPropertyAddress hiddenAddress;
    hiddenAddress.mScope = kAudioDevicePropertyScopeOutput;
    hiddenAddress.mSelector = kAudioDevicePropertyIsHidden;
    
    hiddenAddress.mElement = kAudioObjectPropertyElementMaster;
    if (AudioObjectHasProperty(ID, &hiddenAddress)){
        OSStatus err = AudioObjectSetPropertyData(ID, &hiddenAddress, 0, NULL, sizeof(hidden), &hidden);
    }}


+(void)setDevice:(AudioDeviceID)ID toMuted:(BOOL)condition{
    UInt32 mute = condition ? 1 : 0;
    
    AudioObjectPropertyAddress mutedAddress;
    mutedAddress.mScope = kAudioDevicePropertyScopeOutput;
    mutedAddress.mSelector = kAudioDevicePropertyMute;
    
    //MASTER
    mutedAddress.mElement = kAudioObjectPropertyElementMaster;
    if (AudioObjectHasProperty(ID, &mutedAddress)){
        AudioObjectSetPropertyData(ID, &mutedAddress, 0, NULL, sizeof(mute), &mute);
    }
    
    //LEFT
    mutedAddress.mElement = 1;
    if (AudioObjectHasProperty(ID, &mutedAddress)){
        AudioObjectSetPropertyData(ID, &mutedAddress, 0, NULL, sizeof(mute), &mute);
    }
    
    //RIGHT
    mutedAddress.mElement = 2;
    if (AudioObjectHasProperty(ID, &mutedAddress)){
        AudioObjectSetPropertyData(ID, &mutedAddress, 0, NULL, sizeof(mute), &mute);
    }
}

//PUBLIC
+(BOOL)audioDeviceHasMasterVolume:(AudioDeviceID)ID{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioDevicePropertyScopeOutput;
    address.mSelector = kAudioDevicePropertyVolumeScalar;
    address.mElement = kAudioObjectPropertyElementMaster;
    return AudioObjectHasProperty(ID, &address);
}

//PUBLIC
+(void)setVolumeForDevice:(AudioDeviceID)ID to:(Float32)volume{

    if([self audioDeviceHasMasterVolume:ID]){
        [self setVolumeForDevice:ID andChannel:kChannelMaster to:volume];
    }else{
        Float32 balance = [self getBalanceForDeviceID:ID];
        Float32 leftMultiplier = balance < 0 ? 1 : 1 - balance;
        Float32 rightMiltiplier = balance > 0 ? 1 : 1 + balance;
        Float32 leftVolume = volume * leftMultiplier;
        Float32 rightVolume = volume * rightMiltiplier;
        
        [self setVolumeForDevice:ID andChannel:kChannelLeft to: leftVolume];
        [self setVolumeForDevice:ID andChannel:kChannelRight to: rightVolume];
    }
    
    [self setDevice:ID toMuted:volume < QUARTER_VOLUME_STEP];
}


//PUBLIC
+(void)setBalanceForDevice:(AudioDeviceID)ID to:(Float32)balance{
    Float32 masterVolume = [self getVolumeForDeviceID:ID];

    Float32 leftVolume = 1 - balance;
    Float32 rightVolume = 1 + balance;
    
    if(leftVolume > 1) leftVolume = 1;
    if(rightVolume > 1) rightVolume = 1;
    
    leftVolume *= masterVolume;
    rightVolume *= masterVolume;
    
    [self setVolumeForDevice:ID andChannel:kChannelLeft to:leftVolume];
    [self setVolumeForDevice:ID andChannel:kChannelRight to:rightVolume];
}


#pragma mark -
#pragma mark Conditions

+(BOOL)deviceIsInput:(AudioDeviceID)ID{
    AudioObjectPropertyAddress propAddress;
    propAddress = { kAudioDevicePropertyStreams, kAudioDevicePropertyScopeInput, 0 };
    UInt32 dataSize = 0;
    AudioObjectGetPropertyDataSize(ID, &propAddress, 0, NULL, &dataSize);
    UInt32 streamCount = dataSize / sizeof(AudioStreamID);
    return (streamCount > 0);
}

+(BOOL)deviceIsOutput:(AudioDeviceID)ID{
    AudioObjectPropertyAddress propAddress;
    propAddress = { kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput, 0 };
    UInt32 dataSize = 0;
    AudioObjectGetPropertyDataSize(ID, &propAddress, 0, NULL, &dataSize);
    UInt32 streamCount = dataSize / sizeof(AudioStreamID);
    return (streamCount > 0);
}

+(BOOL)deviceIsBuiltIn:(AudioDeviceID)ID{
    return (ID == [self getEQMacDeviceID] || [self getDeviceTransportTypeByID:ID] == kAudioDeviceTransportTypeBuiltIn);
}

+(BOOL)eqMacDriverInstalled{
    NSArray *outputDeviceIDs = [self getAllOutputDeviceIDs];
    NSLog(@"%@", outputDeviceIDs);
    for (NSNumber *ID in outputDeviceIDs) {
        AudioDeviceID deviceID = [ID intValue];
        if ([[self getDeviceNameByID:deviceID] isEqualToString: DRIVER_NAME]) return true;
    }
    return false;
}

@end
