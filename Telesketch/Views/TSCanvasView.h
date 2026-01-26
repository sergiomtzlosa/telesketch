#import <Cocoa/Cocoa.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

@class TSCanvasView;

typedef NS_ENUM(NSInteger, TSCanvasTool) {
    TSCanvasToolPen = 0,
    TSCanvasToolEraser
};

@protocol TSCanvasViewDelegate <NSObject>
- (void)canvasView:(TSCanvasView *)canvasView didCommitStroke:(TSStroke *)stroke;
- (void)canvasView:(TSCanvasView *)canvasView didEraseStroke:(TSStroke *)stroke;
@end

@interface TSCanvasView : NSView

@property (nonatomic, strong, nullable) TSDrawing *drawing;
@property (nonatomic, strong) TSTheme *theme;
@property (nonatomic, weak, nullable) id<TSCanvasViewDelegate> delegate;

@property (nonatomic, assign) BOOL knobMode;
@property (nonatomic, assign) TSCanvasTool tool;
@property (nonatomic, assign) TSColorRole colorRole;
@property (nonatomic, copy) NSString *customColorHex;
@property (nonatomic, assign) CGFloat strokeWidth;

@property (nonatomic, readonly) BOOL isRevealing;

- (void)beginRevealWithDrawing:(TSDrawing *)drawing duration:(NSTimeInterval)duration;
- (void)cancelReveal;
- (void)endKnobStrokeIfNeeded;
- (void)invalidateDrawingCache;

- (void)knobDidBeginTurn;
- (void)knobDidTurnByRadians:(CGFloat)radians isHorizontal:(BOOL)horizontal;
- (void)knobDidEndTurn;

@end

NS_ASSUME_NONNULL_END
