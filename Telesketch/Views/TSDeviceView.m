#import "TSDeviceView.h"
#import "TSGlassOverlayView.h"
#import "NSColor+TSHex.h"

@interface TSDeviceView ()
@property (nonatomic, strong) TSGlassOverlayView *glassOverlay;
@property (nonatomic, assign) NSRect bodyRect;
@property (nonatomic, assign) NSRect bezelRect;
@property (nonatomic, assign) NSRect horizontalKnobFrame;
@property (nonatomic, assign) NSRect verticalKnobFrame;
@property (nonatomic, assign) CGFloat bodyRadius;
@end

@implementation TSDeviceView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = [TSTheme defaultTheme];
        self.wantsLayer = YES;
        self.layer.masksToBounds = NO;
        self.accessibilityRole = NSAccessibilityGroupRole;
        self.accessibilityLabel = @"Telesketch drawing device";

        _canvasView = [[TSCanvasView alloc] initWithFrame:NSZeroRect];
        _canvasView.theme = _theme;
        [self addSubview:_canvasView];

        _glassOverlay = [[TSGlassOverlayView alloc] initWithFrame:NSZeroRect];
        [self addSubview:_glassOverlay];

        _horizontalKnob = [[TSKnobView alloc] initWithFrame:NSZeroRect];
        _horizontalKnob.axis = TSKnobAxisHorizontal;
        _horizontalKnob.caption = @"X";
        _horizontalKnob.delegate = self;
        _horizontalKnob.accessibilityLabel = @"Horizontal stylus knob";
        [self addSubview:_horizontalKnob];

        _verticalKnob = [[TSKnobView alloc] initWithFrame:NSZeroRect];
        _verticalKnob.axis = TSKnobAxisVertical;
        _verticalKnob.caption = @"Y";
        _verticalKnob.delegate = self;
        _verticalKnob.accessibilityLabel = @"Vertical stylus knob";
        [self addSubview:_verticalKnob];

        [self setNeedsLayout:YES];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)setTheme:(TSTheme *)theme {
    _theme = theme ?: [TSTheme defaultTheme];
    self.canvasView.theme = _theme;
    [self setNeedsDisplay:YES];
}

- (void)refreshAppearance {
    [self setNeedsLayout:YES];
    [self setNeedsDisplay:YES];
    [self.canvasView invalidateDrawingCache];
}

- (NSRect)screenRect {
    return self.bezelRect;
}

