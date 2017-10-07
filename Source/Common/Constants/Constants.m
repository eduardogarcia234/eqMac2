
#import <Foundation/Foundation.h>
#import "Constants.h"

NSString * const DRIVER_NAME = @"eqMac Audio";
NSString * const BUILTIN_DEVICE_NAME = @"Built-in Device";
NSString * const API_URL = @"https://eqmac-api.bitgapp.com";
NSString * const APP_URL = @"https://bitgapp.com/eqmac/";
NSString * const SUPPORT_URL = @"https://go.crisp.chat/chat/embed/?website_id=d43e2906-97e3-4c50-82ea-6fa04383b983";
NSString * const DONATE_URL = @"https://bitgapp.com/eqmac/#/donate";
NSString * const REPO_ISSUES_URL = @"https://github.com/romankisil/eqMac2/blob/master/CONTRIBUTING.md";
Float32 const FULL_VOLUME_STEP = 0.0625;
Float32 const QUARTER_VOLUME_STEP = 0.015625;

@implementation Constants

+(NSArray*)getEQFrequenciesForBandMode:(NSString *)BAND_MODE{
    if ([BAND_MODE isEqualToString:@"10"]) {
        return @[@{
                     @"title": @"32",
                     @"frequency": @32
                     }, @{
                     @"title": @"64",
                     @"frequency": @64
                     }, @{
                     @"title": @"125",
                     @"frequency": @125
                     }, @{
                     @"title": @"250",
                     @"frequency": @250
                     }, @{
                     @"title": @"500",
                     @"frequency": @500
                     }, @{
                     @"title": @"1K",
                     @"frequency": @1000
                     }, @{
                     @"title": @"2K",
                     @"frequency": @2000
                     }, @{
                     @"title": @"4K",
                     @"frequency": @4000
                     }, @{
                     @"title": @"8K",
                     @"frequency": @8000
                     }, @{
                     @"title": @"16K",
                     @"frequency": @16000
                     }];
    } else if([BAND_MODE isEqualToString:@"31"]) {
        return @[@{
                     @"title": @"20",
                     @"frequency": @20
                     }, @{
                     @"title": @"25",
                     @"frequency": @25
                     }, @{
                     @"title": @"31.5",
                     @"frequency": @31.5
                     }, @{
                     @"title": @"40",
                     @"frequency": @40
                     }, @{
                     @"title": @"50",
                     @"frequency": @50
                     }, @{
                     @"title": @"63",
                     @"frequency": @63
                     }, @{
                     @"title": @"80",
                     @"frequency": @80
                     }, @{
                     @"title": @"100",
                     @"frequency": @100
                     }, @{
                     @"title": @"125",
                     @"frequency": @125
                     }, @{
                     @"title": @"160",
                     @"frequency": @160
                     }, @{
                     @"title": @"200",
                     @"frequency": @200
                     }, @{
                     @"title": @"250",
                     @"frequency": @250
                     }, @{
                     @"title": @"315",
                     @"frequency": @315
                     }, @{
                     @"title": @"400",
                     @"frequency": @400
                     }, @{
                     @"title": @"500",
                     @"frequency": @500
                     }, @{
                     @"title": @"630",
                     @"frequency": @1000
                     }, @{
                     @"title": @"800",
                     @"frequency": @800
                     }, @{
                     @"title": @"1K",
                     @"frequency": @1000
                     }, @{
                     @"title": @"1.25K",
                     @"frequency": @1250
                     }, @{
                     @"title": @"1.6K",
                     @"frequency": @1600
                     }, @{
                     @"title": @"2K",
                     @"frequency": @2000
                     }, @{
                     @"title": @"2.5K",
                     @"frequency": @2500
                     }, @{
                     @"title": @"3.15",
                     @"frequency": @3150
                     }, @{
                     @"title": @"4K",
                     @"frequency": @4000
                     }, @{
                     @"title": @"5K",
                     @"frequency": @5000
                     }, @{
                     @"title": @"6.3K",
                     @"frequency": @6300
                     }, @{
                     @"title": @"8K",
                     @"frequency": @8000
                     }, @{
                     @"title": @"10K",
                     @"frequency": @10000
                     }, @{
                     @"title": @"12.5K",
                     @"frequency": @8000
                     }, @{
                     @"title": @"16K",
                     @"frequency": @16000
                     } , @{
                     @"title": @"20K",
                     @"frequency": @20000
                     }];
    }
    return @[];
}

@end

