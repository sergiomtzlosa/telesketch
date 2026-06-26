#import "TSDrawingDocument.h"
#import "TSImageExporter.h"
#import "TSMainWindowController.h"

NSNotificationName const TSDrawingDocumentDidChangeNotification = @"TSDrawingDocumentDidChangeNotification";

@interface TSDrawingDocument ()
@property (nonatomic, copy, readwrite) TSDrawing *drawing;
@property (nonatomic, strong, readwrite) NSUndoManager *drawingUndoManager;
@end

@implementation TSDrawingDocument

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *theme = [defaults stringForKey:@"TSDefaultTheme"] ?: @"classic";
        _drawing = [TSDrawing emptyDrawingWithThemeIdentifier:theme];
        _drawingUndoManager = [[NSUndoManager alloc] init];
        _drawingUndoManager.levelsOfUndo = 60;
        _drawingUndoManager.groupsByEvent = YES;
        self.hasUndoManager = YES;
    }
    return self;
}

- (NSUndoManager *)undoManager {
    return self.drawingUndoManager;
}

- (void)makeWindowControllers {
    TSMainWindowController *windowController = [[TSMainWindowController alloc] initWithDocument:self];
    [self addWindowController:windowController];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    return [self.drawing JSONDataWithError:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    TSDrawing *drawing = [TSDrawing drawingWithJSONData:data error:outError];
    if (!drawing) {
        return NO;
    }
    self.drawing = drawing;
    [self.drawingUndoManager removeAllActions];
    [self notifyChange];
    return YES;
}

- (BOOL)isEntireFileLoaded {
    return YES;
}

- (NSString *)displayName {
    NSString *name = [super displayName];
    if (name.length == 0 || [name isEqualToString:@"Untitled"]) {
        return self.drawing.title.length > 0 ? self.drawing.title : @"Untitled Sketch";
    }
    return name;
}

- (void)applyDrawing:(TSDrawing *)drawing actionName:(NSString *)actionName {
    if (!drawing) return;
    TSDrawing *oldDrawing = self.drawing;
    if (oldDrawing == drawing) return;

    [self.drawingUndoManager beginUndoGrouping];
    [[self.drawingUndoManager prepareWithInvocationTarget:self] restoreDrawing:oldDrawing actionName:actionName ?: @"Change"];
    [self.drawingUndoManager setActionName:actionName ?: @"Change"];
    [self.drawingUndoManager endUndoGrouping];

    self.drawing = drawing;
    [self updateChangeCount:NSChangeDone];
    [self notifyChange];
}

- (void)restoreDrawing:(TSDrawing *)drawing actionName:(NSString *)actionName {
    if (!drawing) return;
    TSDrawing *oldDrawing = self.drawing;
    if (oldDrawing == drawing) return;
    [[self.drawingUndoManager prepareWithInvocationTarget:self] restoreDrawing:oldDrawing actionName:actionName];
    [self.drawingUndoManager setActionName:actionName ?: @"Change"];
    self.drawing = drawing;
    NSDocumentChangeType changeType = NSChangeDone;
    if (self.drawingUndoManager.isUndoing) {
        changeType = NSChangeUndone;
    } else if (self.drawingUndoManager.isRedoing) {
        changeType = NSChangeRedone;
    }
    [self updateChangeCount:changeType];
    [self notifyChange];
}

- (void)setThemeIdentifier:(NSString *)themeIdentifier actionName:(NSString *)actionName {
    if (themeIdentifier.length == 0) return;
    if ([self.drawing.themeIdentifier isEqualToString:themeIdentifier]) return;
    TSDrawing *updated = [self.drawing drawingWithThemeIdentifier:themeIdentifier];
    [self applyDrawing:updated actionName:actionName ?: @"Change Screen"];
}

- (BOOL)exportPNGToURL:(NSURL *)url error:(NSError **)error {
    TSTheme *theme = [TSTheme themeWithIdentifier:self.drawing.themeIdentifier];
    CGFloat width = 2000.0;
    CGFloat height = width / MAX(0.1, self.drawing.aspect);
    return [TSImageExporter writePNGForDrawing:self.drawing
                                        theme:theme
                                        toURL:url
                                    pixelSize:NSMakeSize(width, height)
                                        error:error];
}

- (BOOL)exportSVGToURL:(NSURL *)url error:(NSError **)error {
    TSTheme *theme = [TSTheme themeWithIdentifier:self.drawing.themeIdentifier];
    return [TSImageExporter writeSVGForDrawing:self.drawing
                                        theme:theme
                                        toURL:url
                                        error:error];
}

- (BOOL)exportPDFToURL:(NSURL *)url error:(NSError **)error {
    TSTheme *theme = [TSTheme themeWithIdentifier:self.drawing.themeIdentifier];
    CGFloat width = 1440.0;
    CGFloat height = width / MAX(0.1, self.drawing.aspect);
    return [TSImageExporter writePDFForDrawing:self.drawing
                                        theme:theme
                                        toURL:url
                                     pageSize:NSMakeSize(width, height)
                                        error:error];
}

- (void)notifyChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:TSDrawingDocumentDidChangeNotification object:self];
}

- (void)close {
    [self.drawingUndoManager removeAllActions];
    [super close];
}

@end
