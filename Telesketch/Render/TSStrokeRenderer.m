#import "TSStrokeRenderer.h"
#import "NSColor+TSHex.h"

@implementation TSStrokeRenderer

+ (NSColor *)colorForStroke:(TSStroke *)stroke theme:(TSTheme *)theme {
    if (stroke.role == TSColorRoleCustom && stroke.colorHex.length > 0) {
        return [NSColor ts_colorWithHex:stroke.colorHex] ?: [NSColor ts_colorWithHex:theme.inkHex];
    }
    return [NSColor ts_colorWithHex:[theme colorHexForRole:stroke.role]] ?: [NSColor ts_colorWithHex:theme.inkHex];
}

+ (NSBezierPath *)pathForVertices:(NSArray<TSVertex *> *)vertices inRect:(NSRect)rect {
    if (vertices.count == 0 || rect.size.width <= 0 || rect.size.height <= 0) {
        return [NSBezierPath bezierPath];
    }
    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:vertices.count];
    for (TSVertex *vertex in vertices) {
        CGFloat x = rect.origin.x + vertex.x * rect.size.width;
        CGFloat y = rect.origin.y + (1.0 - vertex.y) * rect.size.height;
        [points addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
    }

    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    if (points.count == 1) {
        NSPoint p = points[0].pointValue;
        [path moveToPoint:p];
        [path lineToPoint:p];
        return path;
    }
    [path moveToPoint:points[0].pointValue];
    if (points.count == 2) {
        [path lineToPoint:points[1].pointValue];
        return path;
    }
    for (NSUInteger i = 0; i < points.count - 1; i++) {
        NSPoint p0 = points[i == 0 ? 0 : i - 1].pointValue;
        NSPoint p1 = points[i].pointValue;
        NSPoint p2 = points[i + 1].pointValue;
        NSPoint p3 = points[MIN(i + 2, points.count - 1)].pointValue;
        NSPoint cp1 = NSMakePoint(p1.x + (p2.x - p0.x) / 6.0, p1.y + (p2.y - p0.y) / 6.0);
        NSPoint cp2 = NSMakePoint(p2.x - (p3.x - p1.x) / 6.0, p2.y - (p3.y - p1.y) / 6.0);
        [path curveToPoint:p2 controlPoint1:cp1 controlPoint2:cp2];
    }
    return path;
}

+ (void)drawStroke:(TSStroke *)stroke inRect:(NSRect)rect theme:(TSTheme *)theme {
    NSBezierPath *path = [self pathForVertices:stroke.vertices inRect:rect];
    if (path.isEmpty) return;
    CGFloat scale = MAX(0.55, MIN(3.0, rect.size.width / 640.0));
    CGFloat width = MAX(0.9, stroke.width * scale);
    NSColor *color = [self colorForStroke:stroke theme:theme];

    [NSGraphicsContext saveGraphicsState];
    [[color colorWithAlphaComponent:(theme.darkScreen ? 0.16 : 0.10)] setStroke];
    path.lineWidth = width + 2.1 * scale;
    [path stroke];

    [color setStroke];
    path.lineWidth = width;
    [path stroke];
    [NSGraphicsContext restoreGraphicsState];
}

+ (void)drawStrokes:(NSArray<TSStroke *> *)strokes inRect:(NSRect)rect theme:(TSTheme *)theme {
    for (TSStroke *stroke in strokes) {
        [self drawStroke:stroke inRect:rect theme:theme];
    }
}

+ (void)drawDrawing:(TSDrawing *)drawing inRect:(NSRect)rect theme:(TSTheme *)theme {
    [self drawScreenBackgroundInRect:rect theme:theme];
    [self drawStrokes:drawing.strokes inRect:rect theme:theme];
}

+ (void)drawScreenBackgroundInRect:(NSRect)rect theme:(TSTheme *)theme {
    NSColor *top = [NSColor ts_colorWithHex:theme.screenTopHex] ?: [NSColor colorWithWhite:0.85 alpha:1];
    NSColor *bottom = [NSColor ts_colorWithHex:theme.screenBottomHex] ?: [NSColor colorWithWhite:0.7 alpha:1];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:top endingColor:bottom];
    [gradient drawInRect:rect angle:-90.0];

    // Fine grain. Deterministic so it doesn't sparkle between frames.
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRect:rect] addClip];
    uint64_t state = 0x9E3779B97F4A7C15ULL ^ (uint64_t)(rect.size.width * 13 + rect.size.height * 7);
    NSColor *grainColor = theme.darkScreen ? [NSColor colorWithWhite:1 alpha:0.028] : [NSColor colorWithWhite:0 alpha:0.028];
    [grainColor setFill];
    NSInteger count = (NSInteger)MIN(2200, MAX(250, rect.size.width * rect.size.height / 380.0));
    for (NSInteger i = 0; i < count; i++) {
        state = state * 6364136223846793005ULL + 1442695040888963407ULL;
        CGFloat x = rect.origin.x + (CGFloat)((state >> 16) % 10000) / 10000.0 * rect.size.width;
        state = state * 6364136223846793005ULL + 1442695040888963407ULL;
        CGFloat y = rect.origin.y + (CGFloat)((state >> 16) % 10000) / 10000.0 * rect.size.height;
        NSRect dot = NSMakeRect(x, y, 0.75, 0.75);
        NSRectFillUsingOperation(dot, NSCompositingOperationSourceOver);
    }

    // Soft vignette.
    NSGradient *vignette = [[NSGradient alloc] initWithColors:@[
        [NSColor colorWithWhite:0 alpha:0.0],
        [NSColor colorWithWhite:0 alpha:theme.darkScreen ? 0.26 : 0.12]
    ]];
    [vignette drawInRect:rect relativeCenterPosition:NSMakePoint(0.0, 0.05)];
    [NSGraphicsContext restoreGraphicsState];
}

+ (void)drawVectorBackgroundInRect:(NSRect)rect theme:(TSTheme *)theme {
    NSColor *paper = [NSColor ts_colorWithHex:theme.screenTopHex] ?: [NSColor colorWithWhite:0.85 alpha:1];
    [paper setFill];
    NSRectFill(rect);
}

+ (void)drawPlotterTipAtPoint:(NSPoint)point color:(NSColor *)color scale:(CGFloat)scale {
    CGFloat radius = 4.5 * scale;
    [NSGraphicsContext saveGraphicsState];
    [color colorWithAlphaComponent:0.16];
    NSBezierPath *glow = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(point.x - radius * 3.2, point.y - radius * 3.2, radius * 6.4, radius * 6.4)];
    [glow fill];
    [color colorWithAlphaComponent:0.45];
    NSBezierPath *halo = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(point.x - radius * 1.7, point.y - radius * 1.7, radius * 3.4, radius * 3.4)];
    [halo fill];
    [color setFill];
    NSBezierPath *core = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(point.x - radius * 0.5, point.y - radius * 0.5, radius, radius)];
    [core fill];
    [NSGraphicsContext restoreGraphicsState];
}

@end
