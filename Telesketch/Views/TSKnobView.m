#import "TSKnobView.h"

@implementation TSKnobView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.masksToBounds = NO;
        self.toolTip = @"Drag to move the stylus";
        self.accessibilityRole = NSAccessibilitySliderRole;
        self.accessibilityLabel = @"Telesketch knob";
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)isFlipped {
    return NO;
}

- (void)setAngle:(CGFloat)angle {
    _angle = angle;
    [self setNeedsDisplay:YES];
}

- (void)setAxis:(TSKnobAxis)axis {
    _axis = axis;
    self.accessibilityHelp = axis == TSKnobAxisHorizontal
        ? @"Turn to move the stylus left and right."
        : @"Turn to move the stylus up and down.";
    [self setNeedsDisplay:YES];
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.openHandCursor];
}

- (void)mouseDown:(NSEvent *)event {
    [[NSCursor closedHandCursor] push];
    if ([self.delegate respondsToSelector:@selector(knobViewDidBeginTurning:)]) {
        [self.delegate knobViewDidBeginTurning:self];
    }
    [self.window makeFirstResponder:self];
}

- (void)mouseDragged:(NSEvent *)event {
    CGFloat delta = (self.axis == TSKnobAxisHorizontal) ? event.deltaX : -event.deltaY;
    CGFloat radians = delta / 34.0;
    if (fabs(radians) < 0.0001) return;
    self.angle += radians;
    if (self.angle > M_PI * 4.0) self.angle -= M_PI * 4.0;
    if (self.angle < -M_PI * 4.0) self.angle += M_PI * 4.0;
    if ([self.delegate respondsToSelector:@selector(knobView:didTurnByRadians:)]) {
        [self.delegate knobView:self didTurnByRadians:radians];
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    [NSCursor pop];
    if ([self.delegate respondsToSelector:@selector(knobViewDidEndTurning:)]) {
        [self.delegate knobViewDidEndTurning:self];
    }
}

- (void)keyDown:(NSEvent *)event {
    NSString *characters = event.charactersIgnoringModifiers;
    CGFloat step = 0.10;
    BOOL handled = YES;
    if ([characters isEqualToString:@"\uF703"] || [characters isEqualToString:@"w"]) {
        self.angle += step;
    } else if ([characters isEqualToString:@"\uF701"] || [characters isEqualToString:@"s"]) {
        self.angle -= step;
    } else if ([characters isEqualToString:@"\uF702"] || [characters isEqualToString:@"a"]) {
        self.angle -= step;
    } else if ([characters isEqualToString:@"\uF700"] || [characters isEqualToString:@"d"]) {
        self.angle += step;
    } else {
        handled = NO;
    }
    if (handled) {
        if ([self.delegate respondsToSelector:@selector(knobViewDidBeginTurning:)]) {
            [self.delegate knobViewDidBeginTurning:self];
        }
        if ([self.delegate respondsToSelector:@selector(knobView:didTurnByRadians:)]) {
            [self.delegate knobView:self didTurnByRadians:step];
        }
        if ([self.delegate respondsToSelector:@selector(knobViewDidEndTurning:)]) {
            [self.delegate knobViewDidEndTurning:self];
        }
    } else {
        [super keyDown:event];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = NSInsetRect(self.bounds, 3.0, 3.0);
    CGFloat radius = MIN(bounds.size.width, bounds.size.height) * 0.5;
    if (radius < 2.0) return;
    NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));

    // Cast shadow on the aluminium plate.
    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.55];
    shadow.shadowBlurRadius = radius * 0.42;
    shadow.shadowOffset = NSMakeSize(0, -radius * 0.12);
    [shadow set];
    NSBezierPath *shadowPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - radius * 0.94,
                                                                                  center.y - radius * 0.94,
                                                                                  radius * 1.88,
                                                                                  radius * 1.88)];
    [[NSColor colorWithCalibratedWhite:0.08 alpha:0.8] setFill];
    [shadowPath fill];
    [NSGraphicsContext restoreGraphicsState];

    // Dark anodised seat.
    NSBezierPath *seat = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - radius,
                                                                            center.y - radius,
                                                                            radius * 2.0,
                                                                            radius * 2.0)];
    NSGradient *seatGradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.16 green:0.12 blue:0.10 alpha:1.0]
                                                            endingColor:[NSColor colorWithSRGBRed:0.34 green:0.20 blue:0.16 alpha:1.0]];
    [seatGradient drawInBezierPath:seat angle:-70.0];

    CGFloat outerRadius = radius * 0.905;
    NSRect outerRect = NSMakeRect(center.x - outerRadius, center.y - outerRadius, outerRadius * 2.0, outerRadius * 2.0);
    NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:outerRect];
    NSGradient *body = [[NSGradient alloc] initWithColors:@[
        [NSColor colorWithSRGBRed:0.87 green:0.43 blue:0.34 alpha:1.0],
        [NSColor colorWithSRGBRed:0.72 green:0.25 blue:0.20 alpha:1.0],
        [NSColor colorWithSRGBRed:0.48 green:0.13 blue:0.11 alpha:1.0],
        [NSColor colorWithSRGBRed:0.70 green:0.24 blue:0.19 alpha:1.0]
    ]];
    [body drawInBezierPath:outer angle:-65.0];

    // Ridges. They rotate with the knob, like a real turned control.
    NSUInteger ridges = 32;
    for (NSUInteger i = 0; i < ridges; i++) {
        CGFloat angle = self.angle + (CGFloat)i / (CGFloat)ridges * M_PI * 2.0;
        CGFloat inner = outerRadius * 0.80;
        CGFloat outerEdge = outerRadius * 0.985;
        NSBezierPath *ridge = [NSBezierPath bezierPath];
        [ridge moveToPoint:NSMakePoint(center.x + cos(angle) * inner, center.y + sin(angle) * inner)];
        [ridge lineToPoint:NSMakePoint(center.x + cos(angle) * outerEdge, center.y + sin(angle) * outerEdge)];
        ridge.lineWidth = MAX(0.65, radius * 0.037);
        ridge.lineCapStyle = NSLineCapStyleRound;
        if (i % 2 == 0) {
            [[NSColor colorWithSRGBRed:0.35 green:0.08 blue:0.07 alpha:0.65] setStroke];
        } else {
            [[NSColor colorWithSRGBRed:0.95 green:0.58 blue:0.46 alpha:0.34] setStroke];
        }
        [ridge stroke];
    }

    // Beveled rim.
    [[NSColor colorWithSRGBRed:0.30 green:0.08 blue:0.06 alpha:0.85] setStroke];
    outer.lineWidth = MAX(0.8, radius * 0.045);
    [outer stroke];
    NSBezierPath *highlightArc = [NSBezierPath bezierPath];
    [highlightArc appendBezierPathWithArcWithCenter:center
                                             radius:outerRadius - radius * 0.075
                                         startAngle:40.0
                                           endAngle:142.0];
    highlightArc.lineWidth = MAX(0.8, radius * 0.055);
    highlightArc.lineCapStyle = NSLineCapStyleRound;
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.30] setStroke];
    [highlightArc stroke];

    // Centre cap.
    CGFloat capRadius = radius * 0.50;
    NSRect capRect = NSMakeRect(center.x - capRadius, center.y - capRadius, capRadius * 2.0, capRadius * 2.0);
    NSBezierPath *cap = [NSBezierPath bezierPathWithOvalInRect:capRect];
    NSGradient *capGradient = [[NSGradient alloc] initWithColors:@[
        [NSColor colorWithSRGBRed:0.80 green:0.36 blue:0.28 alpha:1.0],
        [NSColor colorWithSRGBRed:0.44 green:0.12 blue:0.10 alpha:1.0],
        [NSColor colorWithSRGBRed:0.62 green:0.20 blue:0.16 alpha:1.0]
    ]];
    [capGradient drawInBezierPath:cap angle:-80.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.55] setStroke];
    cap.lineWidth = MAX(0.6, radius * 0.035);
    [cap stroke];

    // Specular sweep on the cap.
    NSBezierPath *specular = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - capRadius * 0.55,
                                                                                 center.y + capRadius * 0.10,
                                                                                 capRadius * 0.88,
                                                                                 capRadius * 0.55)];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.20] setFill];
    [specular fill];

    // Tiny machined index mark.
    CGFloat markAngle = self.angle - M_PI_2;
    NSBezierPath *index = [NSBezierPath bezierPath];
    [index moveToPoint:NSMakePoint(center.x + cos(markAngle) * radius * 0.58,
                                   center.y + sin(markAngle) * radius * 0.58)];
    [index lineToPoint:NSMakePoint(center.x + cos(markAngle) * radius * 0.74,
                                   center.y + sin(markAngle) * radius * 0.74)];
    index.lineWidth = MAX(1.0, radius * 0.055);
    index.lineCapStyle = NSLineCapStyleRound;
    [[NSColor colorWithCalibratedWhite:0.05 alpha:0.55] setStroke];
    [index stroke];

    if (self.caption.length > 0 && radius > 22.0) {
        NSDictionary *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:MAX(7.0, radius * 0.19) weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.93 alpha:0.55],
            NSKernAttributeName: @(radius * 0.04)
        };
        NSSize size = [self.caption sizeWithAttributes:attributes];
        [self.caption drawAtPoint:NSMakePoint(center.x - size.width * 0.5, center.y - size.height - radius * 0.72)
                    withAttributes:attributes];
    }
}

@end
