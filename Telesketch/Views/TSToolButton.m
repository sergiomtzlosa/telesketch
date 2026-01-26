#import "TSToolButton.h"

@interface TSToolButton ()
@property (nonatomic, strong, readwrite) NSString *toolIdentifier;
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property (nonatomic, assign) BOOL hovering;
@end

@implementation TSToolButton

+ (instancetype)buttonWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                          symbolName:(NSString *)symbolName
                              target:(id)target
                              action:(SEL)action {
    TSToolButton *button = [self buttonWithTitle:title target:target action:action];
    button.toolIdentifier = identifier;
    button.bordered = NO;
    button.bezelStyle = NSBezelStyleShadowlessSquare;
    button.wantsLayer = YES;
    button.layer.cornerRadius = 10.0;
    button.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.04].CGColor;
    button.imagePosition = NSImageAbove;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.contentTintColor = [NSColor colorWithWhite:0.82 alpha:1.0];
    button.focusRingType = NSFocusRingTypeNone;
    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:title];
    image = [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightMedium]];
    button.image = image;
    button.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    button.toolTip = title;
    [button updateTitleColor];
    return button;
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    [self updateAppearance];
}

- (void)updateTitleColor {
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    NSColor *color = self.selected ? [NSColor colorWithWhite:1.0 alpha:0.95] : [NSColor colorWithWhite:0.68 alpha:1.0];
    NSDictionary *attributes = @{
        NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: paragraph
    };
    self.attributedTitle = [[NSAttributedString alloc] initWithString:self.title attributes:attributes];
}

- (void)updateAppearance {
    if (self.selected) {
        self.layer.backgroundColor = [NSColor colorWithSRGBRed:0.78 green:0.29 blue:0.24 alpha:0.36].CGColor;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [NSColor colorWithSRGBRed:0.90 green:0.40 blue:0.32 alpha:0.55].CGColor;
    } else if (self.hovering) {
        self.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.08].CGColor;
        self.layer.borderWidth = 0.0;
    } else {
        self.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.04].CGColor;
        self.layer.borderWidth = 0.0;
    }
    [self updateTitleColor];
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
    [self updateAppearance];
}

- (void)mouseExited:(NSEvent *)event {
    self.hovering = NO;
    [self updateAppearance];
}

@end
