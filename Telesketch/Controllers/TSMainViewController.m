#import "TSMainViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "TSDrawingDocument.h"
#import "TSStageView.h"
#import "TSDeviceView.h"
#import "TSCanvasView.h"
#import "TSActionButton.h"
#import "TSIconButton.h"
#import "TSToolButton.h"
#import "TSColorSwatch.h"
#import "TSPromptField.h"
#import "TSHistoryCard.h"
#import "TSOpenCodeService.h"
#import "TSSketchPromptBuilder.h"
#import "TSSketchParser.h"
#import "TSOfflineSketchEngine.h"
#import "TSImageExporter.h"
#import "TSImageTracer.h"
#import "TSTheme.h"
#import "NSColor+TSHex.h"

static const CGFloat TSLeftRailWidth = 248.0;
static const CGFloat TSRightRailWidth = 348.0;
static const CGFloat TSTopBarHeight = 54.0;
static const CGFloat TSRailPadding = 18.0;

static NSColor *TSStudioWhite(CGFloat alpha) {
    return [NSColor colorWithCalibratedWhite:1.0 alpha:alpha];
}

static NSTextField *TSLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color) {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.maximumNumberOfLines = 1;
    label.drawsBackground = NO;
    label.bordered = NO;
    label.editable = NO;
    label.selectable = NO;
    return label;
}

static NSString *TSHexStringFromColor(NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] ?: color;
    if (!rgb) return @"#000000";
    CGFloat r = 0, g = 0, b = 0, a = 1;
    [rgb getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)llround(r * 255.0), (int)llround(g * 255.0), (int)llround(b * 255.0)];
}

#pragma mark - Small custom views

@interface TSChromeRootView : NSView
@end

@implementation TSChromeRootView
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithSRGBRed:0.055 green:0.067 blue:0.059 alpha:1.0] setFill];
    NSRectFill(self.bounds);
}
@end

@interface TSFlippedView : NSView
@end

@implementation TSFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface TSRailView : NSVisualEffectView
@end

@implementation TSRailView
- (BOOL)isFlipped { return YES; }
@end

@interface TSTopBarView : NSView
@end

@implementation TSTopBarView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithSRGBRed:0.105 green:0.125 blue:0.112 alpha:0.97], 0.0,
        [NSColor colorWithSRGBRed:0.058 green:0.073 blue:0.063 alpha:0.97], 1.0, nil];
    [gradient drawInRect:self.bounds angle:-90.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.075] setFill];
    NSRectFill(NSMakeRect(NSMinX(self.bounds), NSMaxY(self.bounds) - 0.5, self.bounds.size.width, 0.5));
}
- (void)mouseDown:(NSEvent *)event {
    if (event.clickCount == 2) {
        [self.window performZoom:nil];
        return;
    }
    [self.window performWindowDragWithEvent:event];
}
@end

@interface TSBrandMarkView : NSView
@end

@implementation TSBrandMarkView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6.0 yRadius:6.0];
    NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithSRGBRed:0.88 green:0.44 blue:0.35 alpha:1.0], 0.0,
        [NSColor colorWithSRGBRed:0.66 green:0.20 blue:0.16 alpha:1.0], 1.0, nil];
    [gradient drawInBezierPath:path angle:-70.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] setStroke];
    path.lineWidth = 0.8;
    [path stroke];

    NSBezierPath *squiggle = [NSBezierPath bezierPath];
    [squiggle moveToPoint:NSMakePoint(5.5, 15.0)];
    [squiggle curveToPoint:NSMakePoint(11.0, 7.0)
             controlPoint1:NSMakePoint(8.0, 12.0)
             controlPoint2:NSMakePoint(7.0, 8.0)];
    [squiggle curveToPoint:NSMakePoint(16.5, 12.0)
             controlPoint1:NSMakePoint(13.5, 6.0)
             controlPoint2:NSMakePoint(15.0, 13.5)];
    squiggle.lineWidth = 1.6;
    squiggle.lineCapStyle = NSLineCapStyleRound;
    [[NSColor colorWithSRGBRed:0.96 green:0.91 blue:0.82 alpha:0.92] setStroke];
    [squiggle stroke];

    NSBezierPath *gloss = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(3.0, 2.5, 16.0, 6.0) xRadius:3.0 yRadius:3.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.16] setFill];
    [gloss fill];
}
@end

@interface TSWidthPreviewView : NSView
@property (nonatomic, strong) TSTheme *theme;
@property (nonatomic, assign) TSColorRole role;
@property (nonatomic, copy) NSString *customHex;
@property (nonatomic, assign) CGFloat previewWidth;
@end

@implementation TSWidthPreviewView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _theme = [TSTheme defaultTheme];
        _role = TSColorRoleInk;
        _customHex = @"";
        _previewWidth = 3.0;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 7.0;
        self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.04].CGColor;
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    NSColor *color = nil;
    if (self.role == TSColorRoleCustom && self.customHex.length > 0) {
        color = [NSColor ts_colorWithHex:self.customHex];
    } else {
        color = [NSColor ts_colorWithHex:[self.theme colorHexForRole:self.role]];
    }
    color = color ?: [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    CGFloat y = NSMidY(self.bounds);
    CGFloat margin = 22.0;
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(margin, y)];
    [path curveToPoint:NSMakePoint(NSMaxX(self.bounds) - margin, y)
         controlPoint1:NSMakePoint(NSMidX(self.bounds) * 0.7, y - 4.0)
         controlPoint2:NSMakePoint(NSMidX(self.bounds) * 1.3, y + 4.0)];
    path.lineCapStyle = NSLineCapStyleRound;

    [[color colorWithAlphaComponent:0.14] setStroke];
    path.lineWidth = self.previewWidth + 2.4;
    [path stroke];
    [color setStroke];
    path.lineWidth = MAX(0.8, self.previewWidth);
    [path stroke];

    // End caps make the weight easier to judge.
    CGFloat capRadius = MAX(1.2, self.previewWidth * 0.5);
    [color setFill];
    NSRectFill(NSMakeRect(margin - capRadius, y - capRadius, capRadius * 2, capRadius * 2));
    NSRectFill(NSMakeRect(NSMaxX(self.bounds) - margin - capRadius, y - capRadius, capRadius * 2, capRadius * 2));
}
@end

@interface TSPromptCardView : NSView
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) TSPromptField *promptField;
@end

@implementation TSPromptCardView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = 10.0;
        self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.055].CGColor;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.09].CGColor;

        _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        _scrollView.drawsBackground = NO;
        _scrollView.borderType = NSNoBorder;
        _scrollView.hasVerticalScroller = YES;
        _scrollView.autohidesScrollers = YES;
        _scrollView.scrollerStyle = NSScrollerStyleOverlay;
        [self addSubview:_scrollView];

        _promptField = [[TSPromptField alloc] initWithFrame:NSMakeRect(0, 0, 200, 60)];
        _promptField.autoresizingMask = NSViewWidthSizable;
        _scrollView.documentView = _promptField;
    }
    return self;
}
- (BOOL)isFlipped { return YES; }
- (void)layout {
    [super layout];
    NSRect inner = NSInsetRect(self.bounds, 10.0, 8.0);
    self.scrollView.frame = NSInsetRect(self.bounds, 8.0, 7.0);
    NSSize contentSize = self.scrollView.contentSize;
    if (contentSize.width < 1 || contentSize.height < 1) return;
    self.promptField.minSize = NSMakeSize(contentSize.width, contentSize.height);
    self.promptField.maxSize = NSMakeSize(contentSize.width, CGFLOAT_MAX);
    NSRect frame = self.promptField.frame;
    frame.size.width = contentSize.width;
    frame.size.height = MAX(contentSize.height, frame.size.height);
    self.promptField.frame = frame;
    (void)inner;
}
@end

#pragma mark - Main controller

@interface TSMainViewController () <TSCanvasViewDelegate, NSMenuItemValidation>
@property (nonatomic, weak, nullable) TSDrawingDocument *document;
@property (nonatomic, strong) TSTheme *theme;

@property (nonatomic, strong) TSChromeRootView *rootView;
@property (nonatomic, strong) TSTopBarView *topBar;
@property (nonatomic, strong) TSStageView *stageView;
@property (nonatomic, strong) TSRailView *toolRail;
@property (nonatomic, strong) TSRailView *atelierRail;

@property (nonatomic, strong) TSBrandMarkView *brandMarkView;
@property (nonatomic, strong) NSTextField *brandLabel;
@property (nonatomic, strong) NSTextField *documentNameLabel;
@property (nonatomic, strong) TSIconButton *topUndoButton;
@property (nonatomic, strong) TSIconButton *topRedoButton;
@property (nonatomic, strong) TSActionButton *exportButton;
@property (nonatomic, strong) TSIconButton *toolRailToggleButton;
@property (nonatomic, strong) TSIconButton *atelierToggleButton;
@property (nonatomic, strong) NSView *leftRailHairline;
@property (nonatomic, strong) NSView *rightRailHairline;

@property (nonatomic, strong) NSArray<TSToolButton *> *toolButtons;
@property (nonatomic, strong) NSArray<NSTextField *> *toolRailSectionLabels;
@property (nonatomic, strong) NSArray<TSColorSwatch *> *colorSwatches;
@property (nonatomic, strong) TSColorSwatch *customSwatch;
@property (nonatomic, strong) NSTextField *widthValueLabel;
@property (nonatomic, strong) NSSlider *widthSlider;
@property (nonatomic, strong) TSWidthPreviewView *widthPreview;
@property (nonatomic, strong) NSSegmentedControl *themeControl;
@property (nonatomic, strong) TSActionButton *railUndoButton;
@property (nonatomic, strong) TSActionButton *railRedoButton;
@property (nonatomic, strong) TSActionButton *traceButton;
@property (nonatomic, strong) TSActionButton *clearButton;
@property (nonatomic, strong) NSTextField *knobHintLabel;

