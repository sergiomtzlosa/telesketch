#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class TSDrawingDocument;

@interface TSMainWindowController : NSWindowController <NSWindowDelegate>

- (instancetype)initWithDocument:(TSDrawingDocument *)document;

@end

NS_ASSUME_NONNULL_END
