#import <Foundation/Foundation.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

/// Turns model text (JSON, optionally wrapped in prose or markdown fences) into a drawing.
@interface TSSketchParser : NSObject

+ (nullable TSDrawing *)drawingFromModelText:(NSString *)text
                                       theme:(TSTheme *)theme
                                       error:(NSError **)error;

/// Extracts the first balanced JSON object or array from arbitrary text.
+ (nullable id)extractJSONValueFromText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
