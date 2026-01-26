#import "TSIconRenderer.h"

static NSColor *TSIconColor(uint32_t rgb, CGFloat alpha) {
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:alpha];
}

static uint64_t TSIconRandom(uint64_t *state) {
    *state = *state * 6364136223846793005ULL + 1442695040888963407ULL;
    return *state;
}

static void TSStroke(NSBezierPath *path, NSColor *color, CGFloat width) {
    [color setStroke];
    path.lineWidth = width;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [path stroke];
}

static void TSFill(NSBezierPath *path, NSColor *color) {
    [color setFill];
    [path fill];
}

static NSBezierPath *TSCurvedPath(NSPoint start, NSPoint c1, NSPoint c2, NSPoint end) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:start];
    [path curveToPoint:end controlPoint1:c1 controlPoint2:c2];
    return path;
}

/// Draws text upright while the icon's design space is vertically flipped.
static void TSDrawText(NSString *text, NSRect rect, NSDictionary *attributes) {
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:rect.origin.x yBy:NSMaxY(rect)];
    [transform scaleXBy:1 yBy:-1];
    [transform concat];
    [text drawInRect:NSMakeRect(0, 0, rect.size.width, rect.size.height) withAttributes:attributes];
    [NSGraphicsContext restoreGraphicsState];
}

@implementation TSIconRenderer

