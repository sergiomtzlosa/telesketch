#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Multi-line prompt field with placeholder text, a character limit and a
/// command-return submit callback.
@interface TSPromptField : NSTextView

@property (nonatomic, copy) NSString *placeholderString;
@property (nonatomic, assign) NSUInteger characterLimit;
@property (nonatomic, copy, nullable) void (^onSubmit)(void);

- (void)setPromptString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
