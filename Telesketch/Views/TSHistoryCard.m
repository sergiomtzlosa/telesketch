#import "TSHistoryCard.h"
#import "TSStrokeRenderer.h"
#import "NSColor+TSHex.h"

@interface TSHistoryCard ()
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@property (nonatomic, assign) BOOL hovering;
@end

@implementation TSHistoryCard

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.bezelStyle = NSBezelStyleShadowlessSquare;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.focusRingType = NSFocusRingTypeNone;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 10.0;
        self.layer.masksToBounds = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.05].CGColor;
    }
    return self;
}

- (void)setDrawing:(TSDrawing *)drawing {
    _drawing = drawing;
    [self setNeedsDisplay:YES];
}

- (void)setTheme:(TSTheme *)theme {
    _theme = theme;
    [self setNeedsDisplay:YES];
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
    self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.10].CGColor;
}

- (void)mouseExited:(NSEvent *)event {
    self.hovering = NO;
    self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.05].CGColor;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    NSRect thumbRect = NSMakeRect(8.0, 8.0, 66.0, bounds.size.height - 16.0);
    thumbRect.size.width = thumbRect.size.height * 4.0 / 3.0;

    NSBezierPath *thumbPath = [NSBezierPath bezierPathWithRoundedRect:thumbRect xRadius:5.0 yRadius:5.0];
    [NSGraphicsContext saveGraphicsState];
    [thumbPath addClip];
    if (self.drawing && self.theme) {
        [TSStrokeRenderer drawScreenBackgroundInRect:thumbRect theme:self.theme];
        [TSStrokeRenderer drawStrokes:self.drawing.strokes inRect:NSInsetRect(thumbRect, 3, 3) theme:self.theme];
    } else {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.06] setFill];
        [thumbPath fill];
    }
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.12] setStroke];
    thumbPath.lineWidth = 1.0;
    [thumbPath stroke];

    NSString *title = self.drawing.title ?: @"Sketch";
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.92 alpha:1.0],
        NSParagraphStyleAttributeName: paragraph
    };
    NSRect titleRect = NSMakeRect(NSMaxX(thumbRect) + 10.0, bounds.size.height * 0.5 - 1.0,
                                  bounds.size.width - NSMaxX(thumbRect) - 22.0, 16.0);
    [title drawInRect:titleRect withAttributes:titleAttributes];

    NSString *subtitle = self.drawing.strokes.count > 0
        ? [NSString stringWithFormat:@"%lu strokes", (unsigned long)self.drawing.strokes.count]
        : @"Empty";
    NSDictionary *subtitleAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.65 alpha:0.9],
        NSParagraphStyleAttributeName: paragraph
    };
    NSRect subtitleRect = NSMakeRect(NSMaxX(thumbRect) + 10.0, bounds.size.height * 0.5 - 17.0,
                                     bounds.size.width - NSMaxX(thumbRect) - 22.0, 14.0);
    [subtitle drawInRect:subtitleRect withAttributes:subtitleAttributes];
}

@end
