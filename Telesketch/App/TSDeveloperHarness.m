#import "TSDeveloperHarness.h"
#import "TSMainViewController.h"
#import "TSDrawingDocument.h"
#import "TSPromptField.h"
#import "TSOpenCodeService.h"
#import "TSSketchPromptBuilder.h"
#import "TSSketchParser.h"
#import "TSTheme.h"

@protocol TSDeveloperHarnessActions <NSObject>
- (void)generateOffline:(nullable id)sender;
- (void)generateWithAI:(nullable id)sender;
@end

@interface TSDeveloperHarness ()
+ (void)scheduleUISmokeTest;
+ (void)runUISmokeInWindow:(NSWindow *)window;
+ (void)pollUISmokeWithController:(TSMainViewController *)controller startDate:(NSDate *)startDate;
@end

@implementation TSDeveloperHarness

+ (void)runIfRequested {
    NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
    NSString *capturePath = environment[@"TS_CAPTURE_SCREENSHOT"];
    NSString *smokeTest = environment[@"TS_SMOKE_OPENCODE"];
    NSString *productionSmoke = environment[@"TS_SMOKE_PRODUCTION"];
    NSString *uiSmoke = environment[@"TS_SMOKE_UI"];
    if (capturePath.length > 0) {
        [self scheduleCaptureAtPath:capturePath];
    } else if (productionSmoke.boolValue) {
        [self scheduleOpenCodeProductionSmokeTest];
    } else if (uiSmoke.boolValue) {
        [self scheduleUISmokeTest];
    } else if (smokeTest.boolValue) {
        [self scheduleOpenCodeSmokeTest];
    }
}

#pragma mark - Window capture

+ (void)scheduleCaptureAtPath:(NSString *)path {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSWindow *window = [self mainDocumentWindow];
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                NSWindow *retryWindow = [self mainDocumentWindow];
                if (retryWindow) {
                    [self prepareShowcaseInWindow:retryWindow path:path];
                } else {
                    fprintf(stderr, "TS_CAPTURE_SCREENSHOT: no document window found\n");
                    [NSApp terminate:nil];
                }
            });
            return;
        }
        [self prepareShowcaseInWindow:window path:path];
    });
}

+ (void)prepareShowcaseInWindow:(NSWindow *)window path:(NSString *)path {
    TSMainViewController *controller = (TSMainViewController *)window.contentViewController;
    TSPromptField *promptField = [self promptFieldInView:controller.view];
    [promptField setPromptString:@"a curious cat"];

    [NSApp sendAction:@selector(generateOffline:) to:controller from:nil];

    // Let the reveal animation finish and the atelier status settle before capture.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        BOOL written = [self writePNGOfWindow:window toPath:path];
        if (written) {
            fprintf(stdout, "TS_CAPTURE_SCREENSHOT: wrote %s\n", path.UTF8String);
            fflush(stdout);
        } else {
            fprintf(stderr, "TS_CAPTURE_SCREENSHOT: could not write %s\n", path.UTF8String);
        }
        TSDrawingDocument *document = (TSDrawingDocument *)window.windowController.document;
        [document updateChangeCount:NSChangeCleared];
        [NSApp terminate:nil];
    });
}

+ (nullable NSWindow *)mainDocumentWindow {
    for (NSWindow *window in NSApp.windows) {
        if (window.isVisible && [window.contentViewController isKindOfClass:[TSMainViewController class]]) {
            return window;
        }
    }
    return nil;
}

+ (nullable TSPromptField *)promptFieldInView:(NSView *)view {
    if ([view isKindOfClass:[TSPromptField class]]) {
        return (TSPromptField *)view;
    }
    for (NSView *subview in view.subviews) {
        TSPromptField *found = [self promptFieldInView:subview];
        if (found) return found;
    }
    return nil;
}

+ (BOOL)writePNGOfWindow:(NSWindow *)window toPath:(NSString *)path {
    NSString *directory = path.stringByDeletingLastPathComponent;
    if (directory.length > 0) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    }

    NSView *view = window.contentView;
    NSBitmapImageRep *representation = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    if (!representation) return NO;
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:representation];

    NSData *png = [representation representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:path atomically:YES];
}

#pragma mark - OpenCode smoke test

