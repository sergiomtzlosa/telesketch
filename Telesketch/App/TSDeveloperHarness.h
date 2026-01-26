#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Developer-only automation used to capture documentation screenshots and to
/// smoke-test the OpenCode integration without accessibility permissions.
///
/// The harness is inert unless launched with one of these environment variables:
///   TS_CAPTURE_SCREENSHOT=/absolute/path.png   render the main window to PNG
///   TS_SMOKE_OPENCODE=1                        start OpenCode, list models,
///                                              generate a sketch with a local
///                                              model, parse the result and quit
///   TS_SMOKE_PRODUCTION=1                      exercise the real atelier prompt
///                                              (and one repair retry) with a
///                                              local model; raw output goes to
///                                              /tmp/ts-production-smoke-*.txt
///   TS_SMOKE_PRODUCTION_ATTEMPTS=3             number of production attempts
///   TS_SMOKE_SUBJECT="a curious cat"           subject for production mode
///   TS_SMOKE_UI=1                              drive the real atelier UI with a
///                                              free cloud model, verify it falls
///                                              back to a local model and that the
///                                              document receives strokes
@interface TSDeveloperHarness : NSObject

+ (void)runIfRequested;

@end

NS_ASSUME_NONNULL_END
