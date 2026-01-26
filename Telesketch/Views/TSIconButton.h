#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSIconButton : NSButton

+ (instancetype)buttonWithSymbolName:(NSString *)symbolName
                              target:(nullable id)target
                              action:(nullable SEL)action
                         description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END
