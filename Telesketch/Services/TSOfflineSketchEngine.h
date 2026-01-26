#import <Foundation/Foundation.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

/// A deterministic, fully offline generative sketch engine.
/// The same prompt + seed always produces the same drawing.
@interface TSOfflineSketchEngine : NSObject

+ (TSDrawing *)drawingForPrompt:(NSString *)prompt theme:(TSTheme *)theme seed:(uint64_t)seed;
+ (NSArray<NSString *> *)sceneNames;

@end

NS_ASSUME_NONNULL_END
