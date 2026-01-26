#import <Cocoa/Cocoa.h>
#import "TSTheme.h"
#import "TSCanvasView.h"
#import "TSKnobView.h"

NS_ASSUME_NONNULL_BEGIN

/// The photoreal aluminium Telesketch device: body, recessed screen, hardware
/// knobs and etched markings. The screen canvas and glass overlay are subviews.
@interface TSDeviceView : NSView <TSKnobViewDelegate>

@property (nonatomic, strong) TSCanvasView *canvasView;
@property (nonatomic, strong) TSKnobView *horizontalKnob;
@property (nonatomic, strong) TSKnobView *verticalKnob;
@property (nonatomic, strong) TSTheme *theme;
@property (nonatomic, readonly) NSRect screenRect;
@property (nonatomic, assign, getter=isShaking) BOOL shaking;

- (void)refreshAppearance;

@end

NS_ASSUME_NONNULL_END
