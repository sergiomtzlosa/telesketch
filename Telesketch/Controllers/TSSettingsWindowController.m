#import "TSSettingsWindowController.h"
#import "TSOpenCodeService.h"
#import "TSTheme.h"

static const CGFloat TSSettingsWidth = 560.0;
static const CGFloat TSSettingsHeight = 500.0;

static NSTextField *TSSettingsLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.drawsBackground = NO;
    label.bordered = NO;
    label.editable = NO;
    label.selectable = NO;
    return label;
}

static NSTextField *TSSectionLabel(NSString *text) {
    NSTextField *label = TSSettingsLabel(text.uppercaseString, 10.0, NSFontWeightSemibold,
                                         [NSColor colorWithCalibratedWhite:0.74 alpha:1.0]);
    label.attributedStringValue = [[NSAttributedString alloc] initWithString:text.uppercaseString
        attributes:@{
            NSFontAttributeName: [NSFont systemFontOfSize:10.0 weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.68 alpha:1.0],
            NSKernAttributeName: @1.3
        }];
    return label;
}

@interface TSSettingsWindowController () <NSWindowDelegate, NSTextFieldDelegate>
@property (nonatomic, strong) NSSegmentedControl *tabControl;
@property (nonatomic, strong) NSView *contentContainer;
@property (nonatomic, strong) NSView *generalPane;
@property (nonatomic, strong) NSView *aiPane;
@property (nonatomic, strong) NSView *aboutPane;

@property (nonatomic, strong) NSPopUpButton *themePopup;
@property (nonatomic, strong) NSPopUpButton *enginePopup;
@property (nonatomic, strong) NSButton *shakeCheckbox;

@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *detailLabel;
@property (nonatomic, strong) NSTextField *externalURLField;
@property (nonatomic, strong) NSSecureTextField *externalPasswordField;
@property (nonatomic, strong) NSTextField *pathField;
@property (nonatomic, strong) NSButton *autoStartCheckbox;
@property (nonatomic, strong) NSButton *startButton;
@property (nonatomic, strong) NSButton *stopButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSTextField *modelCountLabel;
@end

@implementation TSSettingsWindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, TSSettingsWidth, TSSettingsHeight);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Telesketch Settings";
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.releasedWhenClosed = NO;
    window.backgroundColor = [NSColor colorWithSRGBRed:0.085 green:0.100 blue:0.091 alpha:1.0];
    [window setFrameAutosaveName:@"TSSettingsWindow"];
    // Autosave can restore the pre-external-server 430 pt height, which clips the new
    // AI fields. Always enforce the current content size.
    [window setContentSize:NSMakeSize(TSSettingsWidth, TSSettingsHeight)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        [self buildInterface];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(openCodeStatusChanged:)
                                                     name:TSOpenCodeServiceStatusDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(openCodeStatusChanged:)
                                                     name:TSOpenCodeServiceModelsDidChangeNotification
                                                   object:nil];
        [self updateAIStatus];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildInterface {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    self.tabControl = [NSSegmentedControl segmentedControlWithLabels:@[@"General", @"AI", @"About"]
                                                        trackingMode:NSSegmentSwitchTrackingSelectOne
                                                              target:self
                                                              action:@selector(tabChanged:)];
    self.tabControl.frame = NSMakeRect(18, TSSettingsHeight - 52, TSSettingsWidth - 36, 30);
    self.tabControl.selectedSegment = 0;
    [content addSubview:self.tabControl];

    self.contentContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, TSSettingsWidth, TSSettingsHeight - 62)];
    [content addSubview:self.contentContainer];

    self.generalPane = [self buildGeneralPane];
    self.aiPane = [self buildAIPane];
    self.aboutPane = [self buildAboutPane];
    for (NSView *pane in @[self.generalPane, self.aiPane, self.aboutPane]) {
        pane.frame = self.contentContainer.bounds;
        pane.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        pane.hidden = (pane != self.generalPane);
        [self.contentContainer addSubview:pane];
    }
}

