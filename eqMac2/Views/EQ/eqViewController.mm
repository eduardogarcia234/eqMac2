//
//  EQViewController.m
//  eqMac2
//
//  Created by Romans Kisils on 10/12/2016.
//  Copyright © 2016 bitgapp. All rights reserved.
//

#import "eqViewController.h"

@interface eqViewController ()

@property (strong) IBOutlet NSButton *deleteButton;
@property (strong) IBOutlet NSButton *saveButton;
@property (strong) IBOutlet NSButton *bandModeButton;

@property (strong) IBOutlet NSButton *bandsButton;
@property (strong) IBOutlet NSPopUpButton *outputDevicePopup;
@property (strong) IBOutlet NSPopUpButton *presetsPopup;
@property (strong) IBOutlet NSView *bandLabelsView;
@property (strong) IBOutlet NSView *mockSliderView;

@property (strong) IBOutlet NSButton *launchOnStartupCheckbox;
@property (strong) IBOutlet NSButton *showDefaultPresetsCheckbox;
@property (strong) IBOutlet NSTextField *buildLabel;

@property (strong) IBOutlet NSSlider *balanceSlider;
@property (strong) IBOutlet NSImageView *leftSpeaker;
@property (strong) IBOutlet NSImageView *rightSpeaker;
@property (strong) IBOutlet NSView *controlsView;
@property (strong) IBOutlet NSView *optionsView;

@end


NSArray *bandArray;
SliderGraphView *sliderView;
NSNotificationCenter *notify;
NSString* BAND_MODE = @"10";
NSArray *devices;

CGFloat defaultWidth = 309;
CGFloat defaultHeight = 383;

@implementation eqViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    sliderView = [[SliderGraphView alloc] initWithFrame: _mockSliderView.frame];
    [sliderView setAutoresizingMask:_mockSliderView.autoresizingMask];
    _mockSliderView = nil;
    [self.view addSubview:sliderView];
    
    notify = [NSNotificationCenter defaultCenter];
    [notify addObserver:self selector:@selector(sliderGraphChanged) name:@"sliderGraphChanged" object:nil];
    [notify addObserver:self selector:@selector(populatePresetsPopup) name:@"showDefaultPresetsChanged" object:nil];
    [notify addObserver:self selector:@selector(readjustSettings) name:@"popoverWillOpen" object:nil];
    
    [self readjustSettings];
    
    [_launchOnStartupCheckbox setState: [Utilities getLaunchOnLogin] ? NSOnState : NSOffState];
    [_showDefaultPresetsCheckbox setState:[[Storage get:kStorageShowDefaultPresets] integerValue]];
    [_buildLabel setStringValue:[@"Build " stringByAppendingString:[Utilities getAppVersion]]];
    
    NSString *previouslySelectedBandMode = [Storage get:kStorageSelectedBandMode];
    if (previouslySelectedBandMode && [@[@"10", @"31"] containsObject:previouslySelectedBandMode]){
        BAND_MODE = previouslySelectedBandMode;
    }
    
    [self populateBandLabelsView];
    [self populatePresetsPopup];
    
    NSString *selectedPresetsName = [Storage get:kStorageSelectedPresetName];
    if(selectedPresetsName) [_presetsPopup setTitle:selectedPresetsName];
}

-(void)readjustSettings{
    [Utilities executeBlock:^{
        //BALANCE
        Float32 currentBalance = [Devices getBalanceForDeviceID:[Devices getVolumeControllerDeviceID]];
        [_balanceSlider setFloatValue:currentBalance];
        [self changeBalanceIcons:currentBalance];
        
    } after:0.01];
}


-(void)populateBandLabelsView{
    [_bandLabelsView setSubviews:@[]];
    NSArray *frequencies = [Constants getEQFrequenciesForBandMode: BAND_MODE];
    NSPoint labelPosition = NSMakePoint(0, 0);
    CGFloat labelWidth = 33;
    CGFloat posIncrement = _bandLabelsView.bounds.size.width / frequencies.count;
    for (NSDictionary *frequency in frequencies) {
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(labelPosition.x, labelPosition.y, labelWidth, 14)];
        [label setFont: [NSFont systemFontOfSize: [BAND_MODE isEqualToString:@"10"] ? 11 : 9]];
        [label setAlignment:NSCenterTextAlignment];
        [label setStringValue:[frequency objectForKey:@"title"]];
        [label setBordered:NO];
        [label setEditable:NO];
        [label setSelectable:NO];
        [label setDrawsBackground:NO];
        [_bandLabelsView addSubview:label];
        labelPosition.x += posIncrement;
    }
}

