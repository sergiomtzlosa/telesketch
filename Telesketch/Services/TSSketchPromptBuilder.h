#import <Foundation/Foundation.h>
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface TSSketchPromptBuilder : NSObject

+ (NSString *)promptForSubject:(NSString *)subject theme:(TSTheme *)theme;
+ (NSString *)repairPromptForSubject:(NSString *)subject theme:(TSTheme *)theme;
+ (NSArray<NSString *> *)suggestedSubjects;

@end

NS_ASSUME_NONNULL_END
