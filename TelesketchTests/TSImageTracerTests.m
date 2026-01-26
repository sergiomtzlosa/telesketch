#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "TSImageTracer.h"
#import "TSDrawing.h"
#import "TSTheme.h"

@interface TSImageTracerTests : XCTestCase
@end

@implementation TSImageTracerTests

- (NSURL *)temporaryURLWithExtension:(NSString *)extension {
    NSString *name = [NSString stringWithFormat:@"telesketch-trace-%@.%@", [NSUUID UUID].UUIDString, extension];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

- (NSURL *)writeTestImage {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                      pixelsWide:600
                                                                      pixelsHigh:450
                                                                   bitsPerSample:8
                                                                 samplesPerPixel:4
                                                                        hasAlpha:YES
                                                                        isPlanar:NO
                                                                  colorSpaceName:NSCalibratedRGBColorSpace
                                                                     bytesPerRow:0
                                                                    bitsPerPixel:0];
    bitmap.size = NSMakeSize(600, 450);
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [[NSColor whiteColor] setFill];
    NSRectFill(NSMakeRect(0, 0, 600, 450));

    [[NSColor blackColor] setStroke];
    NSBezierPath *frame = [NSBezierPath bezierPathWithRect:NSMakeRect(150, 110, 300, 230)];
    frame.lineWidth = 9.0;
    [frame stroke];
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(235, 160, 130, 130)];
    circle.lineWidth = 7.0;
    [circle stroke];
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSURL *url = [self temporaryURLWithExtension:@"png"];
    XCTAssertTrue([png writeToURL:url options:NSDataWritingAtomic error:NULL]);
    return url;
}

- (void)testTracesImageIntoBoundedStrokes {
    NSURL *url = [self writeTestImage];
    NSError *error = nil;
    TSDrawing *drawing = [TSImageTracer drawingFromImageAtURL:url
                                                       theme:[TSTheme themeWithIdentifier:@"classic"]
                                                       title:@"Test Shape"
                                                       error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    XCTAssertEqualObjects(drawing.title, @"Test Shape");
    XCTAssertGreaterThanOrEqual(drawing.strokes.count, 2u);
    XCTAssertLessThanOrEqual(drawing.strokes.count, 90u);
    XCTAssertEqualWithAccuracy(drawing.aspect, 4.0 / 3.0, 0.001);
    XCTAssertEqualObjects(drawing.themeIdentifier, @"classic");
    for (TSStroke *stroke in drawing.strokes) {
        XCTAssertEqualObjects(stroke.tool, @"trace");
        XCTAssertEqual(stroke.role, TSColorRoleInk);
        for (TSVertex *vertex in stroke.vertices) {
            XCTAssertGreaterThanOrEqual(vertex.x, 0.0);
            XCTAssertLessThanOrEqual(vertex.x, 1.0);
            XCTAssertGreaterThanOrEqual(vertex.y, 0.0);
            XCTAssertLessThanOrEqual(vertex.y, 1.0);
        }
    }
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

- (void)testTraceRejectsMissingFile {
    NSError *error = nil;
    TSDrawing *drawing = [TSImageTracer drawingFromImageAtURL:[self temporaryURLWithExtension:@"png"]
                                                       theme:[TSTheme defaultTheme]
                                                       title:nil
                                                       error:&error];
    XCTAssertNil(drawing);
    XCTAssertNotNil(error);
}

@end
