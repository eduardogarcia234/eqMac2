#import <Foundation/Foundation.h>
#import "EQHost.h"

@implementation EQHost

static EQEngine *mEngine;
static AudioDeviceID selectedOutputDeviceID;
static NSDate *runStart;

+(void)createEQEngineWithOutputDevice:(AudioDeviceID)output{
    if([self EQEngineExists]) [self deleteEQEngine];
    
    AudioDeviceID input = [Devices getEQMacDeviceID];
    selectedOutputDeviceID = output;
    
    [Devices switchToDeviceWithID: [Devices getEQMacDeviceID]];

    mEngine = new EQEngine(input, output);
    mEngine->Start();
    
    NSArray *savedGains = [Storage get:kStorageSelectedGains];
    if(!savedGains) savedGains = @[@0,@0,@0,@0,@0,@0,@0,@0,@0,@0];
    [self setEQEngineFrequencyGains: savedGains];
    runStart = [NSDate date];
}

+(void)deleteEQEngine{
    if(mEngine){
        [Storage set:[EQHost getEQEngineFrequencyGains] key:kStorageSelectedGains];
        
        mEngine->Stop();
            
        delete mEngine;
        mEngine = NULL;
        
        [self stopTimer];
    }
}

+(void)stopTimer{
    NSTimeInterval currentRun = -[runStart timeIntervalSinceNow];
    int overallRuntime = [[Storage get: kStorageOverallRuntime] intValue];
    [Storage set:[NSNumber numberWithInt:overallRuntime + currentRun] key:kStorageOverallRuntime];
}

+(BOOL)EQEngineExists{
    return (mEngine != NULL) ? true : false;
}

+(void)setEQEngineFrequencyGains:(NSArray*)gains{
    Float32 *array = new Float32[[gains count]];
    
    for(int i = 0; i < [gains count]; i++){
        array[i] = [[gains objectAtIndex:i] floatValue];
    }
    
    if(mEngine){
        mEngine->SetEqGains(array);
    }
}

+(NSArray*)getEQEngineFrequencyGains{
    if(mEngine){
        Float32 *gains = mEngine->GetEqGains();
        NSMutableArray *convertedGains = [[NSMutableArray alloc] init];
        for(int i = 0; i < 31; i++){
            [convertedGains addObject:[NSNumber numberWithFloat:gains[i]]];
        }
        return convertedGains;
    }else{
        return @[@0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0];
    }
}


+(AudioDeviceID)getSelectedOutputDeviceID{
    if(selectedOutputDeviceID){
        return selectedOutputDeviceID;
    }
    return 0;
}


@end
