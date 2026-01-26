#import <Foundation/Foundation.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

/// Turns a bitmap into normal Telesketch strokes using Vision's contour
/// detector. The traced image is aspect-fit into the drawing's 4:3 screen.
@interface TSImageTracer : NSObject

+ (nullable TSDrawing *)drawingFromImageAtURL:(NSURL *)url
                                        theme:(TSTheme *)theme
                                        title:(nullable NSString *)title
                                        error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