- (void)layout {
    [super layout];
    NSRect bounds = self.bounds;
    CGFloat inset = MAX(8.0, bounds.size.width * 0.014);
    CGFloat bodyWidth = bounds.size.width - inset * 2.0;
    CGFloat bodyHeight = bodyWidth / 1.25;
    if (bodyHeight > bounds.size.height - inset * 2.0) {
        bodyHeight = bounds.size.height - inset * 2.0;
        bodyWidth = bodyHeight * 1.25;
    }
    self.bodyRect = NSMakeRect(NSMidX(bounds) - bodyWidth * 0.5,
                               NSMidY(bounds) - bodyHeight * 0.5,
                               bodyWidth,
                               bodyHeight);
    self.bodyRadius = MAX(18.0, bodyWidth * 0.032);

    CGFloat screenWidth = bodyWidth * 0.795;
    CGFloat screenHeight = screenWidth * 0.75;
    CGFloat screenX = NSMidX(self.bodyRect) - screenWidth * 0.5;
    CGFloat screenY = NSMinY(self.bodyRect) + bodyHeight * 0.075;
    NSRect screen = NSMakeRect(screenX, screenY, screenWidth, screenHeight);
    self.bezelRect = screen;

    CGFloat bezelInset = MAX(6.0, bodyWidth * 0.010);
    self.canvasView.frame = screen;
    self.glassOverlay.frame = screen;
    self.canvasView.layer.cornerRadius = MAX(5.0, screenWidth * 0.008);
    self.glassOverlay.layer.cornerRadius = MAX(5.0, screenWidth * 0.008);
    self.glassOverlay.layer.masksToBounds = YES;

    CGFloat knobDiameter = MAX(42.0, MIN(78.0, bodyWidth * 0.082));
    CGFloat knobY = NSMaxY(screen) + (bodyHeight * 0.145 - knobDiameter) * 0.38;
    self.horizontalKnobFrame = NSMakeRect(screenX + screenWidth * 0.355 - knobDiameter * 0.5,
                                          knobY,
                                          knobDiameter,
                                          knobDiameter);
    self.verticalKnobFrame = NSMakeRect(screenX + screenWidth * 0.645 - knobDiameter * 0.5,
                                        knobY,
                                        knobDiameter,
                                        knobDiameter);
    self.horizontalKnob.frame = self.horizontalKnobFrame;
    self.verticalKnob.frame = self.verticalKnobFrame;
    (void)bezelInset;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    NSRect body = self.bodyRect;
    if (NSIsEmptyRect(body)) return;

    [NSGraphicsContext saveGraphicsState];
    NSShadow *deviceShadow = [NSShadow new];
    deviceShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.52];
    deviceShadow.shadowBlurRadius = MAX(14.0, body.size.width * 0.035);
    deviceShadow.shadowOffset = NSMakeSize(0, MAX(6.0, body.size.width * 0.012));
    [deviceShadow set];
    NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRoundedRect:body
                                                             xRadius:self.bodyRadius
                                                             yRadius:self.bodyRadius];
    [[NSColor colorWithCalibratedWhite:0.15 alpha:1.0] setFill];
    [bodyPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSColor *light = [NSColor ts_colorWithHex:@"#E7E5DF"];
    NSColor *mid = [NSColor ts_colorWithHex:@"#B9B7B1"];
    NSColor *dark = [NSColor ts_colorWithHex:@"#74736E"];
    NSGradient *aluminium = [[NSGradient alloc] initWithColorsAndLocations:
        light, 0.0,
        [light blendedColorWithFraction:0.20 ofColor:mid], 0.18,
        mid, 0.55,
        dark, 0.90,
        [dark blendedColorWithFraction:0.25 ofColor:[NSColor blackColor]], 1.0, nil];
    [aluminium drawInBezierPath:bodyPath angle:-90.0];

    // Brushed-metal striations, extremely low contrast.
    [NSGraphicsContext saveGraphicsState];
    [bodyPath addClip];
    for (NSInteger i = 0; i < 80; i++) {
        CGFloat y = NSMinY(body) + (CGFloat)i / 80.0 * body.size.height;
        NSBezierPath *line = [NSBezierPath bezierPath];
        [line moveToPoint:NSMakePoint(NSMinX(body), y)];
        CGFloat wave = sin(i * 1.7) * 1.2;
        [line curveToPoint:NSMakePoint(NSMaxX(body), y + wave)
             controlPoint1:NSMakePoint(NSMidX(body) - 80, y + cos(i * 0.9) * 1.7)
             controlPoint2:NSMakePoint(NSMidX(body) + 80, y + sin(i * 0.6) * 1.4)];
        line.lineWidth = 0.6;
        [[NSColor colorWithCalibratedWhite:(i % 2 == 0 ? 1.0 : 0.0) alpha:0.016] setStroke];
        [line stroke];
    }

    // Soft key light from the upper left and edge darkening.
    NSGradient *keyLight = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.16], 0.0,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 0.55, nil];
    [keyLight drawInRect:NSMakeRect(NSMinX(body), NSMinY(body), body.size.width * 0.75, body.size.height * 0.75)
            relativeCenterPosition:NSMakePoint(-0.85, -0.9)];
    NSGradient *edgeDark = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.0]
                                                          endingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.16]];
    [edgeDark drawInRect:body angle:0.0];
    [NSGraphicsContext restoreGraphicsState];

    // Chamfer highlights.
    NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(body, 1.0, 1.0)
                                                        xRadius:self.bodyRadius - 0.5
                                                        yRadius:self.bodyRadius - 0.5];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.42] setStroke];
    rim.lineWidth = 1.2;
    [rim stroke];
    NSBezierPath *outerEdge = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(body, 0.5, 0.5)
                                                              xRadius:self.bodyRadius
                                                              yRadius:self.bodyRadius];
    [[NSColor colorWithCalibratedWhite:0.12 alpha:0.55] setStroke];
    outerEdge.lineWidth = 1.0;
    [outerEdge stroke];

    // Recessed bezel.
    NSRect screen = self.bezelRect;
    CGFloat bezelMargin = MAX(9.0, body.size.width * 0.014);
    NSRect bezel = NSInsetRect(screen, -bezelMargin, -bezelMargin);
    NSBezierPath *bezelPath = [NSBezierPath bezierPathWithRoundedRect:bezel
                                                              xRadius:bezelMargin + 3.0
                                                              yRadius:bezelMargin + 3.0];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *innerShadow = [NSShadow new];
    innerShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.7];
    innerShadow.shadowBlurRadius = bezelMargin;
    innerShadow.shadowOffset = NSMakeSize(0, -2.0);
    [innerShadow set];
    [[NSColor ts_colorWithHex:@"#1B1D1B"] ?: [NSColor darkGrayColor] setFill];
    [bezelPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:0.10 alpha:1.0], 0.0,
        [NSColor colorWithCalibratedWhite:0.20 alpha:1.0], 0.55,
        [NSColor colorWithCalibratedWhite:0.07 alpha:1.0], 1.0, nil];
    [bezelGradient drawInBezierPath:bezelPath angle:-90.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.85] setStroke];
    bezelPath.lineWidth = 1.2;
    [bezelPath stroke];
    NSBezierPath *bezelLip = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bezel, -1.25, -1.25)
                                                             xRadius:bezelMargin + 4.0
                                                             yRadius:bezelMargin + 4.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setStroke];
    bezelLip.lineWidth = 0.8;
    [bezelLip stroke];

    // Etched wordmark and serial plate.
    NSString *wordmark = @"TELESKETCH";
    NSMutableParagraphStyle *center = [NSMutableParagraphStyle new];
    center.alignment = NSTextAlignmentCenter;
    NSDictionary *wordAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:MAX(8.5, body.size.width * 0.0155) weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.22 alpha:0.62],
        NSKernAttributeName: @(MAX(1.5, body.size.width * 0.004)),
        NSParagraphStyleAttributeName: center
    };
    NSRect wordRect = NSMakeRect(NSMinX(body) + body.size.width * 0.20,
                                 NSMinY(body) + body.size.height * 0.028,
                                 body.size.width * 0.60,
                                 body.size.height * 0.05);
    [wordmark drawInRect:wordRect withAttributes:wordAttributes];
    NSDictionary *wordHighlight = @{
        NSFontAttributeName: wordAttributes[NSFontAttributeName],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1.0 alpha:0.32],
        NSKernAttributeName: wordAttributes[NSKernAttributeName],
        NSParagraphStyleAttributeName: center
    };
    [wordmark drawInRect:NSOffsetRect(wordRect, 0, 1.0) withAttributes:wordHighlight];

    NSString *serial = @"Nº 001 · ATELIER EDITION";
    NSDictionary *serialAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:MAX(6.5, body.size.width * 0.0095) weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.24 alpha:0.52],
        NSKernAttributeName: @(0.8),
        NSParagraphStyleAttributeName: center
    };
    NSRect serialRect = NSMakeRect(NSMinX(body) + body.size.width * 0.25,
                                   NSMaxY(body) - body.size.height * 0.055,
                                   body.size.width * 0.50,
                                   12.0);
    [serial drawInRect:serialRect withAttributes:serialAttributes];

    // Corner screws.
    [self drawScrewAtPoint:NSMakePoint(NSMinX(body) + body.size.width * 0.045, NSMinY(body) + body.size.height * 0.055)
                      size:MAX(7.0, body.size.width * 0.014)
                     angle:0.4];
    [self drawScrewAtPoint:NSMakePoint(NSMaxX(body) - body.size.width * 0.045, NSMinY(body) + body.size.height * 0.055)
                      size:MAX(7.0, body.size.width * 0.014)
                     angle:1.1];
    [self drawScrewAtPoint:NSMakePoint(NSMinX(body) + body.size.width * 0.045, NSMaxY(body) - body.size.height * 0.055)
                      size:MAX(7.0, body.size.width * 0.014)
                     angle:2.0];
    [self drawScrewAtPoint:NSMakePoint(NSMaxX(body) - body.size.width * 0.045, NSMaxY(body) - body.size.height * 0.055)
                      size:MAX(7.0, body.size.width * 0.014)
                     angle:0.9];

    (void)bounds;
}