-(void)viewWillAppear{
    [_deleteButton setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"deleteLight.png"] : [NSImage imageNamed:@"deleteDark.png"]];
    [_saveButton setImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"saveLight.png"] : [NSImage imageNamed:@"saveDark.png"]];
    
    [self populateOutputDevicePopup];

}

-(void)viewDidAppear{
    [Utilities executeBlock:^{
        [sliderView animateBandsToValues:[EQHost getEQEngineFrequencyGains]];
    } after:.1];
}

-(void)populateOutputDevicePopup{
    [_outputDevicePopup removeAllItems];
    devices = [Devices getAllUsableDevices];
    
    NSMutableArray *deviceNames = [[NSMutableArray alloc] init];
    
    for (NSDictionary *device in devices) {
        [deviceNames addObject: [device objectForKey:@"name"]];
    }
    
    [_outputDevicePopup addItemsWithTitles: [deviceNames sortedArrayUsingComparator:^NSComparisonResult(NSString *firstString, NSString *secondString) {
        return [[firstString lowercaseString] compare:[secondString lowercaseString]];
    }]];
    
    AudioDeviceID selectedDeviceID;
    if ([EQHost EQEngineExists]) {
        selectedDeviceID = [EQHost getSelectedOutputDeviceID];
    } else {
        selectedDeviceID = [Devices getCurrentDeviceID];
    }
    
    NSString *selectedDeviceName;
    if (selectedDeviceID == [Devices getEQMacDeviceID]) {
        selectedDeviceName = BUILTIN_DEVICE_NAME;
    } else {
        selectedDeviceName = [Devices getDeviceNameByID: selectedDeviceID];
    }
    [_outputDevicePopup setTitle: selectedDeviceName];
}

#pragma mark -
#pragma mark Presets logic

-(void)populatePresetsPopup{
    [_presetsPopup removeAllItems];
    NSArray *presets = [Presets getShowablePresetsNames];
    [_presetsPopup addItemsWithTitles:[presets sortedArrayUsingComparator:^NSComparisonResult(NSString *firstString, NSString *secondString) {
        return [[firstString lowercaseString] compare:[secondString lowercaseString]];
    }]];
}

- (IBAction)changePreset:(NSPopUpButton *)sender {
    NSString *presetName = [sender titleOfSelectedItem];
    NSArray *gains = [Presets getGainsForPreset:presetName];
    [sliderView animateBandsToValues:gains];
    [EQHost setEQEngineFrequencyGains:gains];
    [_presetsPopup setTitle:presetName];
}

- (IBAction)savePreset:(NSButton *)sender {
    NSString *newPresetName = [Utilities showAlertWithInputAndTitle:NSLocalizedString(@"Please enter a name for your new preset.",nil)];
    if(![newPresetName isEqualToString:@""]){
        [Presets savePreset:[sliderView getBandValues] withName:newPresetName];
        [self populatePresetsPopup];
    }
}

- (IBAction)deletePreset:(id)sender {
    if(![[_presetsPopup title] isEqualToString:NSLocalizedString(@"Flat",nil)]){
        [Presets deletePresetWithName:[_presetsPopup title]];
        [self populatePresetsPopup];
        [_presetsPopup setTitle:NSLocalizedString(@"Flat",nil)];
        [self resetEQ:nil];
    }
}


#pragma mark -
#pragma mark UI Actions
-(void)sliderGraphChanged{
    [_presetsPopup setTitle:NSLocalizedString(@"Custom",nil)];
    [EQHost setEQEngineFrequencyGains:[sliderView getBandValues]];
}

- (IBAction)changeDevice:(NSPopUpButton *)sender {
    NSString *deviceName = [sender titleOfSelectedItem];
    NSDictionary *selectedDevice;
    
    for (NSDictionary *device in devices) {
        if ([[device objectForKey:@"name"] isEqualToString: deviceName]) {
            selectedDevice = device;
        }
    }
    
    if (selectedDevice) {
        [Devices switchToDeviceWithID:[[selectedDevice objectForKey:@"id"] intValue] ];
    }
}

- (IBAction)resetEQ:(id)sender {
    [_presetsPopup setTitle:NSLocalizedString(@"Flat",nil)];
    NSArray *flatGains = @[@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0,@0];
    [sliderView animateBandsToValues:flatGains];
    [EQHost setEQEngineFrequencyGains:flatGains];
}

-(NSString*)getSelectedPresetName{
    return [_presetsPopup title];
}

