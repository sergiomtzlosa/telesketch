#import "TSCanvasView.h"
#import "TSStrokeRenderer.h"
#import "NSColor+TSHex.h"

@interface TSCanvasView ()
@property (nonatomic, strong) NSMutableArray<TSVertex *> *currentVertices;
@property (nonatomic, assign) NSPoint stylusPoint;
@property (nonatomic, assign) NSTimeInterval lastPointTime;
@property (nonatomic, assign) NSPoint lastInputPoint;
@property (nonatomic, assign) CGFloat speedFactorSum;
@property (nonatomic, assign) NSUInteger speedSampleCount;
@property (nonatomic, assign) CGFloat pressureSum;
@property (nonatomic, strong) NSMutableSet<NSValue *> *erasedThisDrag;

@property (nonatomic, strong, nullable) NSImage *backgroundCache;
@property (nonatomic, assign) BOOL backgroundDirty;

@property (nonatomic, strong, nullable) TSDrawing *revealDrawing;
@property (nonatomic, assign) NSTimeInterval revealStart;
@property (nonatomic, assign) NSTimeInterval revealDuration;
@property (nonatomic, assign) BOOL revealing;
@property (nonatomic, strong, nullable) NSTimer *revealTimer;
@end

@implementation TSCanvasView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = [TSTheme defaultTheme];
        _tool = TSCanvasToolPen;
        _colorRole = TSColorRoleInk;
        _customColorHex = @"";
        _strokeWidth = 3.0;
        _stylusPoint = NSMakePoint(0.5, 0.5);
        _currentVertices = [NSMutableArray array];
        _erasedThisDrag = [NSMutableSet set];
        _backgroundDirty = YES;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 8.0;
        self.layer.masksToBounds = YES;
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
        self.accessibilityRole = NSAccessibilityGroupRole;
        self.accessibilityLabel = @"Telesketch drawing canvas";
        self.accessibilityHelp = @"Draw with the mouse or use the knobs in knob mode.";
    }
    return self;
}

- (BOOL)isFlipped {
    return NO;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    return YES;
}

- (BOOL)isOpaque {
    return NO;
}

- (void)setDrawing:(TSDrawing *)drawing {
    _drawing = drawing;
    if (!self.revealing) {
        self.stylusPoint = NSMakePoint(0.5, 0.5);
    }
    [self setNeedsDisplay:YES];
}

- (void)setTheme:(TSTheme *)theme {
    _theme = theme ?: [TSTheme defaultTheme];
    self.backgroundDirty = YES;
    [self setNeedsDisplay:YES];
}

- (void)setColorRole:(TSColorRole)colorRole {
    _colorRole = colorRole;
}

- (void)invalidateDrawingCache {
    self.backgroundDirty = YES;
    [self setNeedsDisplay:YES];
}

- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];
    [self invalidateDrawingCache];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    self.backgroundDirty = YES;
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.crosshairCursor];
}

#pragma mark - Drawing

- (NSImage *)cacheImageWithDrawingBlock:(void (^)(void))block {
    NSSize size = self.bounds.size;
    if (size.width < 1 || size.height < 1) return nil;
    CGFloat scale = self.window.backingScaleFactor ?: 2.0;
    NSInteger width = MAX(1, (NSInteger)llround(size.width * scale));
    NSInteger height = MAX(1, (NSInteger)llround(size.height * scale));
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:width
                                                                    pixelsHigh:height
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                 colorSpaceName:NSCalibratedRGBColorSpace
                                                                    bytesPerRow:0
                                                                   bitsPerPixel:0];
    rep.size = size;
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    if (!context) return nil;
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [context setShouldAntialias:YES];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleBy:scale];
    [transform concat];
    block();
    [NSGraphicsContext restoreGraphicsState];
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image addRepresentation:rep];
    return image;
}