- (NSView *)buildGeneralPane {
    NSView *pane = [[NSView alloc] initWithFrame:NSZeroRect];

    NSTextField *newDocs = TSSectionLabel(@"New documents");
    newDocs.frame = NSMakeRect(22, 322, 300, 14);
    [pane addSubview:newDocs];

    NSTextField *themeLabel = TSSettingsLabel(@"Screen theme", 12.0, NSFontWeightRegular,
                                              [NSColor colorWithCalibratedWhite:0.86 alpha:1.0]);
    themeLabel.frame = NSMakeRect(22, 282, 170, 18);
    [pane addSubview:themeLabel];

    self.themePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(214, 278, 220, 26) pullsDown:NO];
    self.themePopup.controlSize = NSControlSizeRegular;
    for (TSTheme *theme in [TSTheme allThemes]) {
        [self.themePopup addItemWithTitle:theme.displayName];
        self.themePopup.lastItem.representedObject = theme.identifier;
    }
    NSString *currentTheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSDefaultTheme"] ?: @"classic";
    for (NSMenuItem *item in self.themePopup.itemArray) {
        if ([item.representedObject isEqualToString:currentTheme]) {
            [self.themePopup selectItem:item];
            break;
        }
    }
    self.themePopup.target = self;
    self.themePopup.action = @selector(defaultThemeChanged:);
    [pane addSubview:self.themePopup];

    NSTextField *engineLabel = TSSettingsLabel(@"Default engine", 12.0, NSFontWeightRegular,
                                               [NSColor colorWithCalibratedWhite:0.86 alpha:1.0]);
    engineLabel.frame = NSMakeRect(22, 242, 170, 18);
    [pane addSubview:engineLabel];

    self.enginePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(214, 238, 220, 26) pullsDown:NO];
    [self.enginePopup addItemWithTitle:@"OpenCode"];
    [self.enginePopup addItemWithTitle:@"Offline"];
    NSInteger defaultEngine = [[NSUserDefaults standardUserDefaults] integerForKey:@"TSDefaultEngine"];
    [self.enginePopup selectItemAtIndex:(defaultEngine == 1) ? 1 : 0];
    self.enginePopup.target = self;
    self.enginePopup.action = @selector(defaultEngineChanged:);
    [pane addSubview:self.enginePopup];

    NSTextField *explanation = TSSettingsLabel(@"These preferences apply to documents you create from now on. "
                                               @"Use the Screen control in the tool rail to change the current drawing.",
                                               11.0, NSFontWeightRegular,
                                               [NSColor colorWithCalibratedWhite:0.56 alpha:1.0]);
    explanation.frame = NSMakeRect(22, 196, 500, 34);
    [pane addSubview:explanation];

    NSTextField *behaviour = TSSectionLabel(@"Behaviour");
    behaviour.frame = NSMakeRect(22, 150, 300, 14);
    [pane addSubview:behaviour];

    self.shakeCheckbox = [NSButton checkboxWithTitle:@"Shake the device when clearing the screen"
                                              target:self
                                              action:@selector(shakeSettingChanged:)];
    self.shakeCheckbox.frame = NSMakeRect(22, 118, 460, 20);
    self.shakeCheckbox.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"TSShakeAnimation"] ? NSControlStateValueOn : NSControlStateValueOff;
    [pane addSubview:self.shakeCheckbox];

    NSTextField *motionNote = TSSettingsLabel(@"Reduce Motion and Increase Contrast are always respected.",
                                              11.0, NSFontWeightRegular,
                                              [NSColor colorWithCalibratedWhite:0.48 alpha:1.0]);
    motionNote.frame = NSMakeRect(22, 92, 500, 18);
    [pane addSubview:motionNote];

    return pane;
}