@property (nonatomic, strong) NSScrollView *atelierScrollView;
@property (nonatomic, strong) TSFlippedView *atelierContent;
@property (nonatomic, strong) NSTextField *atelierTitleLabel;
@property (nonatomic, strong) NSView *statusDotView;
@property (nonatomic, strong) NSTextField *openCodeDetailLabel;
@property (nonatomic, strong) TSPromptCardView *promptCard;
@property (nonatomic, strong) TSPromptField *promptField;
@property (nonatomic, strong) NSArray<TSActionButton *> *suggestionButtons;
@property (nonatomic, strong) NSTextField *engineSectionLabel;
@property (nonatomic, strong) NSSegmentedControl *engineControl;
@property (nonatomic, strong) NSPopUpButton *modelPopup;
@property (nonatomic, strong) TSIconButton *refreshModelsButton;
@property (nonatomic, strong) NSTextField *engineHintLabel;
@property (nonatomic, strong) TSActionButton *generateButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) NSTextField *activityLabel;
@property (nonatomic, strong) TSIconButton *cancelButton;
@property (nonatomic, strong) NSTextField *recentLabel;
@property (nonatomic, strong) NSTextField *historyEmptyLabel;
@property (nonatomic, strong) NSMutableArray<TSHistoryCard *> *historyCards;
@property (nonatomic, strong) NSTextField *privacyLabel;

@property (nonatomic, copy) NSString *selectedToolIdentifier;
@property (nonatomic, assign) TSColorRole selectedRole;
@property (nonatomic, copy) NSString *customColorHex;
@property (nonatomic, assign) CGFloat strokeWidth;

@property (nonatomic, strong) NSMutableArray<TSDrawing *> *recentDrawings;
@property (nonatomic, assign) BOOL toolRailVisible;
@property (nonatomic, assign) BOOL atelierVisible;
@property (nonatomic, assign) BOOL animatingRails;
@property (nonatomic, assign) BOOL generating;
@property (nonatomic, assign) NSInteger generationToken;
@property (nonatomic, assign) BOOL didInstallKeyMonitor;
@property (nonatomic, assign) BOOL didRequestOpenCodeStart;
@property (nonatomic, assign) BOOL didPrepareClose;
@property (nonatomic, strong, nullable) id keyMonitor;
@property (nonatomic, weak, nullable) NSSavePanel *activeExportPanel;
@property (nonatomic, strong, nullable) NSPopUpButton *exportFormatPopup;
@property (nonatomic, copy) NSString *exportBaseName;
@end

@interface TSMainViewController ()
- (void)generateWithOpenCodePrompt:(NSString *)prompt
                            repair:(BOOL)repair
             localFallbackAttempted:(BOOL)localFallbackAttempted;
- (nullable TSOpenCodeModel *)localFallbackModel;
@end

@implementation TSMainViewController

- (instancetype)initWithDocument:(TSDrawingDocument *)document {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _document = document;
        _theme = [TSTheme themeWithIdentifier:document.drawing.themeIdentifier] ?: [TSTheme defaultTheme];
        _selectedToolIdentifier = @"pen";
        _selectedRole = TSColorRoleInk;
        _strokeWidth = 3.0;
        _customColorHex = [[NSUserDefaults standardUserDefaults] stringForKey:@"TSCustomInkColor"] ?: @"#7A5CA8";
        _recentDrawings = [NSMutableArray array];
        _historyCards = [NSMutableArray array];
        _toolRailVisible = YES;
        _atelierVisible = YES;
    }
    return self;
}

- (void)loadView {
    self.rootView = [[TSChromeRootView alloc] initWithFrame:NSMakeRect(0, 0, 1440, 900)];
    self.view = self.rootView;
    [self buildInterface];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self registerNotifications];
    [self refreshInterfaceFromDocument];
    [self updateEngineAppearance];
    [self updateOpenCodeInterface];
    [self updateGeneratingInterfaceWithMessage:nil];
    [self updateUndoButtons];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self installKeyMonitor];
    [self.view.window makeFirstResponder:self.canvasView];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL autoStart = [[NSUserDefaults standardUserDefaults] boolForKey:@"TSAutoStartOpenCode"];
        if (self.engineControl.selectedSegment == 0 && autoStart) {
            [self requestOpenCodeStartIfNeeded];
        }
    });
}