- (void)rebuildBackgroundCache {
    __weak typeof(self) weakSelf = self;
    self.backgroundCache = [self cacheImageWithDrawingBlock:^{
        __strong typeof(weakSelf) self = weakSelf;
        [TSStrokeRenderer drawScreenBackgroundInRect:self.bounds theme:self.theme];
    }];
    self.backgroundDirty = NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect rect = self.bounds;

    if (self.backgroundDirty || !self.backgroundCache) {
        [self rebuildBackgroundCache];
    }
    [self.backgroundCache drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:NO hints:nil];

    if (self.revealing) {
        [self drawRevealInRect:rect];
    } else if (self.drawing) {
        // Draw straight into the view. The drawing is small enough that caching
        // is unnecessary, and direct drawing keeps layer-backed coordinates
        // predictable across backing-scale changes.
        [TSStrokeRenderer drawStrokes:self.drawing.strokes inRect:rect theme:self.theme];
    }

    if (self.currentVertices.count > 0) {
        TSStroke *liveStroke = [TSStroke strokeWithVertices:self.currentVertices
                                                      width:self.strokeWidth
                                                       role:self.colorRole
                                                   colorHex:self.customColorHex
                                                       tool:self.knobMode ? @"knob" : @"pen"];
        [TSStrokeRenderer drawStroke:liveStroke inRect:rect theme:self.theme];
    }

    if (self.drawing.isEmpty && !self.revealing && self.currentVertices.count == 0) {
        [self drawEmptyStateInRect:rect];
    }

    if (self.knobMode && self.currentVertices.count == 0) {
        NSPoint tip = [self viewPointForNormalizedPoint:self.stylusPoint];
        NSColor *accent = [NSColor ts_colorWithHex:self.theme.vermilionHex] ?: [NSColor redColor];
        [accent colorWithAlphaComponent:0.5];
        [[accent colorWithAlphaComponent:0.5] setStroke];
        NSBezierPath *cross = [NSBezierPath bezierPath];
        [cross moveToPoint:NSMakePoint(tip.x - 5, tip.y)];
        [cross lineToPoint:NSMakePoint(tip.x + 5, tip.y)];
        [cross moveToPoint:NSMakePoint(tip.x, tip.y - 5)];
        [cross lineToPoint:NSMakePoint(tip.x, tip.y + 5)];
        cross.lineWidth = 1.0;
        [cross stroke];
    }
}

- (void)drawEmptyStateInRect:(NSRect)rect {
    NSString *text = @"Draw something.\nOr ask the atelier.";
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineSpacing = 5.0;
    NSColor *ink = [NSColor ts_colorWithHex:self.theme.inkHex] ?: [NSColor darkGrayColor];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:15 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [ink colorWithAlphaComponent:0.30],
        NSParagraphStyleAttributeName: paragraph,
        NSKernAttributeName: @0.4
    };
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    NSSize size = [string size];
    NSPoint point = NSMakePoint(NSMidX(rect) - size.width / 2.0, NSMidY(rect) - size.height / 2.0 + 12.0);
    [string drawAtPoint:point];
}

#pragma mark - Coordinates and input

- (NSPoint)normalizedPointForEvent:(NSEvent *)event {
    NSPoint viewPoint = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat x = (viewPoint.x - self.bounds.origin.x) / MAX(1.0, self.bounds.size.width);
    CGFloat y = 1.0 - (viewPoint.y - self.bounds.origin.y) / MAX(1.0, self.bounds.size.height);
    return NSMakePoint(MAX(0.0, MIN(1.0, x)), MAX(0.0, MIN(1.0, y)));
}

- (NSPoint)viewPointForNormalizedPoint:(NSPoint)point {
    return NSMakePoint(self.bounds.origin.x + point.x * self.bounds.size.width,
                       self.bounds.origin.y + (1.0 - point.y) * self.bounds.size.height);
}