+ (void)scheduleOpenCodeSmokeTest {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Fail the run rather than hanging forever if the helper never answers.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(240.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            fprintf(stderr, "TS_SMOKE_OPENCODE: timed out\n");
            fflush(stderr);
            exit(4);
        });

        TSOpenCodeService *service = [TSOpenCodeService sharedService];
        [service startWithCompletion:^(NSError *error) {
            if (error) {
                fprintf(stderr, "TS_SMOKE_OPENCODE: start failed: %s\n",
                        error.localizedDescription.UTF8String);
                fflush(stderr);
                exit(2);
            }
            fprintf(stdout, "TS_SMOKE_OPENCODE: server=%s user=%s passwordCaptured=%s\n",
                    service.serverURLString.UTF8String ?: "(nil)",
                    service.serverUsername.UTF8String ?: "(nil)",
                    service.serverPassword.length > 0 ? "yes" : "no");
            fflush(stdout);

            [service refreshModelsWithCompletion:^(NSError *modelsError) {
                if (modelsError) {
                    fprintf(stderr, "TS_SMOKE_OPENCODE: models failed: %s\n",
                            modelsError.localizedDescription.UTF8String);
                    fflush(stderr);
                    [service shutdown];
                    exit(3);
                }

                TSOpenCodeModel *localModel = nil;
                for (TSOpenCodeModel *model in service.models) {
                    fprintf(stdout, "TS_SMOKE_OPENCODE: model=%s provider=%s local=%d\n",
                            model.identifier.UTF8String ?: "(nil)",
                            model.providerID.UTF8String ?: "(nil)",
                            model.localModel ? 1 : 0);
                    if (model.localModel && !localModel) localModel = model;
                }
                fflush(stdout);
                if (!localModel) {
                    fprintf(stderr, "TS_SMOKE_OPENCODE: no local model available\n");
                    fflush(stderr);
                    [service shutdown];
                    exit(3);
                }

                [service selectModel:localModel];
                TSTheme *theme = [TSTheme themeWithIdentifier:@"classic"];
                [self smokeGenerateWithService:service model:localModel theme:theme repair:NO];
            }];
        }];
    });
}

/// A deliberately tiny prompt keeps the integration smoke test focused on the
/// server, auth, generation and parser path rather than 3B-model artistry.
+ (NSString *)smokePrompt {
    return @"Return ONLY one minified JSON object for a simple cat sketch. No markdown. No commentary.\n"
            "Use exactly 2 strokes with 3 points each in this shape:\n"
            "{\"title\":\"Cat\",\"strokes\":[{\"color\":\"#2B2E2C\",\"width\":3,\"points\":[[0.30,0.30],[0.35,0.25],[0.40,0.30]]},{\"color\":\"#2B2E2C\",\"width\":3,\"points\":[[0.45,0.35],[0.50,0.40],[0.55,0.45]]}]}\n"
            "Stop after the final closing brace.";
}

+ (void)smokeGenerateWithService:(TSOpenCodeService *)service
                           model:(TSOpenCodeModel *)model
                           theme:(TSTheme *)theme
                          repair:(BOOL)repair {
    NSString *prompt = [self smokePrompt];
    [service generateTextForPrompt:prompt model:model completion:^(NSString *text, NSError *error) {
        if (error) {
            fprintf(stderr, "TS_SMOKE_OPENCODE: generation failed: %s\n",
                    error.localizedDescription.UTF8String);
            fflush(stderr);
            [service shutdown];
            exit(5);
        }
        NSError *parseError = nil;
        TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:theme error:&parseError];
        if (!drawing && !repair) {
            fprintf(stderr, "TS_SMOKE_OPENCODE: parse failed (%s); retrying once\n",
                    parseError.localizedDescription.UTF8String);
            fflush(stderr);
            [self smokeGenerateWithService:service model:model theme:theme repair:YES];
            return;
        }
        if (!drawing) {
            fprintf(stderr, "TS_SMOKE_OPENCODE: parse failed: %s\n",
                    parseError.localizedDescription.UTF8String);
            fprintf(stderr, "TS_SMOKE_OPENCODE: raw text: %s\n", text.UTF8String ?: "(nil)");
            fflush(stderr);
            [service shutdown];
            exit(6);
        }
        fprintf(stdout, "TS_SMOKE_OPENCODE: parsed title='%s' strokes=%lu points=%lu\n",
                drawing.title.UTF8String ?: "",
                (unsigned long)drawing.strokes.count,
                (unsigned long)[drawing totalPointCount]);
        fflush(stdout);
        [service shutdown];
        exit(0);
    }];
}

#pragma mark - Production prompt smoke test

