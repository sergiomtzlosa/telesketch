#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class TSKnobView;

typedef NS_ENUM(NSInteger, TSKnobAxis) {
    TSKnobAxisHorizontal = 0,
    TSKnobAxisVertical
};

@protocol TSKnobViewDelegate <NSObject>
- (void)knobViewDidBeginTurning:(TSKnobView *)knobView;
- (void)knobView:(TSKnobView *)knobView didTurnByRadians:(CGFloat)radians;
- (void)knobViewDidEndTurning:(TSKnobView *)knobView;
@end

/// A tactile, anodised vermilion knob that can be dragged to drive the stylus.
@interface TSKnobView : NSView

@property (nonatomic, assign) TSKnobAxis axis;
@property (nonatomic, assign) CGFloat angle;
@property (nonatomic, copy, nullable) NSString *caption;
@property (nonatomic, weak, nullable) id<TSKnobViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
