#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface TSToolButton : NSButton

@property (nonatomic, strong, readonly) NSString *toolIdentifier;
@property (nonatomic, assign, getter=isSelected) BOOL selected;

+ (instancetype)buttonWithIdentifier:(NSString *)identifier
                               title:(NSString *)title
                          symbolName:(NSString *)symbolName
                              target:(nullable id)target
                              action:(nullable SEL)action;

@end

NS_ASSUME_NONNULL_END
