#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class TSDrawingDocument;

@interface TSMainViewController : NSViewController <NSMenuItemValidation>

- (instancetype)initWithDocument:(TSDrawingDocument *)document;

- (void)prepareForWindowClose;

@end

NS_ASSUME_NONNULL_END