- (void)mouseDown:(NSEvent *)event {
    [self.window makeFirstResponder:self];
    [self cancelReveal];
    self.erasedThisDrag = [NSMutableSet set];
    self.lastInputPoint = [self convertPoint:event.locationInWindow fromView:nil];
    self.lastPointTime = event.timestamp;
    self.speedFactorSum = 0.0;
    self.speedSampleCount = 0;
    self.pressureSum = 0.0;

    NSPoint normalized = [self normalizedPointForEvent:event];
    if (self.knobMode) {
        self.stylusPoint = normalized;
        [self setNeedsDisplay:YES];
        return;
    }
    if (self.tool == TSCanvasToolEraser) {
        [self eraseAtNormalizedPoint:normalized];
        return;
    }

    [self.currentVertices removeAllObjects];
    [self.currentVertices addObject:[TSVertex vertexWithX:normalized.x y:normalized.y pressure:[self pressureForEvent:event]]];
    self.stylusPoint = normalized;
    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint normalized = [self normalizedPointForEvent:event];
    if (self.knobMode) {
        self.stylusPoint = normalized;
        [self setNeedsDisplay:YES];
        return;
    }
    if (self.tool == TSCanvasToolEraser) {
        [self eraseAtNormalizedPoint:normalized];
        return;
    }

    NSPoint viewPoint = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat distance = hypot(viewPoint.x - self.lastInputPoint.x, viewPoint.y - self.lastInputPoint.y);
    NSTimeInterval dt = MAX(0.001, event.timestamp - self.lastPointTime);
    CGFloat speed = distance / dt;
    CGFloat factor = 1.28 - MIN(0.55, speed / 1800.0);
    self.speedFactorSum += factor;
    self.speedSampleCount++;
    self.pressureSum += [self pressureForEvent:event];

    TSVertex *lastVertex = self.currentVertices.lastObject;
    if (lastVertex) {
        CGFloat dx = normalized.x - lastVertex.x;
        CGFloat dy = normalized.y - lastVertex.y;
        if (hypot(dx, dy) < 0.0015) {
            return;
        }
    }
    [self.currentVertices addObject:[TSVertex vertexWithX:normalized.x y:normalized.y pressure:[self pressureForEvent:event]]];
    self.stylusPoint = normalized;
    self.lastInputPoint = viewPoint;
    self.lastPointTime = event.timestamp;
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (self.knobMode) {
        return;
    }
    if (self.tool == TSCanvasToolEraser) {
        return;
    }
    [self commitCurrentStrokeWithTool:@"pen"];
}

- (CGFloat)pressureForEvent:(NSEvent *)event {
    CGFloat pressure = event.pressure;
    if (pressure <= 0.001) {
        pressure = 0.5;
    }
    return MAX(0.0, MIN(1.0, pressure));
}

- (void)commitCurrentStrokeWithTool:(NSString *)tool {
    if (self.currentVertices.count == 0) return;
    if (self.currentVertices.count == 1) {
        TSVertex *vertex = self.currentVertices.firstObject;
        [self.currentVertices addObject:[TSVertex vertexWithX:vertex.x y:vertex.y pressure:vertex.pressure]];
    }
    CGFloat speedFactor = 1.0;
    if (self.speedSampleCount > 0) {
        speedFactor = self.speedFactorSum / (CGFloat)self.speedSampleCount;
    }
    CGFloat pressureFactor = 1.0;
    if (self.speedSampleCount > 0) {
        CGFloat averagePressure = self.pressureSum / (CGFloat)self.speedSampleCount;
        pressureFactor = 0.80 + averagePressure * 0.42;
    }
    CGFloat width = MAX(0.6, MIN(16.0, self.strokeWidth * speedFactor * pressureFactor));
    TSStroke *stroke = [TSStroke strokeWithVertices:[self.currentVertices copy]
                                              width:width
                                               role:self.colorRole
                                           colorHex:self.customColorHex
                                               tool:tool];
    [self.currentVertices removeAllObjects];
    [self setNeedsDisplay:YES];
    [self.delegate canvasView:self didCommitStroke:stroke];
}

- (void)eraseAtNormalizedPoint:(NSPoint)normalized {
    if (!self.drawing) return;
    NSRect rect = self.bounds;
    NSPoint target = [self viewPointForNormalizedPoint:normalized];
    for (TSStroke *stroke in [self.drawing.strokes reverseObjectEnumerator]) {
        NSValue *key = [NSValue valueWithNonretainedObject:stroke];
        if ([self.erasedThisDrag containsObject:key]) continue;
        CGFloat threshold = MAX(8.0, stroke.width + 6.0);
        if ([self stroke:stroke isNearPoint:target inRect:rect threshold:threshold]) {
            [self.erasedThisDrag addObject:key];
            [self.delegate canvasView:self didEraseStroke:stroke];
            break;
        }
    }
}