-(void)setBandModeButtonText{
    if ([BAND_MODE isEqualToString:@"10"]) {
        [_bandModeButton setTitle:@"31 Bands"];
    } else if ([BAND_MODE isEqualToString:@"31"]) {
        [_bandModeButton setTitle:@"10 Bands"];
    }
}
- (IBAction)toggleBandMode:(id)sender {
    if ([BAND_MODE isEqualToString:@"10"]) {
        BAND_MODE = @"31";
    } else if ([BAND_MODE isEqualToString:@"31"]) {
        BAND_MODE = @"10";
    }
    [self setBandModeButtonText];
    [self readjustSize];
    [sliderView setNSliders:[BAND_MODE intValue]];
}

-(void)readjustSize{
    if ([BAND_MODE isEqualToString:@"10"]) {
        NSRect newViewRect = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, defaultWidth, defaultHeight);
        [self.view setFrame: newViewRect];
        [_optionsView setFrame:CGRectMake(0, _controlsView.frame.origin.y - _optionsView.frame.size.height, defaultWidth, _optionsView.frame.size.height)];
    } else if ([BAND_MODE isEqualToString:@"31"]) {
        NSRect newViewRect = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, defaultWidth * 2, defaultHeight - _optionsView.frame.size.height);
        [self.view setFrame: newViewRect];
        [_optionsView setFrame:CGRectMake(defaultWidth, _controlsView.frame.origin.y, defaultWidth, _optionsView.frame.size.height)];
    }
    [sliderView setFrame: CGRectMake(sliderView.frame.origin.x, sliderView.frame.origin.y, _bandLabelsView.frame.size.width, sliderView.frame.size.height)];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"readjustPopover" object:nil];
}

-(void)setSelectedPresetName:(NSString*)name{
    [_presetsPopup setTitle:name];
}

- (IBAction)onOffToggle:(ITSwitch *)sender {
    BOOL checked = [sender checked];
    [_presetsPopup setEnabled: checked];
    [_saveButton setEnabled:checked];
    [_deleteButton setEnabled: checked];
    [sliderView enable: checked];

}

- (IBAction)switchShowDefaultPresets:(NSButton *)sender {
    [Storage set:[NSNumber numberWithInteger:[sender state]] key:kStorageShowDefaultPresets];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showDefaultPresetsChanged" object:nil];
}

- (IBAction)checkForUpdates:(id)sender {
}

- (IBAction)reportBug:(id)sender {
    [Utilities openBrowserWithURL:REPO_ISSUES_URL];
}

- (IBAction)getHelp:(id)sender {
    [Utilities openBrowserWithURL:SUPPORT_URL];
}

- (IBAction)supportProject:(id)sender{
    // Open Support Window
}

- (IBAction)changeBalance:(NSSlider *)sender {
    Float32 balance = [sender floatValue];
    [Devices setBalanceForDevice:[Devices getVolumeControllerDeviceID] to:balance];
    [self changeBalanceIcons: [sender floatValue]];
}

-(void)changeBalanceIcons:(CGFloat)balance{
    if (balance == -1) {
        [_leftSpeaker setImage: [Utilities flipImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol1Light.png"] : [NSImage imageNamed:@"vol1Dark.png"]];
    }else if(balance >-1 && balance <= -0.5){
        [_leftSpeaker setImage: [Utilities flipImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol2Light.png"] : [NSImage imageNamed:@"vol2Dark.png"]];
        
    }else if(balance > -0.5 && balance < 0){
        [_leftSpeaker setImage: [Utilities flipImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol3Light.png"] : [NSImage imageNamed:@"vol3Dark.png"]];
        
    }else if(balance == 0){
        [_leftSpeaker setImage: [Utilities flipImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]];
        
    }else if(balance >0 && balance <= 0.5){
        [_leftSpeaker setImage: [Utilities flipImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"vol3Light.png"] : [NSImage imageNamed:@"vol3Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]];
        
    }else if(balance >0.5 && balance < 1){
        [_leftSpeaker setImage: [Utilities flipImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"vol2Light.png"] : [NSImage imageNamed:@"vol2Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]];
    }else{
        [_leftSpeaker setImage: [Utilities flipImage:[Utilities isDarkMode] ? [NSImage imageNamed:@"vol1Light.png"] : [NSImage imageNamed:@"vol1Dark.png"]]];
        [_rightSpeaker setImage: [Utilities isDarkMode] ? [NSImage imageNamed:@"vol4Light.png"] : [NSImage imageNamed:@"vol4Dark.png"]];
    }
    
}

- (IBAction)changeLaunchOnStartup:(NSButton*)sender {
    [Utilities setLaunchOnLogin:[sender state] == NSOnState ? true : false];
}

- (IBAction)quitApplication:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"closeApp" object:nil];
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