- (void)dealloc {
    if (_keyMonitor) {
        [NSEvent removeMonitor:_keyMonitor];
        _keyMonitor = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (TSCanvasView *)canvasView {
    return self.stageView.deviceView.canvasView;
}

- (TSDeviceView *)deviceView {
    return self.stageView.deviceView;
}

- (void)buildInterface {
    self.stageView = [[TSStageView alloc] initWithFrame:NSZeroRect];
    self.stageView.deviceView.theme = self.theme;
    self.stageView.deviceView.canvasView.delegate = self;
    self.stageView.deviceView.canvasView.strokeWidth = self.strokeWidth;
    [self.rootView addSubview:self.stageView];

    self.toolRail = [self buildToolRail];
    [self.rootView addSubview:self.toolRail];

    self.atelierRail = [self buildAtelierRail];
    [self.rootView addSubview:self.atelierRail];

    self.topBar = [[TSTopBarView alloc] initWithFrame:NSZeroRect];
    [self.rootView addSubview:self.topBar];
    [self buildTopBarContents];
}

- (void)buildTopBarContents {
    self.brandMarkView = [[TSBrandMarkView alloc] initWithFrame:NSZeroRect];
    [self.topBar addSubview:self.brandMarkView];

    self.brandLabel = TSLabel(@"TELESKETCH", 12.5, NSFontWeightSemibold, TSStudioWhite(0.92));
    self.brandLabel.attributedStringValue = [[NSAttributedString alloc] initWithString:@"TELESKETCH"
        attributes:@{
            NSFontAttributeName: [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: TSStudioWhite(0.92),
            NSKernAttributeName: @3.2
        }];
    [self.topBar addSubview:self.brandLabel];

    self.documentNameLabel = TSLabel(@"Untitled Sketch", 12.5, NSFontWeightMedium, TSStudioWhite(0.62));
    self.documentNameLabel.alignment = NSTextAlignmentCenter;
    [self.topBar addSubview:self.documentNameLabel];

    self.topUndoButton = [TSIconButton buttonWithSymbolName:@"arrow.uturn.backward"
                                                     target:self
                                                     action:@selector(undo:)
                                                description:@"Undo"];
    [self.topBar addSubview:self.topUndoButton];
    self.topRedoButton = [TSIconButton buttonWithSymbolName:@"arrow.uturn.forward"
                                                     target:self
                                                     action:@selector(redo:)
                                                description:@"Redo"];
    [self.topBar addSubview:self.topRedoButton];

    self.exportButton = [TSActionButton buttonWithTitle:@"Export"
                                             symbolName:@"square.and.arrow.up"
                                                 target:self
                                                 action:@selector(exportDrawing:)];
    self.exportButton.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightSemibold];
    [self.exportButton setTitleText:@"Export"];
    self.exportButton.fillColor = TSStudioWhite(0.07);
    self.exportButton.hoverFillColor = TSStudioWhite(0.13);
    [self.topBar addSubview:self.exportButton];

    self.toolRailToggleButton = [TSIconButton buttonWithSymbolName:@"sidebar.left"
                                                            target:self
                                                            action:@selector(toggleToolRail:)
                                                       description:@"Show or hide the tool rail"];
    [self.topBar addSubview:self.toolRailToggleButton];
    self.atelierToggleButton = [TSIconButton buttonWithSymbolName:@"sidebar.right"
                                                           target:self
                                                           action:@selector(toggleAtelier:)
                                                      description:@"Show or hide the AI atelier"];
    [self.topBar addSubview:self.atelierToggleButton];
}

- (NSTextField *)railSectionLabel:(NSString *)text {
    NSTextField *label = TSLabel(text.uppercaseString, 10.0, NSFontWeightSemibold, TSStudioWhite(0.46));
    label.attributedStringValue = [[NSAttributedString alloc] initWithString:text.uppercaseString
        attributes:@{
            NSFontAttributeName: [NSFont systemFontOfSize:10.0 weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: TSStudioWhite(0.46),
            NSKernAttributeName: @1.4
        }];
    return label;
}

- (TSRailView *)buildToolRail {
    TSRailView *rail = [[TSRailView alloc] initWithFrame:NSZeroRect];
    rail.material = NSVisualEffectMaterialHUDWindow;
    rail.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    rail.state = NSVisualEffectStateActive;
    rail.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    rail.wantsLayer = YES;

    self.leftRailHairline = [[NSView alloc] initWithFrame:NSZeroRect];
    self.leftRailHairline.wantsLayer = YES;
    self.leftRailHairline.layer.backgroundColor = TSStudioWhite(0.08).CGColor;
    [rail addSubview:self.leftRailHairline];

    NSTextField *toolsLabel = [self railSectionLabel:@"Tools"];
    NSTextField *inkLabel = [self railSectionLabel:@"Ink"];
    NSTextField *widthLabel = [self railSectionLabel:@"Width"];
    NSTextField *screenLabel = [self railSectionLabel:@"Screen"];
    NSTextField *actionsLabel = [self railSectionLabel:@"Actions"];
    self.toolRailSectionLabels = @[toolsLabel, inkLabel, widthLabel, screenLabel, actionsLabel];
    for (NSTextField *label in self.toolRailSectionLabels) {
        [rail addSubview:label];
    }

    TSToolButton *pen = [TSToolButton buttonWithIdentifier:@"pen"
                                                     title:@"Pen"
                                                symbolName:@"pencil"
                                                    target:self
                                                    action:@selector(selectTool:)];
    pen.selected = YES;
    TSToolButton *eraser = [TSToolButton buttonWithIdentifier:@"eraser"
                                                        title:@"Eraser"
                                                   symbolName:@"eraser"
                                                       target:self
                                                       action:@selector(selectTool:)];
    TSToolButton *knob = [TSToolButton buttonWithIdentifier:@"knob"
                                                      title:@"Knob"
                                                 symbolName:@"dial.medium"
                                                     target:self
                                                     action:@selector(selectTool:)];
    self.toolButtons = @[pen, eraser, knob];
    for (TSToolButton *button in self.toolButtons) {
        [rail addSubview:button];
    }

    NSMutableArray<TSColorSwatch *> *swatches = [NSMutableArray array];
    NSArray<NSNumber *> *roles = @[@(TSColorRoleInk), @(TSColorRoleVermilion), @(TSColorRoleTeal),
                                   @(TSColorRoleOchre), @(TSColorRoleBlue), @(TSColorRoleCustom)];
    NSArray<NSString *> *names = @[@"Graphite ink", @"Vermilion ink", @"Teal ink",
                                   @"Ochre ink", @"Blue ink", @"Custom colour"];
    NSInteger index = 0;
    for (NSNumber *roleNumber in roles) {
        TSColorSwatch *swatch = [[TSColorSwatch alloc] initWithFrame:NSZeroRect];
        swatch.role = (TSColorRole)roleNumber.integerValue;
        swatch.target = self;
        swatch.action = @selector(selectSwatch:);
        swatch.toolTip = names[index];
        swatch.accessibilityLabel = names[index];
        swatch.swatchDiameter = 24.0;
        [rail addSubview:swatch];
        [swatches addObject:swatch];
        if (swatch.role == TSColorRoleCustom) {
            self.customSwatch = swatch;
        }
        index++;
    }
    self.colorSwatches = swatches;

    self.widthValueLabel = TSLabel(@"3.0 pt", 10.0, NSFontWeightMedium, TSStudioWhite(0.62));
    self.widthValueLabel.alignment = NSTextAlignmentRight;
    [rail addSubview:self.widthValueLabel];

    self.widthSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.widthSlider.minValue = 0.6;
    self.widthSlider.maxValue = 12.0;
    self.widthSlider.doubleValue = self.strokeWidth;
    self.widthSlider.continuous = YES;
    self.widthSlider.controlSize = NSControlSizeSmall;
    self.widthSlider.target = self;
    self.widthSlider.action = @selector(widthChanged:);
    self.widthSlider.toolTip = @"Ink width";
    [rail addSubview:self.widthSlider];

    self.widthPreview = [[TSWidthPreviewView alloc] initWithFrame:NSZeroRect];
    self.widthPreview.role = self.selectedRole;
    self.widthPreview.customHex = self.customColorHex;
    self.widthPreview.previewWidth = self.strokeWidth;
    [rail addSubview:self.widthPreview];

    self.themeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Classic", @"Midnight", @"Blueprint"]
                                                         trackingMode:NSSegmentSwitchTrackingSelectOne
                                                               target:self
                                                               action:@selector(themeChanged:)];
    self.themeControl.controlSize = NSControlSizeSmall;
    self.themeControl.font = [NSFont systemFontOfSize:10.0 weight:NSFontWeightMedium];
    self.themeControl.selectedSegment = 0;
    [rail addSubview:self.themeControl];

    self.railUndoButton = [TSActionButton buttonWithTitle:@"Undo"
                                               symbolName:@"arrow.uturn.backward"
                                                   target:self
                                                   action:@selector(undo:)];
    self.railUndoButton.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    [self.railUndoButton setTitleText:@"Undo"];
    [rail addSubview:self.railUndoButton];

    self.railRedoButton = [TSActionButton buttonWithTitle:@"Redo"
                                               symbolName:@"arrow.uturn.forward"
                                                   target:self
                                                   action:@selector(redo:)];
    self.railRedoButton.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    [self.railRedoButton setTitleText:@"Redo"];
    [rail addSubview:self.railRedoButton];

    self.traceButton = [TSActionButton buttonWithTitle:@"Trace Image…"
                                            symbolName:@"photo"
                                                target:self
                                                action:@selector(traceImage:)];
    self.traceButton.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    [self.traceButton setTitleText:@"Trace Image…"];
    [rail addSubview:self.traceButton];

    self.clearButton = [TSActionButton buttonWithTitle:@"Clear Screen"
                                            symbolName:@"trash"
                                                target:self
                                                action:@selector(shakeToClear:)];
    self.clearButton.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightSemibold];
    [self.clearButton setTitleText:@"Clear Screen"];
    self.clearButton.destructive = YES;
    self.clearButton.hoverFillColor = [NSColor colorWithSRGBRed:0.60 green:0.18 blue:0.15 alpha:0.42];
    [rail addSubview:self.clearButton];

    self.knobHintLabel = TSLabel(@"Knob mode: turn the X and Y controls to plot a line. Click the screen to place the stylus.",
                                 10.0, NSFontWeightRegular, TSStudioWhite(0.48));
    self.knobHintLabel.maximumNumberOfLines = 0;
    self.knobHintLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.knobHintLabel.hidden = YES;
    [rail addSubview:self.knobHintLabel];

    [self updateColorSwatches];
    return rail;
}

- (TSRailView *)buildAtelierRail {
    TSRailView *rail = [[TSRailView alloc] initWithFrame:NSZeroRect];
    rail.material = NSVisualEffectMaterialHUDWindow;
    rail.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    rail.state = NSVisualEffectStateActive;
    rail.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    rail.wantsLayer = YES;

    self.rightRailHairline = [[NSView alloc] initWithFrame:NSZeroRect];
    self.rightRailHairline.wantsLayer = YES;
    self.rightRailHairline.layer.backgroundColor = TSStudioWhite(0.08).CGColor;
    [rail addSubview:self.rightRailHairline];

    self.atelierScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.atelierScrollView.drawsBackground = NO;
    self.atelierScrollView.borderType = NSNoBorder;
    self.atelierScrollView.hasVerticalScroller = YES;
    self.atelierScrollView.autohidesScrollers = YES;
    self.atelierScrollView.scrollerStyle = NSScrollerStyleOverlay;
    [rail addSubview:self.atelierScrollView];

    self.atelierContent = [[TSFlippedView alloc] initWithFrame:NSMakeRect(0, 0, TSRightRailWidth, 900)];
    self.atelierScrollView.documentView = self.atelierContent;

    self.atelierTitleLabel = [self railSectionLabel:@"AI Atelier"];
    [self.atelierTitleLabel setFont:[NSFont systemFontOfSize:10.0 weight:NSFontWeightSemibold]];
    [self.atelierContent addSubview:self.atelierTitleLabel];

    self.statusDotView = [[NSView alloc] initWithFrame:NSZeroRect];
    self.statusDotView.wantsLayer = YES;
    self.statusDotView.layer.cornerRadius = 4.0;
    self.statusDotView.layer.backgroundColor = TSStudioWhite(0.25).CGColor;
    [self.atelierContent addSubview:self.statusDotView];

    self.openCodeDetailLabel = TSLabel(@"OpenCode idle · offline engine ready", 9.5, NSFontWeightRegular, TSStudioWhite(0.42));
    [self.atelierContent addSubview:self.openCodeDetailLabel];

    self.promptCard = [[TSPromptCardView alloc] initWithFrame:NSZeroRect];
    [self.atelierContent addSubview:self.promptCard];
    self.promptField = self.promptCard.promptField;
    self.promptField.placeholderString = @"Describe something to draw…  e.g. a curious cat";
    __weak typeof(self) weakSelf = self;
    self.promptField.onSubmit = ^{
        __strong typeof(weakSelf) self = weakSelf;
        [self generateSketch:nil];
    };

    NSArray<NSString *> *suggestions = [TSSketchPromptBuilder suggestedSubjects];
    NSMutableArray<TSActionButton *> *chips = [NSMutableArray array];
    for (NSString *suggestion in suggestions) {
        TSActionButton *chip = [TSActionButton buttonWithTitle:suggestion
                                                    symbolName:nil
                                                        target:self
                                                        action:@selector(applySuggestion:)];
        chip.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
        [chip setTitleText:suggestion];
        chip.fillColor = TSStudioWhite(0.055);
        chip.hoverFillColor = TSStudioWhite(0.12);
        chip.textColor = TSStudioWhite(0.72);
        [chip setTitleText:suggestion];
        [self.atelierContent addSubview:chip];
        [chips addObject:chip];
    }
    self.suggestionButtons = chips;

    self.engineSectionLabel = [self railSectionLabel:@"Engine"];
    [self.atelierContent addSubview:self.engineSectionLabel];

    self.engineControl = [NSSegmentedControl segmentedControlWithLabels:@[@"OpenCode", @"Offline"]
                                                          trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                target:self
                                                                action:@selector(engineChanged:)];
    self.engineControl.controlSize = NSControlSizeSmall;
    self.engineControl.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    NSInteger defaultEngine = [[NSUserDefaults standardUserDefaults] integerForKey:@"TSDefaultEngine"];
    self.engineControl.selectedSegment = (defaultEngine == 1) ? 1 : 0;
    [self.atelierContent addSubview:self.engineControl];

    self.modelPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.modelPopup.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
    self.modelPopup.controlSize = NSControlSizeSmall;
    self.modelPopup.target = self;
    self.modelPopup.action = @selector(modelSelectionChanged:);
    [self.atelierContent addSubview:self.modelPopup];

    self.refreshModelsButton = [TSIconButton buttonWithSymbolName:@"arrow.clockwise"
                                                           target:self
                                                           action:@selector(refreshModels:)
                                                      description:@"Refresh OpenCode models"];
    [self.atelierContent addSubview:self.refreshModelsButton];

    self.engineHintLabel = TSLabel(@"Uses the OpenCode server on this Mac. Local models run entirely offline.",
                                   10.0, NSFontWeightRegular, TSStudioWhite(0.50));
    self.engineHintLabel.maximumNumberOfLines = 0;
    self.engineHintLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.atelierContent addSubview:self.engineHintLabel];

    self.generateButton = [TSActionButton buttonWithTitle:@"Generate Sketch"
                                               symbolName:@"sparkles"
                                                   target:self
                                                   action:@selector(generateSketch:)];
    self.generateButton.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold];
    [self.generateButton setTitleText:@"Generate Sketch"];
    self.generateButton.fillColor = [NSColor colorWithSRGBRed:0.78 green:0.29 blue:0.24 alpha:0.92];
    self.generateButton.hoverFillColor = [NSColor colorWithSRGBRed:0.88 green:0.37 blue:0.30 alpha:0.98];
    [self.atelierContent addSubview:self.generateButton];

    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.controlSize = NSControlSizeSmall;
    self.progressIndicator.displayedWhenStopped = NO;
    self.progressIndicator.hidden = YES;
    [self.atelierContent addSubview:self.progressIndicator];

    self.activityLabel = TSLabel(@"", 10.0, NSFontWeightRegular, TSStudioWhite(0.56));
    [self.atelierContent addSubview:self.activityLabel];

    self.cancelButton = [TSIconButton buttonWithSymbolName:@"xmark.circle.fill"
                                                    target:self
                                                    action:@selector(cancelGeneration:)
                                               description:@"Cancel generation"];
    self.cancelButton.hidden = YES;
    [self.atelierContent addSubview:self.cancelButton];

    self.recentLabel = [self railSectionLabel:@"Recent"];
    [self.atelierContent addSubview:self.recentLabel];

    self.historyEmptyLabel = TSLabel(@"Nothing yet. Ask the atelier for a first sketch.",
                                     10.0, NSFontWeightRegular, TSStudioWhite(0.40));
    self.historyEmptyLabel.maximumNumberOfLines = 0;
    [self.atelierContent addSubview:self.historyEmptyLabel];

    self.privacyLabel = TSLabel(@"Prompts travel only to the model you choose. Offline mode never leaves your Mac.",
                                9.0, NSFontWeightRegular, TSStudioWhite(0.38));
    self.privacyLabel.maximumNumberOfLines = 0;
    self.privacyLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.atelierContent addSubview:self.privacyLabel];

    return rail;
}