- (BOOL)stroke:(TSStroke *)stroke isNearPoint:(NSPoint)point inRect:(NSRect)rect threshold:(CGFloat)threshold {
    NSArray<TSVertex *> *vertices = stroke.vertices;
    if (vertices.count == 1) {
        NSPoint p = [self viewPointForNormalizedPoint:NSMakePoint(vertices[0].x, vertices[0].y)];
        return hypot(p.x - point.x, p.y - point.y) <= threshold;
    }
    for (NSUInteger i = 0; i < vertices.count - 1; i++) {
        NSPoint a = [self viewPointForNormalizedPoint:NSMakePoint(vertices[i].x, vertices[i].y)];
        NSPoint b = [self viewPointForNormalizedPoint:NSMakePoint(vertices[i + 1].x, vertices[i + 1].y)];
        if ([self distanceFromPoint:point toSegmentA:a b:b] <= threshold) {
            return YES;
        }
    }
    return NO;
}

- (CGFloat)distanceFromPoint:(NSPoint)p toSegmentA:(NSPoint)a b:(NSPoint)b {
    CGFloat dx = b.x - a.x;
    CGFloat dy = b.y - a.y;
    if (fabs(dx) < 1e-6 && fabs(dy) < 1e-6) {
        return hypot(p.x - a.x, p.y - a.y);
    }
    CGFloat t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy);
    t = MAX(0.0, MIN(1.0, t));
    CGFloat x = a.x + t * dx;
    CGFloat y = a.y + t * dy;
    return hypot(p.x - x, p.y - y);
}

#pragma mark - Knob mode

- (void)knobDidBeginTurn {
    if (!self.knobMode) return;
    [self cancelReveal];
    if (self.currentVertices.count > 0) return;
    [self.currentVertices addObject:[TSVertex vertexWithX:self.stylusPoint.x y:self.stylusPoint.y pressure:0.65]];
    self.speedFactorSum = 0.0;
    self.speedSampleCount = 1;
    self.pressureSum = 0.65;
    [self setNeedsDisplay:YES];
}

- (void)knobDidTurnByRadians:(CGFloat)radians isHorizontal:(BOOL)horizontal {
    if (!self.knobMode) return;
    if (self.currentVertices.count == 0) {
        [self knobDidBeginTurn];
    }
    CGFloat amount = radians * 0.135;
    if (horizontal) {
        self.stylusPoint = NSMakePoint(self.stylusPoint.x + amount, self.stylusPoint.y);
    } else {
        self.stylusPoint = NSMakePoint(self.stylusPoint.x, self.stylusPoint.y - amount);
    }
    self.stylusPoint = NSMakePoint(MAX(0.02, MIN(0.98, self.stylusPoint.x)),
                                   MAX(0.02, MIN(0.98, self.stylusPoint.y)));
    TSVertex *last = self.currentVertices.lastObject;
    if (last && hypot(self.stylusPoint.x - last.x, self.stylusPoint.y - last.y) < 0.0015) {
        return;
    }
    self.speedFactorSum += 0.9;
    self.speedSampleCount++;
    self.pressureSum += 0.65;
    [self.currentVertices addObject:[TSVertex vertexWithX:self.stylusPoint.x y:self.stylusPoint.y pressure:0.65]];
    [self setNeedsDisplay:YES];
}

- (void)knobDidEndTurn {
    if (!self.knobMode) return;
    if (self.currentVertices.count >= 2) {
        [self commitCurrentStrokeWithTool:@"knob"];
    } else {
        [self.currentVertices removeAllObjects];
        [self setNeedsDisplay:YES];
    }
}

- (void)endKnobStrokeIfNeeded {
    if (self.knobMode && self.currentVertices.count > 0) {
        [self knobDidEndTurn];
    }
}

- (void)moveStylusToNormalizedPoint:(NSPoint)point {
    if (self.currentVertices.count == 0) {
        [self knobDidBeginTurn];
    }
    self.stylusPoint = point;
    TSVertex *last = self.currentVertices.lastObject;
    if (last && hypot(point.x - last.x, point.y - last.y) < 0.0015) return;
    [self.currentVertices addObject:[TSVertex vertexWithX:point.x y:point.y pressure:0.65]];
    [self setNeedsDisplay:YES];
}

