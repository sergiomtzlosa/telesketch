#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSActionButton : NSButton

@property (nonatomic, strong) NSColor *fillColor;
@property (nonatomic, strong) NSColor *hoverFillColor;
@property (nonatomic, strong) NSColor *textColor;
@property (nonatomic, assign) BOOL destructive;

+ (instancetype)buttonWithTitle:(NSString *)title
                     symbolName:(nullable NSString *)symbolName
                         target:(nullable id)target
                         action:(nullable SEL)action;

- (void)setTitleText:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
