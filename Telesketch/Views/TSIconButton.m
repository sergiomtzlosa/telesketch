#import "TSIconButton.h"

@interface TSIconButton ()
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property (nonatomic, assign) BOOL hovering;
@end

@implementation TSIconButton

+ (instancetype)buttonWithSymbolName:(NSString *)symbolName
                              target:(id)target
                              action:(SEL)action
                         description:(NSString *)description {
    TSIconButton *button = [self buttonWithTitle:@"" target:target action:action];
    button.bordered = NO;
    button.bezelStyle = NSBezelStyleShadowlessSquare;
    button.wantsLayer = YES;
    button.layer.cornerRadius = 7.0;
    button.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.0].CGColor;
    button.contentTintColor = [NSColor colorWithWhite:0.86 alpha:1.0];
    button.focusRingType = NSFocusRingTypeNone;
    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:description];
    image = [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium]];
    button.image = image;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.toolTip = description;
    button.accessibilityLabel = description;
    return button;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverTrackingArea) {
        [self removeTrackingArea:self.hoverTrackingArea];
    }
    self.hoverTrackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                          options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                            owner:self
                                                         userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    self.hovering = YES;
    self.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.08].CGColor;
}

- (void)mouseExited:(NSEvent *)event {
    self.hovering = NO;
    self.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.0].CGColor;
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alphaValue = enabled ? 1.0 : 0.35;
}

@end