+ (void)scheduleOpenCodeProductionSmokeTest {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
        NSInteger attempts = MAX(1, MIN(5, [environment[@"TS_SMOKE_PRODUCTION_ATTEMPTS"] integerValue] ?: 1));
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300.0 * attempts * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            fprintf(stderr, "TS_SMOKE_PRODUCTION: timed out\n");
            fflush(stderr);
            exit(4);
        });

        TSOpenCodeService *service = [TSOpenCodeService sharedService];
        [service startWithCompletion:^(NSError *error) {
            if (error) {
                fprintf(stderr, "TS_SMOKE_PRODUCTION: start failed: %s\n",
                        error.localizedDescription.UTF8String);
                fflush(stderr);
                exit(2);
            }
            fprintf(stdout, "TS_SMOKE_PRODUCTION: server=%s external=%d\n",
                    service.serverURLString.UTF8String ?: "(nil)",
                    service.usesExternalServer ? 1 : 0);
            fflush(stdout);

            [service refreshModelsWithCompletion:^(NSError *modelsError) {
                if (modelsError) {
                    fprintf(stderr, "TS_SMOKE_PRODUCTION: models failed: %s\n",
                            modelsError.localizedDescription.UTF8String);
                    fflush(stderr);
                    [service shutdown];
                    exit(3);
                }
                TSOpenCodeModel *localModel = nil;
                for (TSOpenCodeModel *model in service.models) {
                    if (model.localModel && [model.providerID isEqualToString:@"ollama"]) {
                        localModel = model;
                        break;
                    }
                }
                if (!localModel) {
                    fprintf(stderr, "TS_SMOKE_PRODUCTION: no local Ollama model available\n");
                    fflush(stderr);
                    [service shutdown];
                    exit(3);
                }
                [service selectModel:localModel];
                TSTheme *theme = [TSTheme themeWithIdentifier:@"classic"];
                NSString *subject = environment[@"TS_SMOKE_SUBJECT"] ?: @"a curious cat";
                fprintf(stdout, "TS_SMOKE_PRODUCTION: model=%s attempts=%ld subject=%s\n",
                        localModel.identifier.UTF8String ?: "",
                        (long)attempts,
                        subject.UTF8String ?: "");
                fflush(stdout);
                [self productionAttempt:1
                                ofTotal:attempts
                                service:service
                                  model:localModel
                                  theme:theme
                                subject:subject
                                 repair:NO];
            }];
        }];
    });
}

+ (void)productionAttempt:(NSInteger)attempt
                  ofTotal:(NSInteger)total
                  service:(TSOpenCodeService *)service
                    model:(TSOpenCodeModel *)model
                    theme:(TSTheme *)theme
                  subject:(NSString *)subject
                   repair:(BOOL)repair {
    NSString *prompt = repair
        ? [TSSketchPromptBuilder repairPromptForSubject:subject theme:theme]
        : [TSSketchPromptBuilder promptForSubject:subject theme:theme];
    NSString *stage = repair ? @"repair" : @"primary";

    [service generateTextForPrompt:prompt model:model completion:^(NSString *text, NSError *error) {
        if (error) {
            fprintf(stderr, "TS_SMOKE_PRODUCTION: attempt %ld %s generation failed: %s\n",
                    (long)attempt, stage.UTF8String,
                    error.localizedDescription.UTF8String);
            fflush(stderr);
            [service shutdown];
            exit(5);
        }

        NSString *timestamp = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
        NSString *rawPath = [NSString stringWithFormat:@"/tmp/ts-production-smoke-%@-%ld-%@.txt",
                             timestamp, (long)attempt, stage];
        [text writeToFile:rawPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        NSError *parseError = nil;
        TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:theme error:&parseError];
        if (!drawing && !repair) {
            fprintf(stdout, "TS_SMOKE_PRODUCTION: attempt %ld primary parse failed (%s); retrying with repair prompt\n",
                    (long)attempt,
                    parseError.localizedDescription.UTF8String ?: "unknown");
            fflush(stdout);
            [self productionAttempt:attempt
                            ofTotal:total
                            service:service
                              model:model
                              theme:theme
                            subject:subject
                             repair:YES];
            return;
        }
        if (!drawing) {
            fprintf(stderr, "TS_SMOKE_PRODUCTION: attempt %ld repair parse failed: %s\n",
                    (long)attempt,
                    parseError.localizedDescription.UTF8String ?: "unknown");
            fprintf(stderr, "TS_SMOKE_PRODUCTION: raw output saved to %s\n", rawPath.UTF8String);
            fflush(stderr);
            [service shutdown];
            exit(6);
        }

        fprintf(stdout, "TS_SMOKE_PRODUCTION: attempt %ld/%ld parsed title='%s' strokes=%lu points=%lu stage=%s\n",
                (long)attempt, (long)total,
                drawing.title.UTF8String ?: "",
                (unsigned long)drawing.strokes.count,
                (unsigned long)[drawing totalPointCount],
                stage.UTF8String);
        fflush(stdout);

        if (attempt < total) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self productionAttempt:attempt + 1
                                ofTotal:total
                                service:service
                                  model:model
                                  theme:theme
                                subject:subject
                                 repair:NO];
            });
            return;
        }

        [service shutdown];
        exit(0);
    }];
}

