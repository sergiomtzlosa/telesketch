#import "TSMainMenu.h"

@protocol TSMenuActionDeclarations <NSObject>
- (void)showAbout:(nullable id)sender;
- (void)showSettings:(nullable id)sender;
- (void)exportPNG:(nullable id)sender;
- (void)exportSVG:(nullable id)sender;
- (void)exportPDF:(nullable id)sender;
- (void)traceImage:(nullable id)sender;
- (void)undo:(nullable id)sender;
- (void)redo:(nullable id)sender;
- (void)generateWithAI:(nullable id)sender;
- (void)generateOffline:(nullable id)sender;
- (void)shakeToClear:(nullable id)sender;
- (void)toggleKnobMode:(nullable id)sender;
- (void)toggleToolRail:(nullable id)sender;
- (void)toggleAtelier:(nullable id)sender;
- (void)revealOpenCodeLog:(nullable id)sender;
@end

static NSMenuItem *TSItem(NSString *title, SEL action, NSString *key, NSEventModifierFlags modifiers) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key ?: @""];
    if (key.length > 0) {
        item.keyEquivalentModifierMask = modifiers;
    }
    return item;
}

static NSMenuItem *TSTargetedItem(NSString *title, SEL action, NSString *key,
                                  NSEventModifierFlags modifiers, id target) {
    NSMenuItem *item = TSItem(title, action, key, modifiers);
    item.target = target;
    return item;
}

static NSMenu *TSSubmenu(NSString *title) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:title];
    menu.autoenablesItems = YES;
    return menu;
}

static void TSAddSeparator(NSMenu *menu) {
    [menu addItem:[NSMenuItem separatorItem]];
}

@implementation TSMainMenu