#pragma mark - Reveal animation

- (BOOL)isRevealing {
    return self.revealing;
}

- (void)beginRevealWithDrawing:(TSDrawing *)drawing duration:(NSTimeInterval)duration {
    [self cancelReveal];
    self.drawing = drawing;
    self.revealDrawing = drawing;
    self.revealStart = [NSDate timeIntervalSinceReferenceDate];
    BOOL reduceMotion = [NSWorkspace sharedWorkspace].accessibilityDisplayShouldReduceMotion;
    self.revealDuration = (reduceMotion || duration <= 0.01) ? 0.0 : duration;
    self.revealing = YES;
    if (self.revealDuration <= 0.0) {
        self.revealing = NO;
        self.revealDrawing = nil;
        [self setNeedsDisplay:YES];
        return;
    }
    self.revealTimer = [NSTimer timerWithTimeInterval:1.0 / 60.0 target:self selector:@selector(revealTick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.revealTimer forMode:NSRunLoopCommonModes];
    [self setNeedsDisplay:YES];
}

- (void)cancelReveal {
    [self.revealTimer invalidate];
    self.revealTimer = nil;
    if (self.revealing) {
        self.revealing = NO;
        self.revealDrawing = nil;
        [self setNeedsDisplay:YES];
    }
}

- (void)revealTick:(NSTimer *)timer {
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.revealStart;
    if (elapsed >= self.revealDuration) {
        [timer invalidate];
        self.revealTimer = nil;
        self.revealing = NO;
        self.revealDrawing = nil;
        [self setNeedsDisplay:YES];
        return;
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRevealInRect:(NSRect)rect {
    TSDrawing *drawing = self.revealDrawing;
    if (!drawing) return;
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.revealStart;
    CGFloat progress = self.revealDuration > 0 ? (CGFloat)(elapsed / self.revealDuration) : 1.0;
    progress = MAX(0.0, MIN(1.0, progress));

    NSUInteger total = MAX(1, [drawing totalPointCount]);
    NSUInteger target = (NSUInteger)floor(progress * total);
    NSUInteger consumed = 0;
    NSColor *tipColor = [NSColor ts_colorWithHex:self.theme.vermilionHex] ?: [NSColor redColor];
    NSPoint tipPoint = NSMakePoint(NSMidX(rect), NSMidY(rect));

    for (TSStroke *stroke in drawing.strokes) {
        if (consumed >= target) break;
        NSUInteger available = stroke.vertices.count;
        NSUInteger take = MIN(available, MAX(2, target - consumed));
        NSArray<TSVertex *> *vertices = stroke.vertices;
        if (take < available && take >= 2) {
            NSMutableArray *partial = [NSMutableArray arrayWithArray:[vertices subarrayWithRange:NSMakeRange(0, take - 1)]];
            TSVertex *a = vertices[take - 1];
            TSVertex *b = vertices[take];
            [partial addObject:[TSVertex vertexWithX:(a.x + b.x) * 0.5 y:(a.y + b.y) * 0.5 pressure:0.6]];
            vertices = partial;
        } else if (take < available) {
            vertices = [vertices subarrayWithRange:NSMakeRange(0, take)];
        }
        TSStroke *visible = [TSStroke strokeWithVertices:vertices
                                                   width:stroke.width
                                                    role:stroke.role
                                                colorHex:stroke.colorHex
                                                    tool:stroke.tool];
        [TSStrokeRenderer drawStroke:visible inRect:rect theme:self.theme];
        consumed += take;
        if (vertices.count > 0) {
            TSVertex *last = vertices.lastObject;
            tipPoint = [self viewPointForNormalizedPoint:NSMakePoint(last.x, last.y)];
        }
    }

    if (progress < 0.999) {
        CGFloat scale = MAX(0.7, rect.size.width / 640.0);
        [TSStrokeRenderer drawPlotterTipAtPoint:tipPoint color:tipColor scale:scale];
    }
}

#pragma mark - Accessibility

- (NSArray<NSAccessibilityCustomAction *> *)accessibilityCustomActions {
    return @[];
}

@end