#pragma mark - Layout

- (void)viewDidLayout {
    [super viewDidLayout];
    if (self.animatingRails) return;
    [self layoutChrome];
}

- (void)layoutChrome {
    CGFloat width = self.rootView.bounds.size.width;
    CGFloat height = self.rootView.bounds.size.height;
    if (width < 1 || height < 1) return;

    self.topBar.frame = NSMakeRect(0, 0, width, TSTopBarHeight);
    [self layoutTopBar];

    CGFloat leftWidth = self.toolRailVisible ? TSLeftRailWidth : 0.0;
    CGFloat rightWidth = self.atelierVisible ? TSRightRailWidth : 0.0;

    self.toolRail.hidden = !self.toolRailVisible;
    self.atelierRail.hidden = !self.atelierVisible;
    self.toolRail.frame = NSMakeRect(0, TSTopBarHeight, leftWidth, height - TSTopBarHeight);
    self.atelierRail.frame = NSMakeRect(width - rightWidth, TSTopBarHeight, rightWidth, height - TSTopBarHeight);
    self.stageView.frame = NSMakeRect(leftWidth, TSTopBarHeight,
                                      MAX(1.0, width - leftWidth - rightWidth),
                                      MAX(1.0, height - TSTopBarHeight));

    [self layoutToolRail];
    [self layoutAtelier];

    self.stageView.visibleStageRect = self.stageView.bounds;
    [self.stageView setNeedsLayout:YES];
}

- (void)layoutTopBar {
    CGFloat width = self.topBar.bounds.size.width;
    self.brandMarkView.frame = NSMakeRect(88, 16, 22, 22);
    self.brandLabel.frame = NSMakeRect(118, 18, 160, 16);

    CGFloat right = width - 16.0;
    self.atelierToggleButton.frame = NSMakeRect(right - 28.0, 13, 28, 28);
    right -= 28.0 + 6.0;
    self.toolRailToggleButton.frame = NSMakeRect(right - 28.0, 13, 28, 28);
    right -= 28.0 + 12.0;
    self.exportButton.frame = NSMakeRect(right - 96.0, 12, 96, 30);
    right -= 96.0 + 12.0;
    self.topRedoButton.frame = NSMakeRect(right - 28.0, 13, 28, 28);
    right -= 28.0 + 4.0;
    self.topUndoButton.frame = NSMakeRect(right - 28.0, 13, 28, 28);
    right -= 28.0 + 16.0;

    CGFloat leftEdge = NSMaxX(self.brandLabel.frame) + 18.0;
    CGFloat labelWidth = MAX(120.0, right - leftEdge);
    self.documentNameLabel.frame = NSMakeRect(leftEdge, 18, labelWidth, 18);
}

- (void)layoutToolRail {
    CGFloat width = self.toolRail.bounds.size.width;
    CGFloat height = self.toolRail.bounds.size.height;
    if (width < 1) return;
    self.leftRailHairline.frame = NSMakeRect(width - 1.0, 0, 1.0, height);
    CGFloat contentWidth = width - TSRailPadding * 2.0;

    NSArray<NSNumber *> *sectionY = @[@22.0, @122.0, @186.0, @273.0, @335.0];
    [self.toolRailSectionLabels enumerateObjectsUsingBlock:^(NSTextField *label, NSUInteger idx, BOOL *stop) {
        label.frame = NSMakeRect(TSRailPadding, sectionY[idx].doubleValue, contentWidth, 12);
    }];

    CGFloat toolWidth = (contentWidth - 16.0) / 3.0;
    [self.toolButtons enumerateObjectsUsingBlock:^(TSToolButton *button, NSUInteger idx, BOOL *stop) {
        button.frame = NSMakeRect(TSRailPadding + idx * (toolWidth + 8.0), 42.0, toolWidth, 64.0);
    }];

    CGFloat swatchSize = 28.0;
    CGFloat swatchGap = (contentWidth - swatchSize * self.colorSwatches.count) / MAX(1.0, (CGFloat)self.colorSwatches.count - 1.0);
    [self.colorSwatches enumerateObjectsUsingBlock:^(TSColorSwatch *swatch, NSUInteger idx, BOOL *stop) {
        swatch.frame = NSMakeRect(TSRailPadding + idx * (swatchSize + swatchGap), 142.0, swatchSize, swatchSize);
    }];

    self.widthValueLabel.frame = NSMakeRect(width - TSRailPadding - 88.0, 186.0, 88.0, 12.0);
    self.widthSlider.frame = NSMakeRect(TSRailPadding, 204.0, contentWidth, 18.0);
    self.widthPreview.frame = NSMakeRect(TSRailPadding, 229.0, contentWidth, 28.0);
    self.themeControl.frame = NSMakeRect(TSRailPadding, 293.0, contentWidth, 26.0);

    CGFloat actionWidth = (contentWidth - 6.0) / 2.0;
    self.railUndoButton.frame = NSMakeRect(TSRailPadding, 355.0, actionWidth, 30.0);
    self.railRedoButton.frame = NSMakeRect(TSRailPadding + actionWidth + 6.0, 355.0, actionWidth, 30.0);
    self.traceButton.frame = NSMakeRect(TSRailPadding, 393.0, contentWidth, 30.0);
    self.clearButton.frame = NSMakeRect(TSRailPadding, 431.0, contentWidth, 30.0);

    if (!self.knobHintLabel.hidden) {
        self.knobHintLabel.frame = NSMakeRect(TSRailPadding, 473.0, contentWidth, 34.0);
    } else {
        self.knobHintLabel.frame = NSZeroRect;
    }
}

- (void)layoutAtelier {
    CGFloat width = self.atelierRail.bounds.size.width;
    CGFloat height = self.atelierRail.bounds.size.height;
    if (width < 1) return;
    self.rightRailHairline.frame = NSMakeRect(0, 0, 1.0, height);
    self.atelierScrollView.frame = NSMakeRect(1.0, 0, width - 1.0, height);

    CGFloat viewportWidth = self.atelierScrollView.contentSize.width;
    if (viewportWidth < 10.0) viewportWidth = width - 1.0;
    CGFloat contentWidth = viewportWidth - TSRailPadding * 2.0;
    CGFloat x = TSRailPadding;
    CGFloat y = 18.0;

    self.atelierTitleLabel.frame = NSMakeRect(x, y, contentWidth - 100.0, 14.0);
    self.statusDotView.frame = NSMakeRect(viewportWidth - TSRailPadding - 8.0, y + 3.0, 8.0, 8.0);
    y += 22.0;
    self.openCodeDetailLabel.frame = NSMakeRect(x, y, contentWidth, 13.0);
    y += 24.0;

    self.promptCard.frame = NSMakeRect(x, y, contentWidth, 88.0);
    y += 96.0;

    CGFloat chipX = x;
    for (TSActionButton *chip in self.suggestionButtons) {
        CGFloat chipWidth = MAX(78.0, [chip.attributedTitle size].width + 20.0);
        chip.frame = NSMakeRect(chipX, y, chipWidth, 24.0);
        chipX += chipWidth + 6.0;
    }
    y += 32.0;

    self.engineSectionLabel.frame = NSMakeRect(x, y, contentWidth, 12.0);
    y += 18.0;
    self.engineControl.frame = NSMakeRect(x, y, contentWidth, 26.0);
    y += 34.0;

    BOOL openCodeSelected = self.engineControl.selectedSegment == 0;
    self.modelPopup.hidden = !openCodeSelected;
    self.refreshModelsButton.hidden = !openCodeSelected;
    if (openCodeSelected) {
        self.modelPopup.frame = NSMakeRect(x, y, contentWidth - 34.0, 26.0);
        self.refreshModelsButton.frame = NSMakeRect(x + contentWidth - 28.0, y, 28.0, 26.0);
    }
    y += 32.0;
    self.engineHintLabel.frame = NSMakeRect(x, y, contentWidth, 30.0);
    y += 36.0;

    self.generateButton.frame = NSMakeRect(x, y, contentWidth, 40.0);
    y += 48.0;

    CGFloat cancelWidth = self.cancelButton.hidden ? 0.0 : 30.0;
    self.progressIndicator.frame = NSMakeRect(x, y + 3.0, 14.0, 14.0);
    CGFloat activityX = self.progressIndicator.hidden ? x : x + 20.0;
    self.activityLabel.frame = NSMakeRect(activityX, y + 1.0, contentWidth - (activityX - x) - cancelWidth, 16.0);
    self.cancelButton.frame = NSMakeRect(x + contentWidth - 24.0, y - 1.0, 24.0, 24.0);
    y += 28.0;

    self.recentLabel.frame = NSMakeRect(x, y, contentWidth, 12.0);
    y += 18.0;

    if (self.historyCards.count == 0) {
        self.historyEmptyLabel.hidden = NO;
        self.historyEmptyLabel.frame = NSMakeRect(x, y, contentWidth, 16.0);
        y += 22.0;
    } else {
        self.historyEmptyLabel.hidden = YES;
        for (TSHistoryCard *card in self.historyCards) {
            card.frame = NSMakeRect(x, y, contentWidth, 54.0);
            y += 61.0;
        }
    }

    self.privacyLabel.frame = NSMakeRect(x, y + 2.0, contentWidth, 34.0);
    y += 44.0;

    CGFloat contentHeight = y + 18.0;
    CGFloat documentHeight = MAX(contentHeight, self.atelierScrollView.contentSize.height);
    self.atelierContent.frame = NSMakeRect(0, 0, viewportWidth, documentHeight);
    [self.atelierContent setNeedsDisplay:YES];
}