- (void)drawScrewAtPoint:(NSPoint)center size:(CGFloat)size angle:(CGFloat)angle {
    NSRect rect = NSMakeRect(center.x - size * 0.5, center.y - size * 0.5, size, size);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:rect];
    NSGradient *metal = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.72 alpha:1.0]
                                                       endingColor:[NSColor colorWithCalibratedWhite:0.32 alpha:1.0]];
    [metal drawInBezierPath:circle angle:-60.0];
    [[NSColor colorWithCalibratedWhite:0.10 alpha:0.8] setStroke];
    circle.lineWidth = 0.8;
    [circle stroke];

    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:center.x yBy:center.y];
    [transform rotateByRadians:angle];
    [transform concat];
    NSBezierPath *slot = [NSBezierPath bezierPath];
    [slot moveToPoint:NSMakePoint(-size * 0.26, 0)];
    [slot lineToPoint:NSMakePoint(size * 0.26, 0)];
    slot.lineWidth = MAX(0.8, size * 0.16);
    slot.lineCapStyle = NSLineCapStyleRound;
    [[NSColor colorWithCalibratedWhite:0.10 alpha:0.75] setStroke];
    [slot stroke];
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *spec = [NSBezierPath bezierPath];
    [spec appendBezierPathWithArcWithCenter:center radius:size * 0.34
                                 startAngle:1.5 endAngle:2.9 clockwise:NO];
    spec.lineWidth = MAX(0.5, size * 0.12);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.35] setStroke];
    [spec stroke];
}

#pragma mark - Knob delegate

- (void)knobViewDidBeginTurning:(TSKnobView *)knobView {
    [self.canvasView knobDidBeginTurn];
}

- (void)knobView:(TSKnobView *)knobView didTurnByRadians:(CGFloat)radians {
    [self.canvasView knobDidTurnByRadians:radians isHorizontal:(knobView == self.horizontalKnob)];
}

- (void)knobViewDidEndTurning:(TSKnobView *)knobView {
    [self.canvasView knobDidEndTurn];
}

@end
