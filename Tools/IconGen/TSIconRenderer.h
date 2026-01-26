#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Draws the Telesketch app icon entirely with AppKit primitives.
@interface TSIconRenderer : NSObject

+ (nullable NSData *)PNGDataWithSize:(CGFloat)size;

@end

NS_ASSUME_NONNULL_END