#pragma mark - Atelier UI fallback smoke test

+ (void)scheduleUISmokeTest {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSWindow *window = [self mainDocumentWindow];
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                NSWindow *retryWindow = [self mainDocumentWindow];
                if (retryWindow) {
                    [self runUISmokeInWindow:retryWindow];
                } else {
                    fprintf(stderr, "TS_SMOKE_UI: no document window found\n");
                    fflush(stderr);
                    exit(2);
                }
            });
            return;
        }
        [self runUISmokeInWindow:window];
    });
}

+ (void)runUISmokeInWindow:(NSWindow *)window {
    TSMainViewController *controller = (TSMainViewController *)window.contentViewController;
    TSPromptField *promptField = [self promptFieldInView:controller.view];
    if (!promptField) {
        fprintf(stderr, "TS_SMOKE_UI: prompt field not found\n");
        fflush(stderr);
        exit(2);
    }
    [promptField setPromptString:@"a curious cat"];
    [window makeKeyAndOrderFront:nil];

    TSOpenCodeService *service = [TSOpenCodeService sharedService];
    [service startWithCompletion:^(NSError *startError) {
        if (startError) {
            fprintf(stderr, "TS_SMOKE_UI: start failed: %s\n",
                    startError.localizedDescription.UTF8String);
            fflush(stderr);
            exit(3);
        }
        [service refreshModelsWithCompletion:^(NSError *modelsError) {
            if (modelsError) {
                fprintf(stderr, "TS_SMOKE_UI: models failed: %s\n",
                        modelsError.localizedDescription.UTF8String);
                fflush(stderr);
                [service shutdown];
                exit(3);
            }
            TSOpenCodeModel *cloudModel = nil;
            for (TSOpenCodeModel *model in service.models) {
                if (!model.localModel && model.freeModel) {
                    cloudModel = model;
                    break;
                }
            }
            if (!cloudModel) {
                fprintf(stderr, "TS_SMOKE_UI: no free cloud model available\n");
                fflush(stderr);
                [service shutdown];
                exit(3);
            }
            [service selectModel:cloudModel];
            fprintf(stdout, "TS_SMOKE_UI: selected cloud model=%s provider=%s\n",
                    cloudModel.identifier.UTF8String ?: "",
                    cloudModel.providerID.UTF8String ?: "");
            fflush(stdout);

            [NSApp sendAction:@selector(generateWithAI:) to:controller from:nil];
            [self pollUISmokeWithController:controller startDate:[NSDate date]];
        }];
    }];
}

+ (void)pollUISmokeWithController:(TSMainViewController *)controller startDate:(NSDate *)startDate {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSDate *now = [NSDate date];
        NSTimeInterval elapsed = [now timeIntervalSinceDate:startDate];
        BOOL generating = [[controller valueForKey:@"generating"] boolValue];
        TSDrawingDocument *document = [controller valueForKey:@"document"];
        NSUInteger strokes = document.drawing.strokes.count;
        NSUInteger points = [document.drawing totalPointCount];
        NSTextField *activityLabel = [controller valueForKey:@"activityLabel"];
        NSString *activity = activityLabel.stringValue ?: @"";

        if (!generating && strokes > 0) {
            TSOpenCodeService *service = [TSOpenCodeService sharedService];
            fprintf(stdout, "TS_SMOKE_UI: success model=%s strokes=%lu points=%lu activity='%s'\n",
                    service.preferredModel.identifier.UTF8String ?: "",
                    (unsigned long)strokes,
                    (unsigned long)points,
                    activity.UTF8String);
            fflush(stdout);
            [service shutdown];
            exit(0);
        }
        if (!generating && elapsed > 4.0) {
            fprintf(stderr, "TS_SMOKE_UI: no drawing after %.1fs activity='%s'\n",
                    elapsed, activity.UTF8String);
            fflush(stderr);
            [[TSOpenCodeService sharedService] shutdown];
            exit(7);
        }
        if (elapsed > 240.0) {
            fprintf(stderr, "TS_SMOKE_UI: timed out\n");
            fflush(stderr);
            [[TSOpenCodeService sharedService] shutdown];
            exit(8);
        }
        [self pollUISmokeWithController:controller startDate:startDate];
    });
}

@end
