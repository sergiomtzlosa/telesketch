#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Builds the application's main menu entirely in code. Kept separate from the
/// delegate so menu structure is easy to audit and adjust.
@interface TSMainMenu : NSObject

+ (NSMenu *)buildMainMenu;

@end

NS_ASSUME_NONNULL_END