#pragma mark - Notifications and interface refresh

- (void)registerNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(documentDidChange:) name:TSDrawingDocumentDidChangeNotification object:self.document];
    [center addObserver:self selector:@selector(undoStateChanged:) name:NSUndoManagerDidUndoChangeNotification object:self.document.drawingUndoManager];
    [center addObserver:self selector:@selector(undoStateChanged:) name:NSUndoManagerDidRedoChangeNotification object:self.document.drawingUndoManager];
    [center addObserver:self selector:@selector(undoStateChanged:) name:NSUndoManagerDidCloseUndoGroupNotification object:self.document.drawingUndoManager];
    [center addObserver:self selector:@selector(undoStateChanged:) name:NSUndoManagerCheckpointNotification object:self.document.drawingUndoManager];
    [center addObserver:self selector:@selector(openCodeStatusChanged:) name:TSOpenCodeServiceStatusDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(openCodeModelsChanged:) name:TSOpenCodeServiceModelsDidChangeNotification object:nil];
}

- (void)refreshInterfaceFromDocument {
    TSTheme *theme = [TSTheme themeWithIdentifier:self.document.drawing.themeIdentifier];
    [self applyTheme:theme];
    self.canvasView.drawing = self.document.drawing;
    self.canvasView.strokeWidth = self.strokeWidth;
    self.canvasView.colorRole = self.selectedRole;
    self.canvasView.customColorHex = self.customColorHex;
    [self updateToolSelection];
    [self updateDocumentLabels];
    [self updateUndoButtons];
    [self updateColorSwatches];
    [self updateWidthPreview];
}

- (void)documentDidChange:(NSNotification *)notification {
    if (notification.object != self.document) return;
    TSDrawing *drawing = self.document.drawing;
    TSTheme *theme = [TSTheme themeWithIdentifier:drawing.themeIdentifier];
    if (![theme.identifier isEqualToString:self.theme.identifier]) {
        [self applyTheme:theme];
    }
    self.canvasView.drawing = drawing;
    [self updateDocumentLabels];
    [self updateUndoButtons];
}

- (void)applyTheme:(TSTheme *)theme {
    if (!theme) return;
    self.theme = theme;
    self.deviceView.theme = theme;
    self.widthPreview.theme = theme;
    NSInteger index = 0;
    for (TSTheme *candidate in [TSTheme allThemes]) {
        if ([candidate.identifier isEqualToString:theme.identifier]) {
            index = [[TSTheme allThemes] indexOfObject:candidate];
            break;
        }
    }
    self.themeControl.selectedSegment = index;
    [self updateColorSwatches];
    [self updateWidthPreview];
    for (TSHistoryCard *card in self.historyCards) {
        card.theme = theme;
    }
}

- (void)updateDocumentLabels {
    NSString *name = self.document.displayName ?: @"Untitled Sketch";
    if (self.document.isDocumentEdited) {
        name = [name stringByAppendingString:@"  •"];
    }
    self.documentNameLabel.stringValue = name;
    self.view.window.title = self.document.displayName ?: name;
}

- (void)updateUndoButtons {
    NSUndoManager *manager = self.document.drawingUndoManager;
    BOOL canUndo = manager.canUndo;
    BOOL canRedo = manager.canRedo;
    self.topUndoButton.enabled = canUndo;
    self.topRedoButton.enabled = canRedo;
    self.railUndoButton.enabled = canUndo;
    self.railRedoButton.enabled = canRedo;
}

- (void)undoStateChanged:(NSNotification *)notification {
    [self updateUndoButtons];
}

- (void)updateColorSwatches {
    for (TSColorSwatch *swatch in self.colorSwatches) {
        if (swatch.role == TSColorRoleCustom) {
            swatch.colorHex = self.customColorHex;
        } else {
            swatch.colorHex = [self.theme colorHexForRole:swatch.role];
        }
        swatch.chosen = (swatch.role == self.selectedRole);
        [swatch setNeedsDisplay:YES];
    }
    self.canvasView.colorRole = self.selectedRole;
    self.canvasView.customColorHex = self.customColorHex;
    self.widthPreview.role = self.selectedRole;
    self.widthPreview.customHex = self.customColorHex;
    [self.widthPreview setNeedsDisplay:YES];
}

- (void)updateWidthPreview {
    self.widthPreview.theme = self.theme;
    self.widthPreview.previewWidth = self.strokeWidth;
    self.widthPreview.role = self.selectedRole;
    self.widthPreview.customHex = self.customColorHex;
    self.widthValueLabel.stringValue = [NSString stringWithFormat:@"%.1f pt", self.strokeWidth];
    [self.widthPreview setNeedsDisplay:YES];
}

#pragma mark - Tools, colours and themes

- (void)selectTool:(TSToolButton *)sender {
    self.selectedToolIdentifier = sender.toolIdentifier ?: @"pen";
    [self updateToolSelection];
}

- (void)updateToolSelection {
    [self.canvasView endKnobStrokeIfNeeded];
    for (TSToolButton *button in self.toolButtons) {
        button.selected = [button.toolIdentifier isEqualToString:self.selectedToolIdentifier];
    }
    BOOL knobMode = [self.selectedToolIdentifier isEqualToString:@"knob"];
    BOOL eraser = [self.selectedToolIdentifier isEqualToString:@"eraser"];
    self.canvasView.knobMode = knobMode;
    self.canvasView.tool = eraser ? TSCanvasToolEraser : TSCanvasToolPen;
    self.knobHintLabel.hidden = !knobMode;
    [self layoutToolRail];
    [self.view.window makeFirstResponder:self.canvasView];
}

- (void)selectSwatch:(TSColorSwatch *)sender {
    self.selectedRole = sender.role;
    if (sender.role == TSColorRoleCustom) {
        [self showColorPanel];
    }
    [self updateColorSwatches];
}

- (void)showColorPanel {
    NSColorPanel *panel = [NSColorPanel sharedColorPanel];
    panel.showsAlpha = NO;
    panel.color = [NSColor ts_colorWithHex:self.customColorHex] ?: [NSColor colorWithSRGBRed:0.48 green:0.36 blue:0.66 alpha:1.0];
    panel.target = self;
    panel.action = @selector(customColorPicked:);
    [panel orderFront:nil];
}

- (void)customColorPicked:(NSColorPanel *)panel {
    NSString *hex = TSHexStringFromColor(panel.color);
    if (hex.length == 0) return;
    self.customColorHex = hex;
    self.selectedRole = TSColorRoleCustom;
    [[NSUserDefaults standardUserDefaults] setObject:hex forKey:@"TSCustomInkColor"];
    [self updateColorSwatches];
}

- (void)selectSwatchAtIndex:(NSUInteger)index {
    if (index >= self.colorSwatches.count) return;
    [self selectSwatch:self.colorSwatches[index]];
}

- (void)widthChanged:(id)sender {
    self.strokeWidth = MAX(0.6, MIN(12.0, self.widthSlider.doubleValue));
    self.canvasView.strokeWidth = self.strokeWidth;
    [self updateWidthPreview];
}

- (void)themeChanged:(NSSegmentedControl *)sender {
    NSInteger segment = sender.selectedSegment;
    NSArray<TSTheme *> *themes = [TSTheme allThemes];
    if (segment < 0 || segment >= (NSInteger)themes.count) return;
    TSTheme *theme = themes[segment];
    if ([theme.identifier isEqualToString:self.document.drawing.themeIdentifier]) {
        [self applyTheme:theme];
        return;
    }
    [self.document setThemeIdentifier:theme.identifier actionName:@"Change Screen"];
    [self applyTheme:theme];
}

- (void)applySuggestion:(TSActionButton *)sender {
    NSString *suggestion = sender.title;
    if (suggestion.length == 0) return;
    [self.promptField setPromptString:suggestion];
    [self.view.window makeFirstResponder:self.promptField];
}

#pragma mark - Undo, export and shake

- (void)undo:(id)sender {
    if (self.document.drawingUndoManager.canUndo) {
        [self.document.drawingUndoManager undo];
    }
    [self updateUndoButtons];
}

- (void)redo:(id)sender {
    if (self.document.drawingUndoManager.canRedo) {
        [self.document.drawingUndoManager redo];
    }
    [self updateUndoButtons];
}

- (UTType *)contentTypeForExportFormat:(TSExportFormat)format {
    switch (format) {
        case TSExportFormatPNG:
            return UTTypePNG;
        case TSExportFormatSVG:
            return [UTType typeWithIdentifier:@"public.svg-image"] ?: [UTType typeWithFilenameExtension:@"svg"];
        case TSExportFormatPDF:
            return UTTypePDF;
    }
    return UTTypePNG;
}

- (void)exportDrawing:(id)sender {
    [self presentExportPanelWithFormat:TSExportFormatPNG];
}

- (void)exportPNG:(id)sender {
    [self presentExportPanelWithFormat:TSExportFormatPNG];
}

- (void)exportSVG:(id)sender {
    [self presentExportPanelWithFormat:TSExportFormatSVG];
}

- (void)exportPDF:(id)sender {
    [self presentExportPanelWithFormat:TSExportFormatPDF];
}

