#import "TSGlassOverlayView.h"

@implementation TSGlassOverlayView

- (BOOL)isFlipped {
    return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return NO;
}

- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:7.0 yRadius:7.0];
    [clip addClip];

    // Broad diagonal reflection.
    NSGradient *sweep = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 0.0,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.10], 0.30,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.035], 0.52,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 0.72, nil];
    NSRect sweepRect = NSMakeRect(bounds.origin.x - bounds.size.width * 0.35,
                                  bounds.origin.y - bounds.size.height * 0.20,
                                  bounds.size.width * 1.05,
                                  bounds.size.height * 1.45);
    NSBezierPath *band = [NSBezierPath bezierPath];
    [band moveToPoint:NSMakePoint(NSMinX(sweepRect) + bounds.size.width * 0.18, NSMinY(sweepRect))];
    [band lineToPoint:NSMakePoint(NSMinX(sweepRect) + bounds.size.width * 0.52, NSMinY(sweepRect))];
    [band lineToPoint:NSMakePoint(NSMinX(sweepRect) + bounds.size.width * 0.92, NSMaxY(sweepRect))];
    [band lineToPoint:NSMakePoint(NSMinX(sweepRect) + bounds.size.width * 0.58, NSMaxY(sweepRect))];
    [band closePath];
    [sweep drawInBezierPath:band angle:-22.0];

    // Upper-edge glass lip.
    NSGradient *lip = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.18]
                                                   endingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
    [lip drawInRect:NSMakeRect(0, NSMaxY(bounds) - 3.0, bounds.size.width, 3.0) angle:-90.0];

    [NSGraphicsContext restoreGraphicsState];
}

@end