+ (nullable NSData *)PNGDataWithSize:(CGFloat)size {
    NSInteger pixels = MAX(16, (NSInteger)llround(size));
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                       pixelsWide:pixels
                                                                       pixelsHigh:pixels
                                                                    bitsPerSample:8
                                                                  samplesPerPixel:4
                                                                         hasAlpha:YES
                                                                         isPlanar:NO
                                                                   colorSpaceName:NSCalibratedRGBColorSpace
                                                                      bytesPerRow:0
                                                                     bitsPerPixel:0];
    if (!bitmap) return nil;
    bitmap.size = NSMakeSize(pixels, pixels);

    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    if (!context) return nil;
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    context.shouldAntialias = YES;
    context.imageInterpolation = NSImageInterpolationHigh;

    CGFloat scale = (CGFloat)pixels / 1024.0;
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleBy:scale];
    [transform concat];

    // Work in a top-left-origin 1024 × 1024 design space.
    NSAffineTransform *flip = [NSAffineTransform transform];
    [flip translateXBy:0 yBy:1024];
    [flip scaleXBy:1 yBy:-1];
    [flip concat];

    [self drawIcon];

    [NSGraphicsContext restoreGraphicsState];
    return [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

+ (void)drawIcon {
    NSRect canvas = NSMakeRect(0, 0, 1024, 1024);
    NSRect plate = NSInsetRect(canvas, 40, 40);
    CGFloat plateRadius = 214.0;

    // Soft contact shadow beneath the squircle.
    NSBezierPath *platePath = [NSBezierPath bezierPathWithRoundedRect:plate
                                                              xRadius:plateRadius
                                                              yRadius:plateRadius];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *plateShadow = [NSShadow new];
    plateShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.62];
    plateShadow.shadowBlurRadius = 34.0;
    plateShadow.shadowOffset = NSMakeSize(0, 18);
    [plateShadow set];
    [TSIconColor(0x0A0F0C, 1.0) setFill];
    [platePath fill];
    [NSGraphicsContext restoreGraphicsState];

    // Deep green/charcoal anodised plate.
    NSGradient *plateGradient = [[NSGradient alloc] initWithColorsAndLocations:
        TSIconColor(0x2A3A32, 1.0), 0.0,
        TSIconColor(0x18241E, 1.0), 0.48,
        TSIconColor(0x080C0A, 1.0), 1.0, nil];
    [plateGradient drawInBezierPath:platePath angle:-78.0];

    [NSGraphicsContext saveGraphicsState];
    [platePath addClip];

    // Long, quiet diagonal sheen.
    NSGradient *sheen = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.11], 0.0,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.035], 0.32,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 0.62, nil];
    [sheen drawInRect:plate relativeCenterPosition:NSMakePoint(-0.60, -0.72)];

    // Fine anodised grain.
    uint64_t seed = 0x5EED1234ULL;
    for (NSInteger i = 0; i < 520; i++) {
        CGFloat x = NSMinX(plate) + (CGFloat)(TSIconRandom(&seed) >> 18) / 16384.0 * plate.size.width;
        CGFloat y = NSMinY(plate) + (CGFloat)(TSIconRandom(&seed) >> 18) / 16384.0 * plate.size.height;
        CGFloat length = 2.0 + (CGFloat)(TSIconRandom(&seed) >> 20) / 4096.0 * 9.0;
        NSBezierPath *fleck = [NSBezierPath bezierPath];
        [fleck moveToPoint:NSMakePoint(x, y)];
        [fleck lineToPoint:NSMakePoint(x + length, y + 0.7)];
        fleck.lineWidth = 0.8;
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.018] setStroke];
        [fleck stroke];
    }

    // Vignette.
    NSGradient *vignette = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.0], 0.0,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.0], 0.55,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.46], 1.0, nil];
    [vignette drawInRect:plate relativeCenterPosition:NSZeroPoint];
    [NSGraphicsContext restoreGraphicsState];

    // Rim light and outer edge.
    NSBezierPath *rim = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(plate, 1.5, 1.5)
                                                       xRadius:plateRadius - 1.0
                                                       yRadius:plateRadius - 1.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setStroke];
    rim.lineWidth = 2.4;
    [rim stroke];

    // Leather mat.
    NSRect matRect = NSMakeRect(104, 176, 816, 674);
    NSBezierPath *matPath = [NSBezierPath bezierPathWithRoundedRect:matRect xRadius:96 yRadius:96];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *matShadow = [NSShadow new];
    matShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.45];
    matShadow.shadowBlurRadius = 26.0;
    matShadow.shadowOffset = NSMakeSize(0, 14);
    [matShadow set];
    [TSIconColor(0x17211B, 1.0) setFill];
    [matPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *matGradient = [[NSGradient alloc] initWithStartingColor:TSIconColor(0x26332C, 1.0)
                                                           endingColor:TSIconColor(0x131B17, 1.0)];
    [matGradient drawInBezierPath:matPath angle:-82.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.06] setStroke];
    matPath.lineWidth = 1.2;
    [matPath stroke];

    // Device body.
    NSRect body = NSMakeRect(152, 226, 720, 592);
    NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRoundedRect:body xRadius:52 yRadius:52];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *deviceShadow = [NSShadow new];
    deviceShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.58];
    deviceShadow.shadowBlurRadius = 32.0;
    deviceShadow.shadowOffset = NSMakeSize(0, 20);
    [deviceShadow set];
    [TSIconColor(0x24231F, 1.0) setFill];
    [bodyPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *aluminium = [[NSGradient alloc] initWithColorsAndLocations:
        TSIconColor(0xF3F1EB, 1.0), 0.0,
        TSIconColor(0xDDDBD4, 1.0), 0.16,
        TSIconColor(0xBDBBB5, 1.0), 0.55,
        TSIconColor(0x908F8A, 1.0), 0.88,
        TSIconColor(0x777671, 1.0), 1.0, nil];
    [aluminium drawInBezierPath:bodyPath angle:-90.0];

    [NSGraphicsContext saveGraphicsState];
    [bodyPath addClip];
    for (NSInteger i = 0; i < 74; i++) {
        CGFloat y = NSMinY(body) + (CGFloat)i / 74.0 * body.size.height;
        NSBezierPath *line = [NSBezierPath bezierPath];
        [line moveToPoint:NSMakePoint(NSMinX(body), y)];
        [line curveToPoint:NSMakePoint(NSMaxX(body), y + sin(i * 0.7) * 1.4)
             controlPoint1:NSMakePoint(NSMidX(body) - 90, y + cos(i * 1.3) * 2.1)
             controlPoint2:NSMakePoint(NSMidX(body) + 90, y + sin(i * 0.45) * 1.7)];
        line.lineWidth = 0.8;
        [[NSColor colorWithCalibratedWhite:(i % 2 == 0 ? 1.0 : 0.0) alpha:0.02] setStroke];
        [line stroke];
    }
    NSGradient *bodyLight = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.14], 0.0,
        [NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 0.5, nil];
    [bodyLight drawInRect:NSMakeRect(NSMinX(body), NSMinY(body), body.size.width * 0.78, body.size.height * 0.7)
        relativeCenterPosition:NSMakePoint(-0.8, -0.9)];
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *bodyHighlight = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(body, 2, 2)
                                                                 xRadius:50 yRadius:50];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.46] setStroke];
    bodyHighlight.lineWidth = 2.2;
    [bodyHighlight stroke];
    NSBezierPath *bodyEdge = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(body, 0.75, 0.75)
                                                            xRadius:52 yRadius:52];
    [[NSColor colorWithCalibratedWhite:0.08 alpha:0.48] setStroke];
    bodyEdge.lineWidth = 1.5;
    [bodyEdge stroke];

    // Corner screws.
    [self drawScrewAtPoint:NSMakePoint(184, 258) radius:12 angle:0.45];
    [self drawScrewAtPoint:NSMakePoint(840, 258) radius:12 angle:1.25];
    [self drawScrewAtPoint:NSMakePoint(184, 786) radius:12 angle:0.9];
    [self drawScrewAtPoint:NSMakePoint(840, 786) radius:12 angle:2.1];

    // Bezel.
    NSRect screen = NSMakeRect(232, 292, 560, 420);
    NSRect bezel = NSInsetRect(screen, -20, -20);
    NSBezierPath *bezelPath = [NSBezierPath bezierPathWithRoundedRect:bezel xRadius:30 yRadius:30];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *bezelShadow = [NSShadow new];
    bezelShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.65];
    bezelShadow.shadowBlurRadius = 16.0;
    bezelShadow.shadowOffset = NSMakeSize(0, -3);
    [bezelShadow set];
    [TSIconColor(0x111310, 1.0) setFill];
    [bezelPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *bezelGradient = [[NSGradient alloc] initWithColorsAndLocations:
        TSIconColor(0x0A0C0A, 1.0), 0.0,
        TSIconColor(0x262924, 1.0), 0.45,
        TSIconColor(0x0C0E0C, 1.0), 1.0, nil];
    [bezelGradient drawInBezierPath:bezelPath angle:-90.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.8] setStroke];
    bezelPath.lineWidth = 2.0;
    [bezelPath stroke];
    NSBezierPath *bezelLip = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bezel, -1.5, -1.5)
                                                            xRadius:32 yRadius:32];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setStroke];
    bezelLip.lineWidth = 1.4;
    [bezelLip stroke];

    // Cream screen.
    NSBezierPath *screenPath = [NSBezierPath bezierPathWithRoundedRect:screen xRadius:13 yRadius:13];
    NSGradient *screenGradient = [[NSGradient alloc] initWithColorsAndLocations:
        TSIconColor(0xF3EEE2, 1.0), 0.0,
        TSIconColor(0xE4DED0, 1.0), 0.55,
        TSIconColor(0xD2CBBA, 1.0), 1.0, nil];
    [screenGradient drawInBezierPath:screenPath angle:-88.0];

    [NSGraphicsContext saveGraphicsState];
    [screenPath addClip];

    // Paper grain and vignette on the screen.
    uint64_t screenSeed = 0xCA75E123ULL;
    for (NSInteger i = 0; i < 260; i++) {
        CGFloat x = NSMinX(screen) + (CGFloat)(TSIconRandom(&screenSeed) >> 18) / 16384.0 * screen.size.width;
        CGFloat y = NSMinY(screen) + (CGFloat)(TSIconRandom(&screenSeed) >> 18) / 16384.0 * screen.size.height;
        CGFloat r = 0.6 + (CGFloat)(TSIconRandom(&screenSeed) >> 24) / 256.0 * 1.3;
        [TSIconColor(0x2B2E2C, 0.026) setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y, r, r)] fill];
    }
    NSGradient *screenShade = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.10], 0.0,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.0], 0.16,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.0], 0.82,
        [NSColor colorWithCalibratedWhite:0.0 alpha:0.12], 1.0, nil];
    [screenShade drawInRect:screen angle:-90.0];

    // Diagonal glass sweep.
    NSBezierPath *sweep = [NSBezierPath bezierPath];
    [sweep moveToPoint:NSMakePoint(170, 780)];
    [sweep lineToPoint:NSMakePoint(430, 780)];
    [sweep lineToPoint:NSMakePoint(700, 250)];
    [sweep lineToPoint:NSMakePoint(520, 250)];
    [sweep closePath];
    TSFill(sweep, [NSColor colorWithCalibratedWhite:1.0 alpha:0.075]);
    NSBezierPath *sweep2 = [NSBezierPath bezierPath];
    [sweep2 moveToPoint:NSMakePoint(604, 780)];
    [sweep2 lineToPoint:NSMakePoint(676, 780)];
    [sweep2 lineToPoint:NSMakePoint(850, 400)];
    [sweep2 lineToPoint:NSMakePoint(802, 400)];
    [sweep2 closePath];
    TSFill(sweep2, [NSColor colorWithCalibratedWhite:1.0 alpha:0.05]);

    [self drawCatInScreen:screen];
    [NSGraphicsContext restoreGraphicsState];

    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.55] setStroke];
    screenPath.lineWidth = 1.5;
    [screenPath stroke];

    // Wordmark and serial between the knobs.
    NSMutableParagraphStyle *centered = [NSMutableParagraphStyle new];
    centered.alignment = NSTextAlignmentCenter;
    NSDictionary *wordmarkAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:23.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.17 alpha:0.56],
        NSKernAttributeName: @5.4,
        NSParagraphStyleAttributeName: centered
    };
    TSDrawText(@"TELESKETCH", NSMakeRect(300, 746, 424, 30), wordmarkAttributes);
    NSDictionary *wordmarkHighlight = @{
        NSFontAttributeName: wordmarkAttributes[NSFontAttributeName],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1.0 alpha:0.34],
        NSKernAttributeName: wordmarkAttributes[NSKernAttributeName],
        NSParagraphStyleAttributeName: centered
    };
    TSDrawText(@"TELESKETCH", NSMakeRect(300, 747.5, 424, 30), wordmarkHighlight);

    NSDictionary *serialAttributes = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.18 alpha:0.44],
        NSKernAttributeName: @1.8,
        NSParagraphStyleAttributeName: centered
    };
    TSDrawText(@"Nº 001 · AI ATELIER", NSMakeRect(300, 774, 424, 18), serialAttributes);

    // Knobs.
    [self drawKnobAtCenter:NSMakePoint(286, 772) radius:40];
    [self drawKnobAtCenter:NSMakePoint(738, 772) radius:40];

    // Tiny AI sparkle on the aluminium near the upper-right of the screen.
    [self drawSparkleAtPoint:NSMakePoint(822, 318) size:19 color:TSIconColor(0xC99E52, 0.92)];
    [self drawSparkleAtPoint:NSMakePoint(846, 356) size:9 color:TSIconColor(0xE8D9B8, 0.85)];
}

