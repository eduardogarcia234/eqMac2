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
@end


NSArray *bandArray;
SliderGraphView *sliderView;
NSNotificationCenter *notify;
NSString* BAND_MODE = @"31";
NSArray *devices;

@implementation eqViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    sliderView = [[SliderGraphView alloc] initWithFrame: _mockSliderView.frame];
    _mockSliderView = nil;
    [self.view addSubview:sliderView];
        
    notify = [NSNotificationCenter defaultCenter];
    [notify addObserver:self selector:@selector(sliderGraphChanged) name:@"sliderGraphChanged" object:nil];
    [notify addObserver:self selector:@selector(populatePresetsPopup) name:@"showDefaultPresetsChanged" object:nil];
    
    NSString *previouslySelectedBandMode = [Storage get:kStorageSelectedBandMode];
    if (previouslySelectedBandMode && [@[@"10", @"31"] containsObject:previouslySelectedBandMode]){
        BAND_MODE = previouslySelectedBandMode;
    }
    
    [self populateBandLabelsView];
    [self populatePresetsPopup];
    [self populateOutputDevicePopup];
    
    NSString *selectedPresetsName = [Storage get:kStorageSelectedPresetName];
    if(selectedPresetsName) [_presetsPopup setTitle:selectedPresetsName];
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
    [_outputDevicePopup setTitle: [Devices getDeviceNameByID: [EQHost EQEngineExists] ? [EQHost getSelectedOutputDeviceID] : [Devices getCurrentDeviceID]]];
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
    [sliderView setNSliders:[BAND_MODE intValue]];
}

-(void)setSelectedPresetName:(NSString*)name{
    [_presetsPopup setTitle:name];
}

@end
