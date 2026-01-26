#import "TSAppDelegate.h"
#import "TSMainMenu.h"
#import "TSSettingsWindowController.h"
#import "TSOpenCodeService.h"
#import "TSDeveloperHarness.h"

@interface TSAppDelegate () <NSMenuDelegate>
@property (nonatomic, strong, nullable) TSSettingsWindowController *settingsWindowController;
@property (nonatomic, weak, nullable) NSMenu *openRecentMenu;
@end

@implementation TSAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [self registerDefaults];

    NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    NSApp.mainMenu = [TSMainMenu buildMainMenu];

    NSMenu *fileMenu = [self menuWithTitle:@"File" inMenu:NSApp.mainMenu];
    NSMenuItem *recentItem = [fileMenu itemWithTitle:@"Open Recent"];
    if (recentItem.submenu) {
        self.openRecentMenu = recentItem.submenu;
        recentItem.submenu.delegate = self;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp activateIgnoringOtherApps:YES];
    NSDocumentController *controller = [NSDocumentController sharedDocumentController];
    if (controller.documents.count == 0) {
        [controller newDocument:nil];
    }
    [TSDeveloperHarness runIfRequested];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return YES;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender {
    [[NSDocumentController sharedDocumentController] newDocument:nil];
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        NSDocumentController *controller = [NSDocumentController sharedDocumentController];
        if (controller.documents.count > 0) {
            [controller.documents.firstObject showWindows];
        } else {
            [controller newDocument:nil];
        }
    }
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // The app is about to exit, so terminate the helper synchronously; an
    // asynchronous stop would be discarded with the run loop.
    [[TSOpenCodeService sharedService] shutdown];
}

#pragma mark - Defaults

- (void)registerDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"TSDefaultTheme": @"classic",
        @"TSDefaultEngine": @0,
        @"TSAutoStartOpenCode": @YES,
        @"TSShakeAnimation": @YES,
        @"TSCustomInkColor": @"#7A5CA8"
    }];
}

#pragma mark - Actions

- (IBAction)showAbout:(nullable id)sender {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    NSAttributedString *credits = [[NSAttributedString alloc] initWithString:
        [NSString stringWithFormat:@"A native studio for the drawing machine of your childhood.\n\nVersion %@ · Objective-C + AppKit\nOffline generative sketches included.", version]
        attributes:@{
            NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular],
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
            NSParagraphStyleAttributeName: paragraph
        }];
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName: @"Telesketch",
        NSAboutPanelOptionApplicationVersion: version,
        NSAboutPanelOptionVersion: [NSString stringWithFormat:@"Version %@", version],
        NSAboutPanelOptionCredits: credits
    }];
}

- (IBAction)showSettings:(nullable id)sender {
    if (!self.settingsWindowController) {
        self.settingsWindowController = [[TSSettingsWindowController alloc] init];
    }
    [self.settingsWindowController showWindow:sender];
    [self.settingsWindowController.window makeKeyAndOrderFront:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)showHelp:(nullable id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Telesketch shortcuts";
    alert.informativeText =
        @"Draw directly on the glass with the pen.\n\n"
        @"B — pen      E — eraser      K — knob mode\n"
        @"1–6 — ink colours      [ / ] — line width\n"
        @"⌘Z / ⇧⌘Z — undo, redo      Esc — cancel a generation or reveal\n"
        @"⌘K — shake to clear      ⌘↩ — generate with AI\n"
        @"⇧⌘↩ — generate offline      ⌘⌥1 / ⌘⌥2 — toggle rails\n\n"
        @"In knob mode, click the screen to place the stylus, then turn the "
        @"horizontal and vertical knobs (or drag them) to draw. Arrow keys "
        @"move the focused knob.";
    [alert addButtonWithTitle:@"Got it"];
    [alert beginSheetModalForWindow:NSApp.keyWindow completionHandler:nil];
}

- (IBAction)revealOpenCodeLog:(nullable id)sender {
    NSString *path = [@"~/Library/Logs/Telesketch/opencode.log" stringByExpandingTildeInPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:path]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"No OpenCode log yet";
        alert.informativeText = @"A log will appear after Telesketch starts the OpenCode server for the first time.";
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:NSApp.keyWindow completionHandler:nil];
    }
}

#pragma mark - Open Recent

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu != self.openRecentMenu) return;

    [menu removeAllItems];
    NSArray<NSURL *> *urls = [NSDocumentController sharedDocumentController].recentDocumentURLs;
    if (urls.count == 0) {
        NSMenuItem *empty = [[NSMenuItem alloc] initWithTitle:@"No Recent Documents" action:nil keyEquivalent:@""];
        empty.enabled = NO;
        [menu addItem:empty];
        return;
    }
    for (NSURL *url in urls) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:url.lastPathComponent
                                                      action:@selector(openRecentDocument:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = url;
        [menu addItem:item];
    }
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *clear = [[NSMenuItem alloc] initWithTitle:@"Clear Menu"
                                                   action:@selector(clearRecentDocuments:)
                                            keyEquivalent:@""];
    clear.target = self;
    [menu addItem:clear];
}

- (void)openRecentDocument:(NSMenuItem *)sender {
    NSURL *url = sender.representedObject;
    if (![url isKindOfClass:[NSURL class]]) return;
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url
                                                                          display:YES
                                                                completionHandler:^(NSDocument *document, BOOL alreadyOpen, NSError *error) {
        if (error) {
            [[NSAlert alertWithError:error] beginSheetModalForWindow:NSApp.keyWindow completionHandler:nil];
        }
    }];
}

- (void)clearRecentDocuments:(id)sender {
    [[NSDocumentController sharedDocumentController] clearRecentDocuments:sender];
}

#pragma mark - Helpers

- (nullable NSMenu *)menuWithTitle:(NSString *)title inMenu:(NSMenu *)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:title]) {
            return item.submenu;
        }
    }
    return nil;
}

@end