+ (void)drawCatInScreen:(NSRect)screen {
    NSColor *ink = TSIconColor(0x2B2E2C, 0.96);
    NSColor *softInk = TSIconColor(0x2B2E2C, 0.42);

    // Head.
    NSBezierPath *head = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(404, 356, 216, 190)];
    TSStroke(head, ink, 10.0);

    // Ears.
    NSBezierPath *leftEar = [NSBezierPath bezierPath];
    [leftEar moveToPoint:NSMakePoint(418, 410)];
    [leftEar lineToPoint:NSMakePoint(430, 334)];
    [leftEar lineToPoint:NSMakePoint(492, 376)];
    TSStroke(leftEar, ink, 10.0);

    NSBezierPath *rightEar = [NSBezierPath bezierPath];
    [rightEar moveToPoint:NSMakePoint(606, 410)];
    [rightEar lineToPoint:NSMakePoint(594, 334)];
    [rightEar lineToPoint:NSMakePoint(532, 376)];
    TSStroke(rightEar, ink, 10.0);

    // Eyes, nose and mouth.
    [ink setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(458, 444, 17, 21)] fill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(549, 444, 17, 21)] fill];
    NSBezierPath *nose = [NSBezierPath bezierPath];
    [nose moveToPoint:NSMakePoint(503, 492)];
    [nose lineToPoint:NSMakePoint(521, 492)];
    [nose lineToPoint:NSMakePoint(512, 503)];
    [nose closePath];
    TSFill(nose, ink);
    NSBezierPath *mouthLeft = [NSBezierPath bezierPath];
    [mouthLeft moveToPoint:NSMakePoint(512, 503)];
    [mouthLeft curveToPoint:NSMakePoint(490, 512) controlPoint1:NSMakePoint(509, 514) controlPoint2:NSMakePoint(498, 516)];
    TSStroke(mouthLeft, ink, 5.5);
    NSBezierPath *mouthRight = [NSBezierPath bezierPath];
    [mouthRight moveToPoint:NSMakePoint(512, 503)];
    [mouthRight curveToPoint:NSMakePoint(534, 512) controlPoint1:NSMakePoint(515, 514) controlPoint2:NSMakePoint(526, 516)];
    TSStroke(mouthRight, ink, 5.5);

    // Whiskers.
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat dy = 30.0 * i;
        NSBezierPath *leftWhisker = [NSBezierPath bezierPath];
        [leftWhisker moveToPoint:NSMakePoint(432, 486 + dy * 0.35)];
        [leftWhisker curveToPoint:NSMakePoint(334, 474 + dy)
                   controlPoint1:NSMakePoint(390, 484 + dy * 0.4)
                   controlPoint2:NSMakePoint(360, 478 + dy * 0.7)];
        TSStroke(leftWhisker, softInk, 4.0);
        NSBezierPath *rightWhisker = [NSBezierPath bezierPath];
        [rightWhisker moveToPoint:NSMakePoint(592, 486 + dy * 0.35)];
        [rightWhisker curveToPoint:NSMakePoint(690, 474 + dy)
                    controlPoint1:NSMakePoint(634, 484 + dy * 0.4)
                    controlPoint2:NSMakePoint(664, 478 + dy * 0.7)];
        TSStroke(rightWhisker, softInk, 4.0);
    }

    // Body.
    NSBezierPath *leftBody = TSCurvedPath(NSMakePoint(432, 512),
                                          NSMakePoint(402, 580),
                                          NSMakePoint(408, 620),
                                          NSMakePoint(424, 652));
    TSStroke(leftBody, ink, 9.0);
    NSBezierPath *rightBody = TSCurvedPath(NSMakePoint(596, 512),
                                           NSMakePoint(626, 580),
                                           NSMakePoint(620, 620),
                                           NSMakePoint(604, 652));
    TSStroke(rightBody, ink, 9.0);
    NSBezierPath *belly = TSCurvedPath(NSMakePoint(424, 652),
                                       NSMakePoint(454, 674),
                                       NSMakePoint(570, 674),
                                       NSMakePoint(604, 652));
    TSStroke(belly, ink, 9.0);

    // Paws.
    NSBezierPath *leftPaw = TSCurvedPath(NSMakePoint(452, 660),
                                         NSMakePoint(454, 674),
                                         NSMakePoint(470, 676),
                                         NSMakePoint(476, 662));
    TSStroke(leftPaw, ink, 5.0);
    NSBezierPath *rightPaw = TSCurvedPath(NSMakePoint(552, 660),
                                          NSMakePoint(550, 674),
                                          NSMakePoint(534, 676),
                                          NSMakePoint(528, 662));
    TSStroke(rightPaw, ink, 5.0);

    // Tail.
    NSBezierPath *tail = [NSBezierPath bezierPath];
    [tail moveToPoint:NSMakePoint(612, 626)];
    [tail curveToPoint:NSMakePoint(694, 558)
         controlPoint1:NSMakePoint(678, 628)
         controlPoint2:NSMakePoint(704, 608)];
    [tail curveToPoint:NSMakePoint(668, 514)
         controlPoint1:NSMakePoint(688, 528)
         controlPoint2:NSMakePoint(676, 516)];
    TSStroke(tail, ink, 9.0);

    // Ground line and hatching.
    NSBezierPath *ground = TSCurvedPath(NSMakePoint(350, 692),
                                        NSMakePoint(430, 700),
                                        NSMakePoint(590, 700),
                                        NSMakePoint(668, 690));
    TSStroke(ground, softInk, 3.5);
    for (NSInteger i = 0; i < 7; i++) {
        CGFloat x = 390 + i * 34;
        NSBezierPath *hatch = [NSBezierPath bezierPath];
        [hatch moveToPoint:NSMakePoint(x, 690)];
        [hatch lineToPoint:NSMakePoint(x + 14, 702)];
        TSStroke(hatch, TSIconColor(0x2B2E2C, 0.20), 2.4);
    }

    // Cheek hatching for a hand-drawn feel.
    for (NSInteger i = 0; i < 3; i++) {
        NSBezierPath *cheek = [NSBezierPath bezierPath];
        [cheek moveToPoint:NSMakePoint(438 + i * 7, 524)];
        [cheek lineToPoint:NSMakePoint(446 + i * 7, 536)];
        TSStroke(cheek, TSIconColor(0x2B2E2C, 0.24), 2.2);
    }

    // Four-point AI sparkle on the screen.
    [self drawSparkleAtPoint:NSMakePoint(704, 354) size:31 color:TSIconColor(0xB8863B, 0.95)];
    [self drawSparkleAtPoint:NSMakePoint(742, 396) size:14 color:TSIconColor(0x8E6A32, 0.8)];

    (void)screen;
}