- (NSView *)buildAIPane {
    NSView *pane = [[NSView alloc] initWithFrame:NSZeroRect];

    NSTextField *connection = TSSectionLabel(@"OpenCode connection");
    connection.frame = NSMakeRect(22, 396, 300, 14);
    [pane addSubview:connection];

    self.statusLabel = TSSettingsLabel(@"OpenCode is stopped.", 12.0, NSFontWeightMedium,
                                       [NSColor colorWithCalibratedWhite:0.88 alpha:1.0]);
    self.statusLabel.frame = NSMakeRect(22, 364, 500, 20);
    [pane addSubview:self.statusLabel];

    self.detailLabel = TSSettingsLabel(@"", 10.5, NSFontWeightRegular,
                                       [NSColor colorWithCalibratedWhite:0.56 alpha:1.0]);
    self.detailLabel.frame = NSMakeRect(22, 338, 500, 18);
    [pane addSubview:self.detailLabel];

    NSTextField *externalLabel = TSSectionLabel(@"External server");
    externalLabel.frame = NSMakeRect(22, 304, 300, 14);
    [pane addSubview:externalLabel];

    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    self.externalURLField = [[NSTextField alloc] initWithFrame:NSMakeRect(22, 270, 500, 26)];
    self.externalURLField.placeholderString = @"http://127.0.0.1:4096 — leave empty to start a local helper";
    self.externalURLField.font = [NSFont monospacedSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    self.externalURLField.stringValue = service.externalServerURLString ?: @"";
    self.externalURLField.target = self;
    self.externalURLField.action = @selector(externalSettingsChanged:);
    self.externalURLField.delegate = self;
    [pane addSubview:self.externalURLField];

    self.externalPasswordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(22, 238, 500, 26)];
    self.externalPasswordField.placeholderString = @"Server password (username is always opencode)";
    self.externalPasswordField.font = [NSFont monospacedSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    self.externalPasswordField.stringValue = service.externalServerPassword ?: @"";
    self.externalPasswordField.target = self;
    self.externalPasswordField.action = @selector(externalSettingsChanged:);
    self.externalPasswordField.delegate = self;
    [pane addSubview:self.externalPasswordField];

    NSTextField *helperLabel = TSSectionLabel(@"Local helper");
    helperLabel.frame = NSMakeRect(22, 204, 300, 14);
    [pane addSubview:helperLabel];

    NSTextField *binaryLabel = TSSettingsLabel(@"opencode binary", 12.0, NSFontWeightRegular,
                                               [NSColor colorWithCalibratedWhite:0.86 alpha:1.0]);
    binaryLabel.frame = NSMakeRect(22, 182, 140, 18);
    [pane addSubview:binaryLabel];

    self.pathField = [[NSTextField alloc] initWithFrame:NSMakeRect(22, 154, 500, 26)];
    self.pathField.placeholderString = @"Auto-detect — leave empty to search PATH and common locations";
    self.pathField.font = [NSFont monospacedSystemFontOfSize:11.0 weight:NSFontWeightRegular];
    self.pathField.stringValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSOpenCodeBinaryPath"] ?: @"";
    self.pathField.target = self;
    self.pathField.action = @selector(binaryPathChanged:);
    self.pathField.delegate = self;
    [pane addSubview:self.pathField];

    self.startButton = [NSButton buttonWithTitle:@"Connect" target:self action:@selector(startServer:)];
    self.startButton.bezelStyle = NSBezelStyleRounded;
    self.startButton.frame = NSMakeRect(22, 114, 118, 30);
    [pane addSubview:self.startButton];

    self.stopButton = [NSButton buttonWithTitle:@"Disconnect" target:self action:@selector(stopServer:)];
    self.stopButton.bezelStyle = NSBezelStyleRounded;
    self.stopButton.frame = NSMakeRect(146, 114, 96, 30);
    [pane addSubview:self.stopButton];

    self.refreshButton = [NSButton buttonWithTitle:@"Refresh Models" target:self action:@selector(refreshModels:)];
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.frame = NSMakeRect(248, 114, 138, 30);
    [pane addSubview:self.refreshButton];

    self.modelCountLabel = TSSettingsLabel(@"No model information yet.", 10.5, NSFontWeightRegular,
                                           [NSColor colorWithCalibratedWhite:0.54 alpha:1.0]);
    self.modelCountLabel.frame = NSMakeRect(396, 120, 126, 18);
    [pane addSubview:self.modelCountLabel];

    self.autoStartCheckbox = [NSButton checkboxWithTitle:@"Start OpenCode automatically when the AI atelier opens"
                                                   target:self
                                                   action:@selector(autoStartChanged:)];
    self.autoStartCheckbox.frame = NSMakeRect(22, 86, 500, 20);
    self.autoStartCheckbox.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"TSAutoStartOpenCode"]
        ? NSControlStateValueOn : NSControlStateValueOff;
    [pane addSubview:self.autoStartCheckbox];

    NSTextField *note = TSSettingsLabel(@"Leave the server URL empty to let Telesketch launch its own helper and capture "
                                        @"the generated password. Enter a URL and password to use an OpenCode server "
                                        @"that is already running. Cloud models can hit rate limits; local Ollama "
                                        @"models and the built-in offline engine remain available.",
                                        11.0, NSFontWeightRegular,
                                        [NSColor colorWithCalibratedWhite:0.52 alpha:1.0]);
    note.frame = NSMakeRect(22, 24, 500, 56);
    [pane addSubview:note];

    return pane;
}

