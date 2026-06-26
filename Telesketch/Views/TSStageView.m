#import "TSStageView.h"
#import "NSColor+TSHex.h"

@implementation TSStageView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _deviceView = [[TSDeviceView alloc] initWithFrame:NSZeroRect];
        [self addSubview:_deviceView];
        self.wantsLayer = YES;
        self.layer.masksToBounds = YES;
        self.accessibilityRole = NSAccessibilityGroupRole;
        self.accessibilityLabel = @"Telesketch studio stage";
        [self setNeedsLayout:YES];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

- (void)layout {
    [super layout];
    [self layoutDevice];
}

- (void)setVisibleStageRect:(NSRect)visibleStageRect {
    _visibleStageRect = visibleStageRect;
    [self layoutDevice];
}

- (void)layoutDevice {
    NSRect bounds = self.bounds;
    NSRect effective = self.visibleStageRect;
    if (NSIsEmptyRect(effective)) {
        effective = bounds;
    }
    CGFloat horizontalPadding = MAX(56.0, effective.size.width * 0.08);
    CGFloat verticalPadding = 110.0;
    CGFloat availableWidth = MAX(280.0, effective.size.width - horizontalPadding * 2.0);
    CGFloat availableHeight = MAX(200.0, effective.size.height - verticalPadding);
    CGFloat width = MIN(900.0, MIN(availableWidth, availableHeight * 1.25));
    CGFloat height = width / 1.25;
    CGFloat x = NSMinX(effective) + (effective.size.width - width) * 0.5;
    CGFloat y = NSMinY(effective) + (effective.size.height - height) * 0.5 - 8.0;
    self.deviceView.frame = NSMakeRect(round(x), round(y), round(width), round(height));
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;

    // Deep studio gradient.
    NSGradient *desk = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor ts_colorWithHex:@"#141816"], 0.0,
        [NSColor ts_colorWithHex:@"#101412"], 0.48,
        [NSColor ts_colorWithHex:@"#0B0E0C"], 1.0, nil];
    [desk drawInRect:bounds angle:-90.0];

    // Smoked-oak grain.
    [NSGraphicsContext saveGraphicsState];
    NSInteger lines = (NSInteger)(bounds.size.height / 6.0);
    for (NSInteger i = 0; i < lines; i++) {
        CGFloat y = NSMinY(bounds) + (CGFloat)i * 6.0 + sin(i * 0.37) * 1.2;
        NSBezierPath *grain = [NSBezierPath bezierPath];
        [grain moveToPoint:NSMakePoint(NSMinX(bounds) - 20, y)];
        [grain curveToPoint:NSMakePoint(NSMaxX(bounds) + 20, y + sin(i * 0.21) * 2.0)
              controlPoint1:NSMakePoint(NSMidX(bounds) - bounds.size.width * 0.26, y + cos(i * 0.43) * 2.8)
              controlPoint2:NSMakePoint(NSMidX(bounds) + bounds.size.width * 0.26, y + sin(i * 0.39) * 2.4)];
        grain.lineWidth = (i % 5 == 0) ? 1.1 : 0.55;
        CGFloat alpha = (i % 5 == 0) ? 0.028 : 0.014;
        [[NSColor colorWithCalibratedWhite:(i % 3 == 0 ? 1.0 : 0.0) alpha:alpha] setStroke];
        [grain stroke];
    }

    // Key light, upper left.
    NSGradient *key = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.055], 0.0,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.015], 0.55,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 1.0, nil];
    [key drawInRect:bounds relativeCenterPosition:NSMakePoint(-0.62, -0.58)];
    [NSGraphicsContext restoreGraphicsState];

    // Leather mat under the device.
    NSRect deviceFrame = self.deviceView.frame;
    NSRect matRect = NSInsetRect(deviceFrame, -MAX(22.0, deviceFrame.size.width * 0.038), -MAX(18.0, deviceFrame.size.width * 0.026));
    matRect.origin.y -= 4.0;
    NSBezierPath *matPath = [NSBezierPath bezierPathWithRoundedRect:matRect xRadius:28.0 yRadius:28.0];

    [NSGraphicsContext saveGraphicsState];
    NSShadow *matShadow = [NSShadow new];
    matShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.55];
    matShadow.shadowBlurRadius = 30.0;
    matShadow.shadowOffset = NSMakeSize(0, 10.0);
    [matShadow set];
    [[NSColor ts_colorWithHex:@"#1C2420"] ?: [NSColor darkGrayColor] setFill];
    [matPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *matGradient = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor ts_colorWithHex:@"#242E28"], 0.0,
        [NSColor ts_colorWithHex:@"#1A221E"], 0.52,
        [NSColor ts_colorWithHex:@"#141A17"], 1.0, nil];
    [matGradient drawInBezierPath:matPath angle:-90.0];

    // Leather grain.
    [NSGraphicsContext saveGraphicsState];
    [matPath addClip];
    for (NSInteger i = 0; i < 220; i++) {
        uint64_t state = (uint64_t)(i + 1) * 6364136223846793005ULL + 1442695040888963407ULL;
        CGFloat x = NSMinX(matRect) + (CGFloat)((state >> 17) % 10000) / 10000.0 * matRect.size.width;
        state = state * 6364136223846793005ULL + 1442695040888963407ULL;
        CGFloat y = NSMinY(matRect) + (CGFloat)((state >> 17) % 10000) / 10000.0 * matRect.size.height;
        CGFloat r = 0.7 + (CGFloat)((state >> 8) % 100) / 100.0 * 1.3;
        NSBezierPath *speck = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y, r, r)];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.018] setFill];
        [speck fill];
    }
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.22] setStroke];
    matPath.lineWidth = 1.0;
    [matPath stroke];
    NSBezierPath *matHighlight = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(matRect, 2, 2) xRadius:26 yRadius:26];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.07] setStroke];
    matHighlight.lineWidth = 1.0;
    [matHighlight stroke];
    [NSGraphicsContext restoreGraphicsState];

    // Caption beneath the device.
    NSMutableParagraphStyle *center = [NSMutableParagraphStyle new];
    center.alignment = NSTextAlignmentCenter;
    NSDictionary *captionAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:9.5 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.58 alpha:0.55],
        NSKernAttributeName: @1.6,
        NSParagraphStyleAttributeName: center
    };
    NSString *caption = @"TÉLÉ-SKETCH · STUDIO Nº 001";
    NSRect captionRect = NSMakeRect(NSMinX(bounds), NSMaxY(matRect) + 12.0, bounds.size.width, 16.0);
    [caption drawInRect:captionRect withAttributes:captionAttributes];

    // Vignette.
    NSGradient *vignette = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.0], 0.0,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.0], 0.55,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.42], 1.0, nil];
    [vignette drawInRect:bounds relativeCenterPosition:NSZeroPoint];
}

@end