+ (void)drawSparkleAtPoint:(NSPoint)center size:(CGFloat)size color:(NSColor *)color {
    NSBezierPath *star = [NSBezierPath bezierPath];
    [star moveToPoint:NSMakePoint(center.x, center.y - size)];
    [star curveToPoint:NSMakePoint(center.x + size * 0.22, center.y - size * 0.22)
         controlPoint1:NSMakePoint(center.x + size * 0.06, center.y - size * 0.34)
         controlPoint2:NSMakePoint(center.x + size * 0.12, center.y - size * 0.16)];
    [star curveToPoint:NSMakePoint(center.x + size, center.y)
         controlPoint1:NSMakePoint(center.x + size * 0.28, center.y - size * 0.06)
         controlPoint2:NSMakePoint(center.x + size * 0.40, center.y)];
    [star curveToPoint:NSMakePoint(center.x + size * 0.22, center.y + size * 0.22)
         controlPoint1:NSMakePoint(center.x + size * 0.40, center.y)
         controlPoint2:NSMakePoint(center.x + size * 0.28, center.y + size * 0.06)];
    [star curveToPoint:NSMakePoint(center.x, center.y + size)
         controlPoint1:NSMakePoint(center.x + size * 0.12, center.y + size * 0.16)
         controlPoint2:NSMakePoint(center.x + size * 0.06, center.y + size * 0.34)];
    [star curveToPoint:NSMakePoint(center.x - size * 0.22, center.y + size * 0.22)
         controlPoint1:NSMakePoint(center.x - size * 0.06, center.y + size * 0.34)
         controlPoint2:NSMakePoint(center.x - size * 0.12, center.y + size * 0.16)];
    [star curveToPoint:NSMakePoint(center.x - size, center.y)
         controlPoint1:NSMakePoint(center.x - size * 0.28, center.y + size * 0.06)
         controlPoint2:NSMakePoint(center.x - size * 0.40, center.y)];
    [star curveToPoint:NSMakePoint(center.x - size * 0.22, center.y - size * 0.22)
         controlPoint1:NSMakePoint(center.x - size * 0.40, center.y)
         controlPoint2:NSMakePoint(center.x - size * 0.28, center.y - size * 0.06)];
    [star curveToPoint:NSMakePoint(center.x, center.y - size)
         controlPoint1:NSMakePoint(center.x - size * 0.12, center.y - size * 0.16)
         controlPoint2:NSMakePoint(center.x - size * 0.06, center.y - size * 0.34)];
    [star closePath];
    TSFill(star, color);

    NSBezierPath *core = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - size * 0.10,
                                                                           center.y - size * 0.10,
                                                                           size * 0.20,
                                                                           size * 0.20)];
    TSFill(core, [NSColor colorWithCalibratedWhite:1.0 alpha:0.82]);
}

