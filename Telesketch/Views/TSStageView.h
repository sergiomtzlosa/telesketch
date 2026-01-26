#import <Cocoa/Cocoa.h>
#import "TSDeviceView.h"

NS_ASSUME_NONNULL_BEGIN

/// The studio stage: a smoked-oak desk, a dark green leather mat and the
/// aluminium Telesketch device.
@interface TSStageView : NSView

@property (nonatomic, strong) TSDeviceView *deviceView;

/// Frame of the middle column that remains visible between the rails.
@property (nonatomic, assign) NSRect visibleStageRect;

@end

NS_ASSUME_NONNULL_END
