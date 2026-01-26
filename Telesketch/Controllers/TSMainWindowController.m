#import "TSMainWindowController.h"
#import "TSDrawingDocument.h"
#import "TSMainViewController.h"

@implementation TSMainWindowController

- (instancetype)initWithDocument:(TSDrawingDocument *)document {
    NSRect frame = NSMakeRect(0, 0, 1440, 900);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                              NSWindowStyleMaskFullSizeContentView;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = document.drawing.title ?: @"Untitled Sketch";
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.backgroundColor = [NSColor colorWithSRGBRed:0.055 green:0.067 blue:0.059 alpha:1.0];
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.minSize = NSMakeSize(1180, 760);
    window.movableByWindowBackground = YES;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    [window center];
    [window setFrameAutosaveName:@"TelesketchMainWindow"];

    self = [super initWithWindow:window];
    if (self) {
        window.delegate = self;
        TSMainViewController *content = [[TSMainViewController alloc] initWithDocument:document];
        window.contentViewController = content;
        [window setContentSize:NSMakeSize(1440, 900)];
        [window center];
        window.releasedWhenClosed = NO;
    }
    return self;
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
}

- (void)windowWillClose:(NSNotification *)notification {
    TSMainViewController *controller = (TSMainViewController *)self.window.contentViewController;
    if ([controller respondsToSelector:@selector(prepareForWindowClose)]) {
        [controller prepareForWindowClose];
    }
}

@end