+ (void)drawKnobAtCenter:(NSPoint)center radius:(CGFloat)radius {
    NSRect seatRect = NSMakeRect(center.x - radius * 1.10, center.y - radius * 1.10,
                                 radius * 2.20, radius * 2.20);
    NSBezierPath *seat = [NSBezierPath bezierPathWithOvalInRect:seatRect];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *seatShadow = [NSShadow new];
    seatShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.45];
    seatShadow.shadowBlurRadius = 10.0;
    seatShadow.shadowOffset = NSMakeSize(0, 5);
    [seatShadow set];
    NSGradient *seatGradient = [[NSGradient alloc] initWithStartingColor:TSIconColor(0x37231D, 1.0)
                                                           endingColor:TSIconColor(0x6F4A3C, 1.0)];
    [seatGradient drawInBezierPath:seat angle:-70.0];
    [NSGraphicsContext restoreGraphicsState];

    CGFloat outerRadius = radius * 0.94;
    NSRect outerRect = NSMakeRect(center.x - outerRadius, center.y - outerRadius,
                                  outerRadius * 2.0, outerRadius * 2.0);
    NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:outerRect];
    NSGradient *bodyGradient = [[NSGradient alloc] initWithColors:@[
        TSIconColor(0xE8775A, 1.0),
        TSIconColor(0xC64B3C, 1.0),
        TSIconColor(0x7C1F18, 1.0),
        TSIconColor(0xB43C30, 1.0)
    ]];
    [bodyGradient drawInBezierPath:outer angle:-64.0];

    for (NSInteger i = 0; i < 26; i++) {
        CGFloat angle = (CGFloat)i / 26.0 * M_PI * 2.0 + 0.2;
        CGFloat inner = outerRadius * 0.72;
        CGFloat rim = outerRadius * 0.98;
        NSBezierPath *ridge = [NSBezierPath bezierPath];
        [ridge moveToPoint:NSMakePoint(center.x + cos(angle) * inner, center.y + sin(angle) * inner)];
        [ridge lineToPoint:NSMakePoint(center.x + cos(angle) * rim, center.y + sin(angle) * rim)];
        ridge.lineWidth = 1.6;
        ridge.lineCapStyle = NSLineCapStyleRound;
        [[NSColor colorWithCalibratedWhite:(i % 2 == 0 ? 0.0 : 1.0)
                                    alpha:(i % 2 == 0 ? 0.28 : 0.16)] setStroke];
        [ridge stroke];
    }

    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.55] setStroke];
    outer.lineWidth = 2.0;
    [outer stroke];
    NSBezierPath *highlight = [NSBezierPath bezierPath];
    [highlight appendBezierPathWithArcWithCenter:center
                                         radius:outerRadius - 3.0
                                     startAngle:0.9
                                       endAngle:2.5
                                      clockwise:NO];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.30] setStroke];
    highlight.lineWidth = 2.4;
    [highlight stroke];

    CGFloat capRadius = radius * 0.46;
    NSBezierPath *cap = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - capRadius,
                                                                          center.y - capRadius,
                                                                          capRadius * 2.0,
                                                                          capRadius * 2.0)];
    NSGradient *capGradient = [[NSGradient alloc] initWithColors:@[
        TSIconColor(0xB95243, 1.0),
        TSIconColor(0x6C1D16, 1.0),
        TSIconColor(0x9A3127, 1.0)
    ]];
    [capGradient drawInBezierPath:cap angle:-80.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] setStroke];
    cap.lineWidth = 1.4;
    [cap stroke];

    NSBezierPath *specular = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - capRadius * 0.58,
                                                                                center.y - capRadius * 0.52,
                                                                                capRadius * 0.9,
                                                                                capRadius * 0.52)];
    TSFill(specular, [NSColor colorWithCalibratedWhite:1.0 alpha:0.18]);
}

+ (void)drawScrewAtPoint:(NSPoint)center radius:(CGFloat)radius angle:(CGFloat)angle {
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - radius,
                                                                             center.y - radius,
                                                                             radius * 2.0,
                                                                             radius * 2.0)];
    NSGradient *metal = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.76 alpha:1.0]
                                                       endingColor:[NSColor colorWithCalibratedWhite:0.36 alpha:1.0]];
    [metal drawInBezierPath:circle angle:-60.0];
    [[NSColor colorWithCalibratedWhite:0.08 alpha:0.7] setStroke];
    circle.lineWidth = 1.0;
    [circle stroke];

    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:center.x yBy:center.y];
    [transform rotateByRadians:angle];
    [transform concat];
    NSBezierPath *slot = [NSBezierPath bezierPath];
    [slot moveToPoint:NSMakePoint(-radius * 0.56, 0)];
    [slot lineToPoint:NSMakePoint(radius * 0.56, 0)];
    slot.lineWidth = 2.4;
    slot.lineCapStyle = NSLineCapStyleRound;
    [[NSColor colorWithCalibratedWhite:0.10 alpha:0.7] setStroke];
    [slot stroke];
    [NSGraphicsContext restoreGraphicsState];
}

@end
