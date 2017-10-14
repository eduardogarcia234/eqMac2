//
//  Defaults.h
//  eqMac
//
//  Created by Romans Kisils on 12/12/2016.
//  Copyright © 2016 bitgapp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Storage : NSObject

typedef enum {
    kStorageShowDefaultPresets,
    kStoragePresets,
    kStorageAlreadyLaunched,
    kStorageOverallRuntime,
    kStorageLastRuntimeCheck,
    kStorageUUID,
    kStorageSelectedGains,
    kStorageSelectedPresetName,
    kStorageState,
} StorageKey;

+(id)get:(StorageKey)key;
+(void)set:(id)object key:(StorageKey)key;
@end
