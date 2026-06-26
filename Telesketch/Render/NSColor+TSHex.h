#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (TSHex)
+ (nullable NSColor *)ts_colorWithHex:(NSString *)hex;
+ (nullable NSColor *)ts_colorWithHex:(NSString *)hex alpha:(CGFloat)alpha;
- (NSString *)ts_hexString;
@end

NS_ASSUME_NONNULL_END