+ (NSMenu *)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
    mainMenu.autoenablesItems = YES;

    NSString *appName = NSProcessInfo.processInfo.processName ?: @"Telesketch";

    // Application menu
    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:appName action:nil keyEquivalent:@""];
    NSMenu *appMenu = TSSubmenu(appName);
    appItem.submenu = appMenu;
    [mainMenu addItem:appItem];

    [appMenu addItem:TSTargetedItem([NSString stringWithFormat:@"About %@", appName],
                                    @selector(showAbout:), @"", 0, nil)];
    TSAddSeparator(appMenu);
    [appMenu addItem:TSItem(@"Settings…", @selector(showSettings:), @",", NSEventModifierFlagCommand)];
    TSAddSeparator(appMenu);

    NSMenu *servicesMenu = TSSubmenu(@"Services");
    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
    servicesItem.submenu = servicesMenu;
    [appMenu addItem:servicesItem];
    NSApp.servicesMenu = servicesMenu;
    TSAddSeparator(appMenu);

    [appMenu addItem:TSTargetedItem([NSString stringWithFormat:@"Hide %@", appName],
                                    @selector(hide:), @"h", NSEventModifierFlagCommand, NSApp)];
    [appMenu addItem:TSTargetedItem(@"Hide Others", @selector(hideOtherApplications:), @"h",
                                    NSEventModifierFlagCommand | NSEventModifierFlagOption, NSApp)];
    [appMenu addItem:TSTargetedItem(@"Show All", @selector(unhideAllApplications:), @"", 0, NSApp)];
    TSAddSeparator(appMenu);
    [appMenu addItem:TSTargetedItem([NSString stringWithFormat:@"Quit %@", appName],
                                    @selector(terminate:), @"q", NSEventModifierFlagCommand, NSApp)];

    // File menu
    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = TSSubmenu(@"File");
    fileItem.submenu = fileMenu;
    [mainMenu addItem:fileItem];

    [fileMenu addItem:TSItem(@"New", @selector(newDocument:), @"n", NSEventModifierFlagCommand)];
    [fileMenu addItem:TSItem(@"Open…", @selector(openDocument:), @"o", NSEventModifierFlagCommand)];

    NSMenu *recentMenu = TSSubmenu(@"Open Recent");
    NSMenuItem *recentItem = [[NSMenuItem alloc] initWithTitle:@"Open Recent" action:nil keyEquivalent:@""];
    recentItem.submenu = recentMenu;
    recentItem.tag = 4242;
    [fileMenu addItem:recentItem];
    TSAddSeparator(fileMenu);
    [fileMenu addItem:TSItem(@"Close", @selector(performClose:), @"w", NSEventModifierFlagCommand)];
    [fileMenu addItem:TSItem(@"Save…", @selector(saveDocument:), @"s", NSEventModifierFlagCommand)];
    [fileMenu addItem:TSItem(@"Save As…", @selector(saveDocumentAs:), @"s",
                             NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    TSAddSeparator(fileMenu);
    [fileMenu addItem:TSItem(@"Export PNG…", @selector(exportPNG:), @"e",
                             NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    [fileMenu addItem:TSItem(@"Export SVG…", @selector(exportSVG:), @"", 0)];
    [fileMenu addItem:TSItem(@"Export PDF…", @selector(exportPDF:), @"", 0)];
    TSAddSeparator(fileMenu);
    [fileMenu addItem:TSItem(@"Trace Image…", @selector(traceImage:), @"i",
                             NSEventModifierFlagCommand | NSEventModifierFlagShift)];

    // Edit menu
    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = TSSubmenu(@"Edit");
    editItem.submenu = editMenu;
    [mainMenu addItem:editItem];

    [editMenu addItem:TSItem(@"Undo", @selector(undo:), @"z", NSEventModifierFlagCommand)];
    [editMenu addItem:TSItem(@"Redo", @selector(redo:), @"z",
                             NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    TSAddSeparator(editMenu);
    [editMenu addItem:TSItem(@"Cut", @selector(cut:), @"x", NSEventModifierFlagCommand)];
    [editMenu addItem:TSItem(@"Copy", @selector(copy:), @"c", NSEventModifierFlagCommand)];
    [editMenu addItem:TSItem(@"Paste", @selector(paste:), @"v", NSEventModifierFlagCommand)];
    [editMenu addItem:TSItem(@"Delete", @selector(delete:), @"", 0)];
    [editMenu addItem:TSItem(@"Select All", @selector(selectAll:), @"a", NSEventModifierFlagCommand)];

    // Sketch menu
    NSMenuItem *sketchItem = [[NSMenuItem alloc] initWithTitle:@"Sketch" action:nil keyEquivalent:@""];
    NSMenu *sketchMenu = TSSubmenu(@"Sketch");
    sketchItem.submenu = sketchMenu;
    [mainMenu addItem:sketchItem];

    [sketchMenu addItem:TSItem(@"Generate with AI", @selector(generateWithAI:), @"\r",
                               NSEventModifierFlagCommand)];
    [sketchMenu addItem:TSItem(@"Generate Offline", @selector(generateOffline:), @"\r",
                               NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    TSAddSeparator(sketchMenu);
    [sketchMenu addItem:TSItem(@"Shake to Clear", @selector(shakeToClear:), @"k",
                               NSEventModifierFlagCommand)];
    [sketchMenu addItem:TSItem(@"Toggle Knob Mode", @selector(toggleKnobMode:), @"k",
                               NSEventModifierFlagCommand | NSEventModifierFlagShift)];

    // View menu
    NSMenuItem *viewItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    NSMenu *viewMenu = TSSubmenu(@"View");
    viewItem.submenu = viewMenu;
    [mainMenu addItem:viewItem];

    NSMenuItem *toolRailItem = TSItem(@"Tool Rail", @selector(toggleToolRail:), @"1",
                                      NSEventModifierFlagCommand | NSEventModifierFlagOption);
    toolRailItem.tag = 4301;
    [viewMenu addItem:toolRailItem];
    NSMenuItem *atelierItem = TSItem(@"AI Atelier", @selector(toggleAtelier:), @"2",
                                     NSEventModifierFlagCommand | NSEventModifierFlagOption);
    atelierItem.tag = 4302;
    [viewMenu addItem:atelierItem];
    TSAddSeparator(viewMenu);
    [viewMenu addItem:TSItem(@"Enter Full Screen", @selector(toggleFullScreen:), @"f",
                             NSEventModifierFlagCommand | NSEventModifierFlagControl)];

    // Window menu
    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    NSMenu *windowMenu = TSSubmenu(@"Window");
    windowItem.submenu = windowMenu;
    [mainMenu addItem:windowItem];

    [windowMenu addItem:TSItem(@"Minimize", @selector(performMiniaturize:), @"m", NSEventModifierFlagCommand)];
    [windowMenu addItem:TSItem(@"Zoom", @selector(performZoom:), @"", 0)];
    TSAddSeparator(windowMenu);
    [windowMenu addItem:TSTargetedItem(@"Bring All to Front", @selector(arrangeInFront:), @"", 0, NSApp)];
    NSApp.windowsMenu = windowMenu;

    // Help menu
    NSMenuItem *helpItem = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    NSMenu *helpMenu = TSSubmenu(@"Help");
    helpItem.submenu = helpMenu;
    [mainMenu addItem:helpItem];
    [helpMenu addItem:TSItem(@"Telesketch Help", @selector(showHelp:), @"?", NSEventModifierFlagCommand)];
    [helpMenu addItem:TSItem(@"Reveal OpenCode Log", @selector(revealOpenCodeLog:), @"", 0)];
    NSApp.helpMenu = helpMenu;

    return mainMenu;
}

@end
