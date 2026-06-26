#import <Cocoa/Cocoa.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const TSDrawingDocumentDidChangeNotification;

@interface TSDrawingDocument : NSDocument

@property (nonatomic, copy, readonly) TSDrawing *drawing;
@property (nonatomic, strong, readonly) NSUndoManager *drawingUndoManager;

- (void)applyDrawing:(TSDrawing *)drawing actionName:(NSString *)actionName;
- (void)setThemeIdentifier:(NSString *)themeIdentifier actionName:(NSString *)actionName;
- (BOOL)exportPNGToURL:(NSURL *)url error:(NSError **)error;
- (BOOL)exportSVGToURL:(NSURL *)url error:(NSError **)error;
- (BOOL)exportPDFToURL:(NSURL *)url error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