- (NSView *)buildAboutPane {
    NSView *pane = [[NSView alloc] initWithFrame:NSZeroRect];

    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(22, 218, 96, 96)];
    iconView.image = NSApp.applicationIconImage ?: [NSImage imageNamed:NSImageNameApplicationIcon];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [pane addSubview:iconView];

    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSTextField *name = TSSettingsLabel(@"Telesketch", 24.0, NSFontWeightSemibold,
                                        [NSColor colorWithCalibratedWhite:0.95 alpha:1.0]);
    name.frame = NSMakeRect(136, 278, 380, 30);
    [pane addSubview:name];

    NSTextField *versionLabel = TSSettingsLabel([NSString stringWithFormat:@"Version %@ · Atelier Edition", version],
                                                11.0, NSFontWeightMedium,
                                                [NSColor colorWithCalibratedWhite:0.58 alpha:1.0]);
    versionLabel.frame = NSMakeRect(136, 252, 380, 18);
    [pane addSubview:versionLabel];

    NSTextField *description = TSSettingsLabel(@"A native Objective-C studio for the drawing machine of your childhood: "
                                               @"freehand ink, tactile knobs, three screen themes, AI sketches through "
                                               @"OpenCode, and a guaranteed offline generative engine.",
                                               11.5, NSFontWeightRegular,
                                               [NSColor colorWithCalibratedWhite:0.70 alpha:1.0]);
    description.frame = NSMakeRect(136, 166, 390, 72);
    [pane addSubview:description];

    NSTextField *serial = TSSettingsLabel(@"Nº 001 · Made for the desk, not the cloud.", 10.0, NSFontWeightMedium,
                                          [NSColor colorWithCalibratedWhite:0.46 alpha:1.0]);
    serial.frame = NSMakeRect(22, 112, 500, 18);
    [pane addSubview:serial];

    NSButton *logButton = [NSButton buttonWithTitle:@"Reveal OpenCode Log" target:self action:@selector(revealLog:)];
    logButton.bezelStyle = NSBezelStyleRounded;
    logButton.frame = NSMakeRect(22, 64, 178, 30);
    [pane addSubview:logButton];

    NSButton *docsButton = [NSButton buttonWithTitle:@"Draw Something" target:self action:@selector(closeSettings:)];
    docsButton.bezelStyle = NSBezelStyleRounded;
    docsButton.frame = NSMakeRect(208, 64, 146, 30);
    [pane addSubview:docsButton];

    return pane;
}

#pragma mark - Actions

- (void)tabChanged:(NSSegmentedControl *)sender {
    self.generalPane.hidden = sender.selectedSegment != 0;
    self.aiPane.hidden = sender.selectedSegment != 1;
    self.aboutPane.hidden = sender.selectedSegment != 2;
}

- (void)defaultThemeChanged:(NSPopUpButton *)sender {
    NSString *identifier = sender.selectedItem.representedObject ?: @"classic";
    [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:@"TSDefaultTheme"];
}

- (void)defaultEngineChanged:(NSPopUpButton *)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:sender.indexOfSelectedItem == 1 ? 1 : 0
                                               forKey:@"TSDefaultEngine"];
}

- (void)shakeSettingChanged:(NSButton *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:(sender.state == NSControlStateValueOn)
                                            forKey:@"TSShakeAnimation"];
}

- (void)autoStartChanged:(NSButton *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:(sender.state == NSControlStateValueOn)
                                            forKey:@"TSAutoStartOpenCode"];
}

