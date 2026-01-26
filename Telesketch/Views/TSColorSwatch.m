#import "TSColorSwatch.h"
#import "NSColor+TSHex.h"

@implementation TSColorSwatch

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.bezelStyle = NSBezelStyleShadowlessSquare;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.focusRingType = NSFocusRingTypeNone;
        self.swatchDiameter = MIN(frameRect.size.width, frameRect.size.height) - 6.0;
    }
    return self;
}

- (void)setRole:(TSColorRole)role {
    _role = role;
    [self setNeedsDisplay:YES];
}

- (void)setColorHex:(NSString *)colorHex {
    _colorHex = [colorHex copy];
    [self setNeedsDisplay:YES];
}

- (void)setChosen:(BOOL)chosen {
    _chosen = chosen;
    [self setNeedsDisplay:YES];
}

- (void)setSwatchDiameter:(CGFloat)swatchDiameter {
    _swatchDiameter = swatchDiameter;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    CGFloat diameter = self.swatchDiameter > 0 ? MIN(self.swatchDiameter, MIN(bounds.size.width, bounds.size.height) - 4.0)
                                               : MIN(bounds.size.width, bounds.size.height) - 6.0;
    NSRect circleRect = NSMakeRect(NSMidX(bounds) - diameter * 0.5,
                                   NSMidY(bounds) - diameter * 0.5,
                                   diameter,
                                   diameter);

    if (self.isChosen) {
        NSBezierPath *halo = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(circleRect, -4.0, -4.0)];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.92] setStroke];
        halo.lineWidth = 1.5;
        [halo stroke];
    }

    NSColor *fill = nil;
    if (self.colorHex.length > 0) {
        fill = [NSColor ts_colorWithHex:self.colorHex];
    }
    if (!fill) {
        switch (self.role) {
            case TSColorRoleInk: fill = [NSColor colorWithSRGBRed:0.16 green:0.18 blue:0.17 alpha:1.0]; break;
            case TSColorRoleVermilion: fill = [NSColor colorWithSRGBRed:0.78 green:0.29 blue:0.24 alpha:1.0]; break;
            case TSColorRoleTeal: fill = [NSColor colorWithSRGBRed:0.22 green:0.49 blue:0.47 alpha:1.0]; break;
            case TSColorRoleOchre: fill = [NSColor colorWithSRGBRed:0.72 green:0.53 blue:0.23 alpha:1.0]; break;
            case TSColorRoleBlue: fill = [NSColor colorWithSRGBRed:0.24 green:0.36 blue:0.54 alpha:1.0]; break;
            case TSColorRoleCustom: fill = [NSColor colorWithSRGBRed:0.55 green:0.38 blue:0.64 alpha:1.0]; break;
        }
    }

    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[fill blendedColorWithFraction:0.16 ofColor:[NSColor whiteColor]]
                                                           endingColor:[fill blendedColorWithFraction:0.18 ofColor:[NSColor blackColor]]];
    [gradient drawInBezierPath:circle angle:-70.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] setStroke];
    circle.lineWidth = 0.8;
    [circle stroke];

    NSBezierPath *gloss = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(circleRect.origin.x + diameter * 0.18,
                                                                              circleRect.origin.y + diameter * 0.50,
                                                                              diameter * 0.64,
                                                                              diameter * 0.32)];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.20] setFill];
    [gloss fill];

    if (self.role == TSColorRoleCustom) {
        NSImage *eyedropper = [NSImage imageWithSystemSymbolName:@"eyedropper" accessibilityDescription:@"Custom colour"];
        eyedropper = [eyedropper imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:MAX(7.0, diameter * 0.34) weight:NSFontWeightBold]];
        NSRect imageRect = NSMakeRect(NSMidX(bounds) - diameter * 0.24,
                                      NSMidY(bounds) - diameter * 0.24,
                                      diameter * 0.48,
                                      diameter * 0.48);
        [eyedropper drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:0.9 respectFlipped:NO hints:nil];
    }
}

@end