- (void)presentExportPanelWithFormat:(TSExportFormat)format {
    if (!self.document) return;

    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"Export Sketch";
    panel.allowedContentTypes = @[[self contentTypeForExportFormat:format]];
    NSString *baseName = [self.document.displayName stringByDeletingPathExtension] ?: @"Telesketch";
    self.exportBaseName = baseName;
    panel.nameFieldStringValue = [baseName stringByAppendingPathExtension:TSExportFormatFileExtension(format)];

    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 250, 34)];
    NSTextField *label = TSLabel(@"Format", 11.5, NSFontWeightMedium, [NSColor colorWithCalibratedWhite:0.24 alpha:1.0]);
    label.frame = NSMakeRect(0, 8, 54, 18);
    [accessory addSubview:label];

    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(58, 3, 180, 26) pullsDown:NO];
    for (NSNumber *formatNumber in @[@(TSExportFormatPNG), @(TSExportFormatSVG), @(TSExportFormatPDF)]) {
        TSExportFormat candidate = (TSExportFormat)formatNumber.integerValue;
        [popup addItemWithTitle:[NSString stringWithFormat:@"%@ — %@",
                                 TSExportFormatDisplayName(candidate),
                                 [self exportFormatDescription:candidate]]];
    }
    [popup selectItemAtIndex:format];
    popup.target = self;
    popup.action = @selector(exportFormatChanged:);
    [accessory addSubview:popup];

    self.activeExportPanel = panel;
    self.exportFormatPopup = popup;
    panel.accessoryView = accessory;

    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || result != NSModalResponseOK || !panel.URL) return;
        NSInteger index = self.exportFormatPopup.indexOfSelectedItem;
        TSExportFormat selected = (index >= 0 && index <= TSExportFormatPDF) ? (TSExportFormat)index : format;
        NSURL *url = panel.URL;
        NSString *extension = TSExportFormatFileExtension(selected);
        if (![url.pathExtension.lowercaseString isEqualToString:extension]) {
            url = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:extension];
        }
        NSError *error = nil;
        BOOL success = NO;
        switch (selected) {
            case TSExportFormatPNG:
                success = [self.document exportPNGToURL:url error:&error];
                break;
            case TSExportFormatSVG:
                success = [self.document exportSVGToURL:url error:&error];
                break;
            case TSExportFormatPDF:
                success = [self.document exportPDFToURL:url error:&error];
                break;
        }
        if (!success) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        } else {
            [self setActivityMessage:[NSString stringWithFormat:@"Exported %@", url.lastPathComponent] error:NO];
        }
        self.activeExportPanel = nil;
        self.exportFormatPopup = nil;
    }];
}

- (NSString *)exportFormatDescription:(TSExportFormat)format {
    switch (format) {
        case TSExportFormatPNG: return @"raster image";
        case TSExportFormatSVG: return @"vector, editable";
        case TSExportFormatPDF: return @"vector document";
    }
    return @"";
}

- (void)exportFormatChanged:(NSPopUpButton *)sender {
    NSSavePanel *panel = self.activeExportPanel;
    if (!panel) return;
    NSInteger index = sender.indexOfSelectedItem;
    if (index < 0 || index > TSExportFormatPDF) return;
    TSExportFormat format = (TSExportFormat)index;
    panel.allowedContentTypes = @[[self contentTypeForExportFormat:format]];
    NSString *base = self.exportBaseName.length > 0 ? self.exportBaseName : @"Telesketch";
    panel.nameFieldStringValue = [base stringByAppendingPathExtension:TSExportFormatFileExtension(format)];
}

- (void)traceImage:(id)sender {
    if (!self.document || self.generating) return;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"Trace an Image";
    panel.message = @"Choose a photo or drawing. Telesketch will trace its outlines into ink strokes.";
    panel.allowedContentTypes = @[UTTypeImage];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || result != NSModalResponseOK || !panel.URL) return;
        [self beginTracingImageAtURL:panel.URL];
    }];
}

- (void)beginTracingImageAtURL:(NSURL *)url {
    if (!self.document || self.generating) return;
    self.generating = YES;
    self.generationToken++;
    NSInteger token = self.generationToken;
    [self updateGeneratingInterfaceWithMessage:@"Tracing outlines into ink…"];

    TSTheme *theme = self.theme;
    NSString *title = url.lastPathComponent.stringByDeletingPathExtension;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *traceError = nil;
        TSDrawing *drawing = [TSImageTracer drawingFromImageAtURL:url
                                                            theme:theme
                                                            title:title
                                                            error:&traceError];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || token != self.generationToken) return;
            if (!drawing) {
                self.generating = NO;
                [self updateGeneratingInterfaceWithMessage:nil];
                [self setActivityMessage:traceError.localizedDescription ?: @"Could not trace that image." error:YES];
                NSAlert *alert = [[NSAlert alloc] init];
                alert.alertStyle = NSAlertStyleWarning;
                alert.messageText = @"The image couldn't be traced.";
                alert.informativeText = traceError.localizedDescription ?: @"No usable outlines were found.";
                [alert addButtonWithTitle:@"Dismiss"];
                [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
                return;
            }
            [self finishGenerationWithDrawing:drawing source:@"Traced image"];
        });
    });
}

- (void)shakeToClear:(id)sender {
    if (!self.document || self.document.drawing.isEmpty) {
        [[NSHapticFeedbackManager defaultPerformer] performFeedbackPattern:NSHapticFeedbackPatternAlignment
                                                         performanceTime:NSHapticFeedbackPerformanceTimeNow];
        return;
    }
    [[NSHapticFeedbackManager defaultPerformer] performFeedbackPattern:NSHapticFeedbackPatternGeneric
                                                     performanceTime:NSHapticFeedbackPerformanceTimeNow];
    BOOL reduceMotion = [NSWorkspace sharedWorkspace].accessibilityDisplayShouldReduceMotion;
    BOOL shakeEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"TSShakeAnimation"];
    TSDrawing *empty = [TSDrawing emptyDrawingWithThemeIdentifier:self.theme.identifier];
    if (reduceMotion || !shakeEnabled) {
        [self.document applyDrawing:empty actionName:@"Clear"];
        return;
    }

    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@0, @-9, @8, @-6, @4, @0];
    shake.keyTimes = @[@0, @0.15, @0.32, @0.50, @0.72, @1.0];
    shake.duration = 0.42;
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    CAKeyframeAnimation *rotate = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotate.values = @[@0, @-0.012, @0.010, @-0.007, @0.004, @0];
    rotate.duration = 0.42;
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[shake, rotate];
    group.duration = 0.42;
    [self.deviceView.layer addAnimation:group forKey:@"TSDeviceShake"];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.20;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        self.canvasView.animator.alphaValue = 0.0;
    } completionHandler:^{
        [self.document applyDrawing:empty actionName:@"Clear"];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.26;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            self.canvasView.animator.alphaValue = 1.0;
        } completionHandler:nil];
    }];
}

#pragma mark - Canvas delegate

- (void)canvasView:(TSCanvasView *)canvasView didCommitStroke:(TSStroke *)stroke {
    if (!self.document) return;
    TSDrawing *updated = [self.document.drawing drawingByAddingStroke:stroke];
    [self.document applyDrawing:updated actionName:@"Draw"];
}

- (void)canvasView:(TSCanvasView *)canvasView didEraseStroke:(TSStroke *)stroke {
    if (!self.document) return;
    TSDrawing *updated = [self.document.drawing drawingByRemovingStroke:stroke];
    [self.document applyDrawing:updated actionName:@"Erase"];
}

#pragma mark - Rail visibility and keyboard

- (void)toggleToolRail:(id)sender {
    self.toolRailVisible = !self.toolRailVisible;
    [self animateRails];
}

- (void)toggleAtelier:(id)sender {
    self.atelierVisible = !self.atelierVisible;
    [self animateRails];
}

- (void)animateRails {
    BOOL reduceMotion = [NSWorkspace sharedWorkspace].accessibilityDisplayShouldReduceMotion;
    CGFloat width = self.rootView.bounds.size.width;
    CGFloat height = self.rootView.bounds.size.height;
    CGFloat leftWidth = self.toolRailVisible ? TSLeftRailWidth : 0.0;
    CGFloat rightWidth = self.atelierVisible ? TSRightRailWidth : 0.0;
    NSRect stageFinal = NSMakeRect(leftWidth, TSTopBarHeight,
                                   MAX(1.0, width - leftWidth - rightWidth),
                                   MAX(1.0, height - TSTopBarHeight));
    NSRect leftFinal = self.toolRailVisible
        ? NSMakeRect(0, TSTopBarHeight, TSLeftRailWidth, height - TSTopBarHeight)
        : NSMakeRect(-TSLeftRailWidth, TSTopBarHeight, TSLeftRailWidth, height - TSTopBarHeight);
    NSRect rightFinal = self.atelierVisible
        ? NSMakeRect(width - TSRightRailWidth, TSTopBarHeight, TSRightRailWidth, height - TSTopBarHeight)
        : NSMakeRect(width, TSTopBarHeight, TSRightRailWidth, height - TSTopBarHeight);

    self.toolRail.hidden = NO;
    self.atelierRail.hidden = NO;
    self.animatingRails = YES;
    self.stageView.visibleStageRect = stageFinal;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = reduceMotion ? 0.01 : 0.30;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        self.toolRail.animator.frame = leftFinal;
        self.atelierRail.animator.frame = rightFinal;
        self.stageView.animator.frame = stageFinal;
    } completionHandler:^{
        self.animatingRails = NO;
        self.toolRail.hidden = !self.toolRailVisible;
        self.atelierRail.hidden = !self.atelierVisible;
        [self layoutChrome];
        [self.stageView setNeedsLayout:YES];
        [self.stageView layoutSubtreeIfNeeded];
    }];
}

