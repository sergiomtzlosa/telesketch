#import <Cocoa/Cocoa.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

/// A small recent-sketch card with a live-rendered thumbnail.
@interface TSHistoryCard : NSButton

@property (nonatomic, strong, nullable) TSDrawing *drawing;
@property (nonatomic, strong, nullable) TSTheme *theme;

@end

NS_ASSUME_NONNULL_END