- (void)binaryPathChanged:(NSTextField *)sender {
    NSString *path = [sender.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    service.binaryPathOverride = path;
    if (service.status == TSOpenCodeStatusReady && !service.usesExternalServer) {
        [service restart];
    }
    [self updateAIStatus];
}

- (void)externalSettingsChanged:(id)sender {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    service.externalServerURLString = self.externalURLField.stringValue;
    service.externalServerPassword = self.externalPasswordField.stringValue;
    if (service.status == TSOpenCodeStatusReady || service.status == TSOpenCodeStatusStarting) {
        [service restart];
    }
    [self updateAIStatus];
}

- (void)startServer:(id)sender {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    [self externalSettingsChanged:self.externalURLField];
    if (!service.usesExternalServer) {
        [self binaryPathChanged:self.pathField];
    }
    __weak typeof(self) weakSelf = self;
    [[TSOpenCodeService sharedService] startWithCompletion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self updateAIStatus];
        if (error) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        }
    }];
    [self updateAIStatus];
}

- (void)stopServer:(id)sender {
    [[TSOpenCodeService sharedService] stop];
    [self updateAIStatus];
}

- (void)refreshModels:(id)sender {
    __weak typeof(self) weakSelf = self;
    [[TSOpenCodeService sharedService] refreshModelsWithCompletion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self updateAIStatus];
        if (error) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        }
    }];
}

- (void)revealLog:(id)sender {
    NSString *path = [@"~/Library/Logs/Telesketch/opencode.log" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
    } else {
        NSBeep();
    }
}

- (void)closeSettings:(id)sender {
    [self.window performClose:sender];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if (notification.object == self.pathField) {
        [self binaryPathChanged:self.pathField];
    } else if (notification.object == self.externalURLField ||
               notification.object == self.externalPasswordField) {
        [self externalSettingsChanged:notification.object];
    }
}

#pragma mark - Status

- (void)openCodeStatusChanged:(NSNotification *)notification {
    [self updateAIStatus];
}

- (void)updateAIStatus {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    BOOL external = service.usesExternalServer;
    NSString *statusText = external ? @"External OpenCode server configured." : @"OpenCode is stopped.";
    NSString *detail = external
        ? [NSString stringWithFormat:@"Server: %@", service.externalServerURLString]
        : (service.discoveredBinaryPath.length > 0
            ? [NSString stringWithFormat:@"Binary: %@", service.discoveredBinaryPath]
            : @"No opencode binary found yet.");

    switch (service.status) {
        case TSOpenCodeStatusStopped:
            statusText = external ? @"External OpenCode server configured." : @"OpenCode is stopped.";
            break;
        case TSOpenCodeStatusStarting:
            statusText = external ? @"Connecting to the external OpenCode server…" : @"Starting the OpenCode server…";
            break;
        case TSOpenCodeStatusReady:
            statusText = [NSString stringWithFormat:@"Connected to %@", service.connectionSummary ?: @"OpenCode"];
            if (service.serverURLString.length > 0) {
                detail = [NSString stringWithFormat:@"%@ · username %@ · %@",
                          service.serverURLString,
                          service.serverUsername,
                          external ? @"password from settings" : @"password captured from server"];
            }
            break;
        case TSOpenCodeStatusFailed:
            statusText = external ? @"Could not connect to the external server." : @"OpenCode could not start.";
            detail = service.lastError.length > 0 ? service.lastError : detail;
            break;
    }

    self.statusLabel.stringValue = statusText;
    self.detailLabel.stringValue = detail;
    self.detailLabel.toolTip = detail;

    if (service.models.count == 0) {
        self.modelCountLabel.stringValue = @"No models loaded";
    } else {
        NSUInteger localCount = 0;
        for (TSOpenCodeModel *model in service.models) {
            if (model.localModel) localCount++;
        }
        self.modelCountLabel.stringValue = [NSString stringWithFormat:@"%lu models · %lu local",
                                            (unsigned long)service.models.count, (unsigned long)localCount];
    }

    BOOL ready = service.status == TSOpenCodeStatusReady;
    self.startButton.enabled = !ready && service.status != TSOpenCodeStatusStarting;
    self.stopButton.enabled = service.status != TSOpenCodeStatusStopped;
    self.refreshButton.enabled = ready;
    if (self.pathField.currentEditor == nil) {
        self.pathField.stringValue = service.binaryPathOverride ?: @"";
    }
    if (self.externalURLField.currentEditor == nil) {
        self.externalURLField.stringValue = service.externalServerURLString ?: @"";
    }
    if (self.externalPasswordField.currentEditor == nil) {
        self.externalPasswordField.stringValue = service.externalServerPassword ?: @"";
    }
}

@end
