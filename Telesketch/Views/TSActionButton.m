#import "TSActionButton.h"
#import "NSColor+TSHex.h"

@interface TSActionButton ()
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property (nonatomic, assign) BOOL hovering;
@property (nonatomic, strong) NSColor *baseFill;
@end

@implementation TSActionButton

+ (instancetype)buttonWithTitle:(NSString *)title
                     symbolName:(NSString *)symbolName
                         target:(id)target
                         action:(SEL)action {
    TSActionButton *button = [self buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleShadowlessSquare;
    button.bordered = NO;
    button.imagePosition = NSImageLeft;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.imageHugsTitle = YES;
    button.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
    button.wantsLayer = YES;
    button.layer.cornerRadius = 9.0;
    button.fillColor = [NSColor colorWithWhite:1.0 alpha:0.075];
    button.hoverFillColor = [NSColor colorWithWhite:1.0 alpha:0.12];
    button.textColor = [NSColor colorWithWhite:0.93 alpha:1.0];
    button.baseFill = button.fillColor;
    button.focusRingType = NSFocusRingTypeNone;
    if (symbolName.length > 0) {
        NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:title];
        image = [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightSemibold]];
        button.image = image;
        button.contentTintColor = button.textColor;
    }
    [button setTitleText:title];
    button.toolTip = title;
    return button;
}

- (void)setFillColor:(NSColor *)fillColor {
    _fillColor = fillColor;
    self.baseFill = fillColor;
    self.layer.backgroundColor = fillColor.CGColor;
}

- (void)setHoverFillColor:(NSColor *)hoverFillColor {
    _hoverFillColor = hoverFillColor;
    [self updateBackground];
}

- (void)setTextColor:(NSColor *)textColor {
    _textColor = textColor;
    self.contentTintColor = textColor;
    [self setTitleText:self.title];
}

- (void)setTitleText:(NSString *)title {
    if (!title) title = @"";
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    NSDictionary *attributes = @{
        NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: self.enabled ? self.textColor ?: [NSColor whiteColor] : [[NSColor whiteColor] colorWithAlphaComponent:0.35],
        NSParagraphStyleAttributeName: paragraph
    };
    self.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
    self.toolTip = title;
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    self.alphaValue = enabled ? 1.0 : 0.45;
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
    [self updateBackground];
}

- (void)mouseExited:(NSEvent *)event {
    self.hovering = NO;
    [self updateBackground];
}

- (void)mouseDown:(NSEvent *)event {
    self.layer.transform = CATransform3DMakeScale(0.98, 0.98, 1.0);
    [super mouseDown:event];
    self.layer.transform = CATransform3DIdentity;
}

- (void)updateBackground {
    NSColor *color = self.hovering && self.enabled ? (self.hoverFillColor ?: self.fillColor) : self.fillColor;
    self.layer.backgroundColor = color.CGColor;
}

@end
