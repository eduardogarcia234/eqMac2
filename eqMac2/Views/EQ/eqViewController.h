//
//  EQViewController.h
//  eqMac2
//
//  Created by Romans Kisils on 10/12/2016.
//  Copyright © 2016 bitgapp. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EQHost.h"
#import "SliderGraphView.h"
#import "Constants.h"
#import "AppDelegate.h"
#import "Utilities.h"
#import "Presets.h"
#import "Devices.h"
#import "API.h"
#import <WebKit/WebKit.h>
#import "ITSwitch.h"

@interface eqViewController : NSViewController
-(NSString*)getSelectedPresetName;
-(void)setSelectedPresetName:(NSString*)name;
@end
