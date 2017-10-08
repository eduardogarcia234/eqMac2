
#ifndef Constants_h
#define Constants_h
extern NSString * const DRIVER_UID;
extern NSString * const DRIVER_NAME;
extern NSString * const BUILTIN_DEVICE_NAME;
extern NSString * const API_URL;
extern NSString * const APP_URL;
extern NSString * const SUPPORT_URL;
extern NSString * const DONATE_URL;
extern NSString * const REPO_ISSUES_URL;
extern Float32    const FULL_VOLUME_STEP;
extern Float32    const QUARTER_VOLUME_STEP;

@interface Constants : NSObject
+(NSArray*)getEQFrequenciesForBandMode:(NSString *)BAND_MODE;
@end

#endif /* Constants_h */
