#import "TSPromptField.h"

@implementation TSPromptField

- (instancetype)initWithFrame:(NSRect)frameRect {
    NSTextStorage *storage = [NSTextStorage new];
    NSLayoutManager *layoutManager = [NSLayoutManager new];
    [storage addLayoutManager:layoutManager];
    NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(frameRect.size.width, CGFLOAT_MAX)];
    container.widthTracksTextView = YES;
    [layoutManager addTextContainer:container];

    self = [super initWithFrame:frameRect textContainer:container];
    if (self) {
        _characterLimit = 280;
        self.richText = NO;
        self.importsGraphics = NO;
        self.allowsUndo = YES;
        self.drawsBackground = NO;
        self.font = [NSFont systemFontOfSize:14.0 weight:NSFontWeightRegular];
        self.textColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
        self.insertionPointColor = [NSColor colorWithSRGBRed:0.88 green:0.42 blue:0.34 alpha:1.0];
        self.textContainerInset = NSMakeSize(3.0, 3.0);
        self.horizontallyResizable = NO;
        self.verticallyResizable = YES;
        self.autoresizingMask = NSViewWidthSizable;
        self.minSize = NSMakeSize(0, 0);
        self.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        self.textContainer.widthTracksTextView = YES;
        self.accessibilityLabel = @"Sketch prompt";
    }
    return self;
}

- (void)setPlaceholderString:(NSString *)placeholderString {
    _placeholderString = [placeholderString copy];
    [self setNeedsDisplay:YES];
}

- (void)setCharacterLimit:(NSUInteger)characterLimit {
    _characterLimit = characterLimit;
    [self enforceCharacterLimit];
}

- (void)setPromptString:(NSString *)string {
    NSString *safe = string ?: @"";
    if (self.characterLimit > 0 && safe.length > self.characterLimit) {
        safe = [safe substringToIndex:self.characterLimit];
    }
    self.string = safe;
    [self setNeedsDisplay:YES];
}

- (void)enforceCharacterLimit {
    if (self.characterLimit > 0 && self.string.length > self.characterLimit) {
        self.string = [self.string substringToIndex:self.characterLimit];
    }
}

- (void)didChangeText {
    [super didChangeText];
    [self enforceCharacterLimit];
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 36 || event.keyCode == 76) {
        BOOL shift = (event.modifierFlags & NSEventModifierFlagShift) != 0;
        BOOL command = (event.modifierFlags & NSEventModifierFlagCommand) != 0;
        if (!shift) {
            if (command && self.onSubmit) {
                self.onSubmit();
            } else if (!command && self.onSubmit) {
                self.onSubmit();
            }
            return;
        }
    }
    [super keyDown:event];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (self.string.length == 0 && self.placeholderString.length > 0) {
        NSDictionary *attributes = @{
            NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:14.0],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.65 alpha:0.65],
            NSParagraphStyleAttributeName: [NSParagraphStyle defaultParagraphStyle]
        };
        NSRect inset = NSInsetRect(self.bounds, self.textContainerInset.width + 2.0, self.textContainerInset.height + 1.0);
        [self.placeholderString drawWithRect:inset
                                     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                                  attributes:attributes];
    }
}

- (BOOL)becomeFirstResponder {
    BOOL result = [super becomeFirstResponder];
    [self setNeedsDisplay:YES];
    return result;
}

- (void)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)flag {
    [super drawInsertionPointInRect:rect color:color turnedOn:flag];
}

@end