- (void)installKeyMonitor {
    if (self.didInstallKeyMonitor) return;
    self.didInstallKeyMonitor = YES;
    __weak typeof(self) weakSelf = self;
    self.keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent *event) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || event.window != self.view.window) return event;
        NSResponder *firstResponder = self.view.window.firstResponder;
        BOOL editingText = [firstResponder isKindOfClass:[NSTextView class]] || [firstResponder isKindOfClass:[NSTextField class]];
        if (editingText) {
            if (event.keyCode == 53 && self.generating) {
                [self cancelGeneration:nil];
                return nil;
            }
            return event;
        }
        if (event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) {
            return event;
        }
        NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
        if (event.keyCode == 53) {
            if (self.generating) {
                [self cancelGeneration:nil];
            } else {
                [self.canvasView cancelReveal];
            }
            return nil;
        }
        if ([characters isEqualToString:@"b"]) {
            [self selectToolByIdentifier:@"pen"];
            return nil;
        }
        if ([characters isEqualToString:@"e"]) {
            [self selectToolByIdentifier:@"eraser"];
            return nil;
        }
        if ([characters isEqualToString:@"k"]) {
            [self selectToolByIdentifier:@"knob"];
            return nil;
        }
        if ([characters isEqualToString:@"["] || [characters isEqualToString:@"]"]) {
            CGFloat delta = [characters isEqualToString:@"["] ? -0.5 : 0.5;
            self.widthSlider.doubleValue = MAX(0.6, MIN(12.0, self.widthSlider.doubleValue + delta));
            [self widthChanged:nil];
            return nil;
        }
        if (characters.length == 1) {
            unichar c = [characters characterAtIndex:0];
            if (c >= '1' && c <= '6') {
                [self selectSwatchAtIndex:c - '1'];
                return nil;
            }
        }
        return event;
    }];
}

- (void)selectToolByIdentifier:(NSString *)identifier {
    for (TSToolButton *button in self.toolButtons) {
        if ([button.toolIdentifier isEqualToString:identifier]) {
            [self selectTool:button];
            return;
        }
    }
}

- (void)selectPen:(id)sender { [self selectToolByIdentifier:@"pen"]; }
- (void)selectEraser:(id)sender { [self selectToolByIdentifier:@"eraser"]; }
- (void)toggleKnobMode:(id)sender {
    NSString *next = [self.selectedToolIdentifier isEqualToString:@"knob"] ? @"pen" : @"knob";
    [self selectToolByIdentifier:next];
}

- (void)prepareForWindowClose {
    if (self.didPrepareClose) return;
    self.didPrepareClose = YES;
    self.generationToken++;
    [[TSOpenCodeService sharedService] cancelCurrentGeneration];
    if (self.keyMonitor) {
        [NSEvent removeMonitor:self.keyMonitor];
        self.keyMonitor = nil;
    }
}

- (void)cancelOperation:(id)sender {
    if (self.generating) {
        [self cancelGeneration:nil];
    } else {
        [self.canvasView cancelReveal];
    }
}

#pragma mark - Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    if (action == @selector(undo:)) return self.document.drawingUndoManager.canUndo;
    if (action == @selector(redo:)) return self.document.drawingUndoManager.canRedo;
    if (action == @selector(generateWithAI:) || action == @selector(generateOffline:)) {
        return !self.generating;
    }
    if (action == @selector(exportPNG:) || action == @selector(exportSVG:) || action == @selector(exportPDF:)) {
        return self.document != nil;
    }
    if (action == @selector(traceImage:)) {
        return self.document != nil && !self.generating;
    }
    if (action == @selector(toggleToolRail:)) {
        menuItem.title = self.toolRailVisible ? @"Hide Tool Rail" : @"Show Tool Rail";
        menuItem.state = self.toolRailVisible ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(toggleAtelier:)) {
        menuItem.title = self.atelierVisible ? @"Hide AI Atelier" : @"Show AI Atelier";
        menuItem.state = self.atelierVisible ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(toggleKnobMode:)) {
        menuItem.state = [self.selectedToolIdentifier isEqualToString:@"knob"] ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    return YES;
}

#pragma mark - OpenCode status and models

- (void)openCodeStatusChanged:(NSNotification *)notification {
    [self updateOpenCodeInterface];
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    if (service.status == TSOpenCodeStatusReady) {
        [self rebuildModelMenu];
    }
}

- (void)openCodeModelsChanged:(NSNotification *)notification {
    [self rebuildModelMenu];
    [self updateOpenCodeInterface];
}

- (void)updateOpenCodeInterface {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    NSColor *dotColor = TSStudioWhite(0.24);
    NSString *detail = nil;

    BOOL offline = self.engineControl.selectedSegment == 1;
    if (offline) {
        dotColor = [NSColor colorWithSRGBRed:0.35 green:0.58 blue:0.48 alpha:1.0];
        detail = @"Offline · built-in parametric engine ready";
    } else {
        switch (service.status) {
            case TSOpenCodeStatusStopped:
                dotColor = TSStudioWhite(0.24);
                detail = @"OpenCode idle · press Generate to start the server.";
                break;
            case TSOpenCodeStatusStarting:
                dotColor = [NSColor colorWithSRGBRed:0.72 green:0.55 blue:0.25 alpha:1.0];
                detail = @"Starting opencode serve · capturing URL and password…";
                break;
            case TSOpenCodeStatusReady: {
                dotColor = [NSColor colorWithSRGBRed:0.32 green:0.68 blue:0.44 alpha:1.0];
                NSString *countText = service.models.count == 1 ? @"1 model" : [NSString stringWithFormat:@"%lu models", (unsigned long)service.models.count];
                detail = [NSString stringWithFormat:@"Connected · %@ · %@ · auth from server", [service connectionSummary], countText];
                break;
            }
            case TSOpenCodeStatusFailed:
                dotColor = [NSColor colorWithSRGBRed:0.80 green:0.31 blue:0.26 alpha:1.0];
                detail = service.lastError.length > 0 ? service.lastError : @"OpenCode is unavailable.";
                break;
        }
    }

    self.statusDotView.layer.backgroundColor = dotColor.CGColor;
    self.openCodeDetailLabel.stringValue = detail ?: @"";
    self.openCodeDetailLabel.toolTip = detail;
    self.openCodeDetailLabel.textColor = (service.status == TSOpenCodeStatusFailed && !offline)
        ? [NSColor colorWithSRGBRed:0.86 green:0.47 blue:0.41 alpha:0.95]
        : TSStudioWhite(0.46);
}

- (void)rebuildModelMenu {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    NSArray<TSOpenCodeModel *> *models = service.models;
    [self.modelPopup removeAllItems];

    if (models.count == 0) {
        [self.modelPopup addItemWithTitle:@"No models available"];
        self.modelPopup.enabled = NO;
        self.modelPopup.toolTip = @"OpenCode has not reported any chat models yet.";
        return;
    }

    self.modelPopup.enabled = YES;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Models"];
    NSString *lastProvider = nil;
    for (TSOpenCodeModel *model in models) {
        if (![model.providerName isEqualToString:lastProvider]) {
            if (lastProvider.length > 0) {
                [menu addItem:[NSMenuItem separatorItem]];
            }
            NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:model.providerName.uppercaseString
                                                            action:nil
                                                     keyEquivalent:@""];
            header.enabled = NO;
            [menu addItem:header];
            lastProvider = model.providerName;
        }
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[model compactDisplayName]
                                                      action:nil
                                               keyEquivalent:@""];
        item.representedObject = model;
        [menu addItem:item];
    }
    [self.modelPopup setMenu:menu];

    NSMenuItem *match = nil;
    NSMenuItem *first = nil;
    for (NSMenuItem *item in menu.itemArray) {
        if (![item.representedObject isKindOfClass:[TSOpenCodeModel class]]) continue;
        if (!first) first = item;
        if (item.representedObject == service.preferredModel) {
            match = item;
            break;
        }
    }
    if (!match) match = first;
    if (match) {
        [self.modelPopup selectItem:match];
        TSOpenCodeModel *model = match.representedObject;
        self.modelPopup.toolTip = [model displayName];
    }
}

- (nullable TSOpenCodeModel *)selectedModel {
    id object = self.modelPopup.selectedItem.representedObject;
    return [object isKindOfClass:[TSOpenCodeModel class]] ? object : nil;
}

- (void)modelSelectionChanged:(NSPopUpButton *)sender {
    TSOpenCodeModel *model = [self selectedModel];
    if (!model) return;
    [[TSOpenCodeService sharedService] selectModel:model];
    self.modelPopup.toolTip = [model displayName];
    [self setActivityMessage:[NSString stringWithFormat:@"Model set to %@", [model compactDisplayName]] error:NO];
}

- (void)requestOpenCodeStartIfNeeded {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    if (service.status == TSOpenCodeStatusReady || service.status == TSOpenCodeStatusStarting) {
        [self updateOpenCodeInterface];
        if (service.status == TSOpenCodeStatusReady) {
            [self rebuildModelMenu];
        }
        return;
    }
    self.didRequestOpenCodeStart = YES;
    [self updateOpenCodeInterface];
    __weak typeof(self) weakSelf = self;
    [service startWithCompletion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self updateOpenCodeInterface];
        if (error) {
            [self setActivityMessage:error.localizedDescription error:YES];
        } else {
            [self rebuildModelMenu];
        }
    }];
}

- (void)refreshModels:(id)sender {
    self.engineControl.selectedSegment = 0;
    [self updateEngineAppearance];
    [self setActivityMessage:@"Refreshing OpenCode models…" error:NO];
    __weak typeof(self) weakSelf = self;
    [[TSOpenCodeService sharedService] refreshModelsWithCompletion:^(NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self updateOpenCodeInterface];
        if (error) {
            [self setActivityMessage:error.localizedDescription error:YES];
        } else {
            [self rebuildModelMenu];
            [self setActivityMessage:@"Models refreshed from OpenCode." error:NO];
        }
    }];
}

- (void)engineChanged:(NSSegmentedControl *)sender {
    if (self.generating) {
        [self cancelGeneration:nil];
    }
    BOOL offline = self.engineControl.selectedSegment == 1;
    [[NSUserDefaults standardUserDefaults] setInteger:(offline ? 1 : 0) forKey:@"TSDefaultEngine"];
    [self updateEngineAppearance];
    [self updateOpenCodeInterface];
    if (!offline) {
        [self requestOpenCodeStartIfNeeded];
    }
}

- (void)updateEngineAppearance {
    BOOL offline = self.engineControl.selectedSegment == 1;
    [self.generateButton setTitleText:offline ? @"Generate Offline" : @"Generate Sketch"];
    self.engineHintLabel.stringValue = offline
        ? @"Built-in parametric engine. Deterministic hand-drawn scenes, no network and no model required."
        : @"Models come from your OpenCode server. Local models are marked Local and run entirely offline.";
    self.modelPopup.hidden = offline;
    self.refreshModelsButton.hidden = offline;
    [self layoutAtelier];
}

#pragma mark - Generation

