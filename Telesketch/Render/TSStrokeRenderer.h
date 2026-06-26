#import <Cocoa/Cocoa.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface TSStrokeRenderer : NSObject

+ (NSColor *)colorForStroke:(TSStroke *)stroke theme:(TSTheme *)theme;
+ (NSBezierPath *)pathForVertices:(NSArray<TSVertex *> *)vertices inRect:(NSRect)rect;
+ (void)drawStroke:(TSStroke *)stroke inRect:(NSRect)rect theme:(TSTheme *)theme;
+ (void)drawStrokes:(NSArray<TSStroke *> *)strokes inRect:(NSRect)rect theme:(TSTheme *)theme;
+ (void)drawDrawing:(TSDrawing *)drawing inRect:(NSRect)rect theme:(TSTheme *)theme;
+ (void)drawScreenBackgroundInRect:(NSRect)rect theme:(TSTheme *)theme;
/// A clean opaque screen tint for vector PDF output. Quartz renders alpha
/// gradients as opaque black in PDFs and quantises NSGradient shadings into
/// visible bands, so print exports use the theme's flat paper colour.
+ (void)drawVectorBackgroundInRect:(NSRect)rect theme:(TSTheme *)theme;
+ (void)drawPlotterTipAtPoint:(NSPoint)point color:(NSColor *)color scale:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