- (void)generateWithAI:(id)sender {
    self.engineControl.selectedSegment = 0;
    [self updateEngineAppearance];
    [self generateSketch:sender];
}

- (void)generateOffline:(id)sender {
    self.engineControl.selectedSegment = 1;
    [self updateEngineAppearance];
    [self generateSketch:sender];
}

- (void)generateSketch:(id)sender {
    if (self.generating) return;
    NSString *prompt = [self.promptField.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (prompt.length == 0) {
        [self setActivityMessage:@"Describe something to draw first." error:YES];
        [self.view.window makeFirstResponder:self.promptField];
        NSBeep();
        return;
    }
    if (self.engineControl.selectedSegment == 1) {
        [self generateOfflineWithPrompt:prompt];
    } else {
        [self generateWithOpenCodePrompt:prompt repair:NO];
    }
}

- (void)generateWithOpenCodePrompt:(NSString *)prompt repair:(BOOL)repair {
    [self generateWithOpenCodePrompt:prompt repair:repair localFallbackAttempted:NO];
}

- (void)generateWithOpenCodePrompt:(NSString *)prompt
                            repair:(BOOL)repair
             localFallbackAttempted:(BOOL)localFallbackAttempted {
    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    TSOpenCodeModel *model = [self selectedModel] ?: service.preferredModel;

    if (!repair) {
        self.generating = YES;
        self.generationToken++;
        [self updateGeneratingInterfaceWithMessage:@"Warming up the atelier…"];
        [self updateOpenCodeInterface];
        if (service.status != TSOpenCodeStatusReady) {
            [self requestOpenCodeStartIfNeeded];
        }
    } else {
        [self updateGeneratingInterfaceWithMessage:@"Tidying the lines…"];
    }

    NSInteger token = self.generationToken;
    NSString *requestPrompt = repair
        ? [TSSketchPromptBuilder repairPromptForSubject:prompt theme:self.theme]
        : [TSSketchPromptBuilder promptForSubject:prompt theme:self.theme];

    __weak typeof(self) weakSelf = self;
    [service generateTextForPrompt:requestPrompt model:model completion:^(NSString *text, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || token != self.generationToken) return;

        if (error) {
            if ([error.domain isEqualToString:TSOpenCodeErrorDomain] && error.code == TSOpenCodeErrorCancelled) {
                self.generating = NO;
                [self updateGeneratingInterfaceWithMessage:nil];
                [self setActivityMessage:@"Generation cancelled." error:NO];
                return;
            }
            // A saved free cloud model can be exhausted while a local Ollama model is
            // ready. Switching automatically keeps the atelier drawing instead of
            // dead-ending on the provider's quota.
            if (!localFallbackAttempted &&
                [error.domain isEqualToString:TSOpenCodeErrorDomain] &&
                error.code == TSOpenCodeErrorQuota &&
                !model.localModel) {
                TSOpenCodeModel *localModel = [self localFallbackModel];
                if (localModel) {
                    [service selectModel:localModel];
                    [self rebuildModelMenu];
                    [self generateWithOpenCodePrompt:prompt
                                              repair:NO
                               localFallbackAttempted:YES];
                    [self setActivityMessage:[NSString stringWithFormat:
                        @"Free model limit reached. Switched to local %@.", localModel.name] error:NO];
                    return;
                }
            }
            [self presentGenerationFailure:error.localizedDescription detail:nil prompt:prompt];
            return;
        }

        NSError *parseError = nil;
        TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:self.theme error:&parseError];
        if (!drawing) {
            if (!repair) {
                [self generateWithOpenCodePrompt:prompt repair:YES localFallbackAttempted:localFallbackAttempted];
                return;
            }
            [self presentGenerationFailure:@"The model returned something that wasn't a drawing."
                                    detail:parseError.localizedDescription
                                    prompt:prompt];
            return;
        }

        NSString *modelName = model.name.length > 0 ? model.name : @"OpenCode";
        if (localFallbackAttempted) {
            modelName = [modelName stringByAppendingString:@" · local fallback"];
        }
        [self finishGenerationWithDrawing:drawing source:[NSString stringWithFormat:@"OpenCode · %@", modelName]];
    }];
}

- (nullable TSOpenCodeModel *)localFallbackModel {
    TSOpenCodeModel *firstLocal = nil;
    for (TSOpenCodeModel *model in [TSOpenCodeService sharedService].models) {
        if (!model.localModel) continue;
        if ([model.providerID isEqualToString:@"ollama"]) {
            return model;
        }
        if (!firstLocal) firstLocal = model;
    }
    return firstLocal;
}

- (void)generateOfflineWithPrompt:(NSString *)prompt {
    self.generating = YES;
    self.generationToken++;
    NSInteger token = self.generationToken;
    [self updateGeneratingInterfaceWithMessage:@"Composing an offline sketch…"];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.38 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || token != self.generationToken) return;
        uint64_t seed = (uint64_t)([[NSDate date] timeIntervalSince1970] * 1000.0) ^ (uint64_t)prompt.hash;
        TSDrawing *drawing = [TSOfflineSketchEngine drawingForPrompt:prompt theme:self.theme seed:seed];
        [self finishGenerationWithDrawing:drawing source:@"Built-in engine"];
    });
}

- (void)finishGenerationWithDrawing:(TSDrawing *)drawing source:(NSString *)source {
    self.generating = NO;
    TSDrawing *themedDrawing = [drawing drawingWithThemeIdentifier:self.theme.identifier];
    [self.document applyDrawing:themedDrawing actionName:@"Generate Sketch"];
    [self addRecentDrawing:themedDrawing];
    [self updateGeneratingInterfaceWithMessage:nil];
    [self.canvasView beginRevealWithDrawing:themedDrawing
                                   duration:[self revealDurationForDrawing:themedDrawing]];
    [self setActivityMessage:[NSString stringWithFormat:@"%@ · %lu strokes",
                              source, (unsigned long)themedDrawing.strokes.count] error:NO];
    [self updateDocumentLabels];
    [self layoutAtelier];
}

- (NSTimeInterval)revealDurationForDrawing:(TSDrawing *)drawing {
    NSUInteger points = [drawing totalPointCount];
    NSTimeInterval duration = 0.55 + MIN(1.55, (double)points * 0.006);
    return MAX(0.6, MIN(2.2, duration));
}

- (void)cancelGeneration:(id)sender {
    if (!self.generating) return;
    self.generationToken++;
    [[TSOpenCodeService sharedService] cancelCurrentGeneration];
    self.generating = NO;
    [self updateGeneratingInterfaceWithMessage:nil];
    [self setActivityMessage:@"Generation cancelled." error:NO];
}

- (void)presentGenerationFailure:(NSString *)message detail:(NSString *)detail prompt:(NSString *)prompt {
    self.generating = NO;
    [self updateGeneratingInterfaceWithMessage:nil];
    [self setActivityMessage:message error:YES];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"The atelier couldn't finish that sketch.";
    NSString *informative = message ?: @"Unknown error.";
    if (detail.length > 0) {
        NSString *trimmed = detail.length > 600 ? [[detail substringToIndex:600] stringByAppendingString:@"…"] : detail;
        informative = [informative stringByAppendingFormat:@"\n\n%@", trimmed];
    }
    alert.informativeText = informative;
    [alert addButtonWithTitle:@"Try Offline"];
    [alert addButtonWithTitle:@"Dismiss"];
    __weak typeof(self) weakSelf = self;
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse response) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (response == NSAlertFirstButtonReturn) {
            self.engineControl.selectedSegment = 1;
            [self updateEngineAppearance];
            [self updateOpenCodeInterface];
            [self generateOfflineWithPrompt:prompt];
        }
    }];
}

- (void)updateGeneratingInterfaceWithMessage:(NSString *)message {
    self.generateButton.enabled = !self.generating;
    self.progressIndicator.hidden = !self.generating;
    self.cancelButton.hidden = !self.generating;
    if (self.generating) {
        [self.progressIndicator startAnimation:nil];
    } else {
        [self.progressIndicator stopAnimation:nil];
    }
    if (message.length > 0) {
        [self setActivityMessage:message error:NO];
    }
    [self layoutAtelier];
}

- (void)setActivityMessage:(NSString *)message error:(BOOL)isError {
    self.activityLabel.stringValue = message ?: @"";
    self.activityLabel.textColor = isError
        ? [NSColor colorWithSRGBRed:0.88 green:0.48 blue:0.42 alpha:0.95]
        : TSStudioWhite(0.56);
    self.activityLabel.toolTip = message;
    [self layoutAtelier];
}

#pragma mark - Recent sketches

- (void)addRecentDrawing:(TSDrawing *)drawing {
    if (!drawing) return;
    [self.recentDrawings insertObject:drawing atIndex:0];
    while (self.recentDrawings.count > 5) {
        [self.recentDrawings removeLastObject];
    }
    [self rebuildHistoryCards];
    [self layoutAtelier];
}

- (void)rebuildHistoryCards {
    for (TSHistoryCard *card in self.historyCards) {
        [card removeFromSuperview];
    }
    [self.historyCards removeAllObjects];

    for (TSDrawing *drawing in self.recentDrawings) {
        TSHistoryCard *card = [[TSHistoryCard alloc] initWithFrame:NSZeroRect];
        card.drawing = drawing;
        card.theme = self.theme;
        card.target = self;
        card.action = @selector(historyCardClicked:);
        card.toolTip = [NSString stringWithFormat:@"Re-apply %@", drawing.title];
        [self.atelierContent addSubview:card];
        [self.historyCards addObject:card];
    }
    [self layoutAtelier];
}

- (void)historyCardClicked:(TSHistoryCard *)card {
    TSDrawing *drawing = card.drawing;
    if (!drawing || !self.document) return;
    TSDrawing *themed = [drawing drawingWithThemeIdentifier:self.theme.identifier];
    [self.document applyDrawing:themed actionName:@"Reapply Sketch"];
    [self.canvasView beginRevealWithDrawing:themed duration:[self revealDurationForDrawing:themed]];
    [self setActivityMessage:[NSString stringWithFormat:@"%@ · %lu strokes",
                              themed.title, (unsigned long)themed.strokes.count] error:NO];
}

@end
