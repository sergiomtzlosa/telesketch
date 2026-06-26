#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "TSImageExporter.h"
#import "TSOfflineSketchEngine.h"
#import "TSDrawing.h"
#import "TSTheme.h"

@interface TSImageExporterTests : XCTestCase
@end

@implementation TSImageExporterTests

- (NSURL *)temporaryURLWithExtension:(NSString *)extension {
    NSString *name = [NSString stringWithFormat:@"telesketch-test-%@.%@", [NSUUID UUID].UUIDString, extension];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

- (TSDrawing *)rocketDrawing {
    TSTheme *theme = [TSTheme themeWithIdentifier:@"classic"];
    return [TSOfflineSketchEngine drawingForPrompt:@"rocket" theme:theme seed:17];
}

- (void)testExportsValidPNGAtRequestedSize {
    TSTheme *theme = [TSTheme themeWithIdentifier:@"classic"];
    TSDrawing *drawing = [self rocketDrawing];
    NSURL *url = [self temporaryURLWithExtension:@"png"];
    NSError *error = nil;

    BOOL success = [TSImageExporter writePNGForDrawing:drawing
                                                theme:theme
                                                toURL:url
                                            pixelSize:NSMakeSize(1200, 900)
                                                error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:url.path]);

    NSData *data = [NSData dataWithContentsOfURL:url];
    XCTAssertNotNil(data);
    XCTAssertGreaterThan(data.length, 1000u);

    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:data];
    XCTAssertNotNil(rep);
    XCTAssertEqual(rep.pixelsWide, 1200);
    XCTAssertEqual(rep.pixelsHigh, 900);

    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

- (void)testExportAspectComesFromDrawing {
    TSTheme *theme = [TSTheme themeWithIdentifier:@"blueprint"];
    TSDrawing *drawing = [[TSDrawing alloc] initWithTitle:@"Wide"
                                                   aspect:2.0
                                        themeIdentifier:@"blueprint"
                                                 strokes:@[]];
    NSURL *url = [self temporaryURLWithExtension:@"png"];
    BOOL success = [TSImageExporter writePNGForDrawing:drawing
                                                theme:theme
                                                toURL:url
                                            pixelSize:NSMakeSize(1000, 999)
                                                error:NULL];
    XCTAssertTrue(success);
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[NSData dataWithContentsOfURL:url]];
    XCTAssertNotNil(rep);
    XCTAssertEqual(rep.pixelsWide, 1000);
    XCTAssertEqual(rep.pixelsHigh, 500);
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

- (void)testExportsParsableSVGWithVectorStrokes {
    TSTheme *theme = [TSTheme themeWithIdentifier:@"classic"];
    TSDrawing *drawing = [self rocketDrawing];
    NSURL *url = [self temporaryURLWithExtension:@"svg"];
    NSError *error = nil;

    BOOL success = [TSImageExporter writeSVGForDrawing:drawing
                                                theme:theme
                                                toURL:url
                                                error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);

    NSData *data = [NSData dataWithContentsOfURL:url];
    XCTAssertNotNil(data);
    XCTAssertGreaterThan(data.length, 1000u);
    NSString *svgSource = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertTrue([svgSource hasPrefix:@"<?xml"]);

    NSError *xmlError = nil;
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:data options:0 error:&xmlError];
    XCTAssertNotNil(document);
    XCTAssertNil(xmlError);
    XCTAssertEqualObjects(document.rootElement.name, @"svg");
    XCTAssertTrue([document.rootElement attributeForName:@"viewBox"] != nil);
    XCTAssertTrue([document.rootElement attributeForName:@"width"] != nil);

    NSString *xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertGreaterThan([xml componentsSeparatedByString:@"<path"].count, 2);
    XCTAssertTrue([xml containsString:@"stroke-linecap=\"round\""]);

    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

- (void)testExportsVectorPDFWithMatchingAspect {
    TSTheme *theme = [TSTheme themeWithIdentifier:@"midnight"];
    TSDrawing *drawing = [self rocketDrawing];
    NSURL *url = [self temporaryURLWithExtension:@"pdf"];
    NSError *error = nil;

    BOOL success = [TSImageExporter writePDFForDrawing:drawing
                                                theme:theme
                                                toURL:url
                                             pageSize:NSMakeSize(1440, 1080)
                                                error:&error];
    XCTAssertTrue(success);
    XCTAssertNil(error);

    NSData *data = [NSData dataWithContentsOfURL:url];
    XCTAssertNotNil(data);
    XCTAssertGreaterThan(data.length, 2000u);
    NSData *headerData = [data subdataWithRange:NSMakeRange(0, 4)];
    NSString *header = [[NSString alloc] initWithData:headerData encoding:NSASCIIStringEncoding];
    XCTAssertEqualObjects(header, @"%PDF");

    NSPDFImageRep *rep = [NSPDFImageRep imageRepWithData:data];
    XCTAssertNotNil(rep);
    XCTAssertEqual(rep.pageCount, 1);
    XCTAssertEqualWithAccuracy(rep.size.width, 1440.0, 1.0);
    XCTAssertEqualWithAccuracy(rep.size.height, 1080.0, 1.0);

    // Rendering the page catches PDF-only regressions such as alpha shadings
    // that Quartz turns into an opaque black rectangle.
    NSSize renderSize = NSMakeSize(720, 540);
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                       pixelsWide:(NSInteger)renderSize.width
                                                                       pixelsHigh:(NSInteger)renderSize.height
                                                                    bitsPerSample:8
                                                                  samplesPerPixel:4
                                                                         hasAlpha:YES
                                                                         isPlanar:NO
                                                                   colorSpaceName:NSCalibratedRGBColorSpace
                                                                      bytesPerRow:0
                                                                     bitsPerPixel:0];
    XCTAssertNotNil(bitmap);
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [[NSColor whiteColor] setFill];
    NSRectFill(NSMakeRect(0, 0, renderSize.width, renderSize.height));
    [rep drawInRect:NSMakeRect(0, 0, renderSize.width, renderSize.height)];
    [NSGraphicsContext restoreGraphicsState];

    NSColor *background = [[bitmap colorAtX:12 y:12]
                           colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    XCTAssertNotNil(background);
    CGFloat backgroundBrightness = (background.redComponent + background.greenComponent + background.blueComponent) / 3.0;
    XCTAssertGreaterThan(backgroundBrightness, 0.03);
    XCTAssertLessThan(backgroundBrightness, 0.45);

    NSUInteger brightSamples = 0;
    for (NSInteger y = 0; y < (NSInteger)renderSize.height; y += 12) {
        for (NSInteger x = 0; x < (NSInteger)renderSize.width; x += 12) {
            NSColor *sample = [[bitmap colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            if (!sample) continue;
            CGFloat brightness = (sample.redComponent + sample.greenComponent + sample.blueComponent) / 3.0;
            if (brightness > 0.48) brightSamples++;
        }
    }
    XCTAssertGreaterThan(brightSamples, 5u, @"The PDF should contain visible vector strokes");

    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
}

- (void)testExportRejectsMissingDrawing {
    NSError *error = nil;
    BOOL success = [TSImageExporter writePNGForDrawing:(TSDrawing *)nil
                                                theme:[TSTheme defaultTheme]
                                                toURL:[self temporaryURLWithExtension:@"png"]
                                            pixelSize:NSMakeSize(800, 600)
                                                error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);

    error = nil;
    success = [TSImageExporter writeSVGForDrawing:nil
                                          theme:[TSTheme defaultTheme]
                                          toURL:[self temporaryURLWithExtension:@"svg"]
                                          error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);

    error = nil;
    success = [TSImageExporter writePDFForDrawing:nil
                                          theme:[TSTheme defaultTheme]
                                          toURL:[self temporaryURLWithExtension:@"pdf"]
                                       pageSize:NSMakeSize(800, 600)
                                          error:&error];
    XCTAssertFalse(success);
    XCTAssertNotNil(error);
}

- (void)testExportFormatMetadata {
    XCTAssertEqualObjects(TSExportFormatFileExtension(TSExportFormatPNG), @"png");
    XCTAssertEqualObjects(TSExportFormatFileExtension(TSExportFormatSVG), @"svg");
    XCTAssertEqualObjects(TSExportFormatFileExtension(TSExportFormatPDF), @"pdf");
    XCTAssertEqualObjects(TSExportFormatDisplayName(TSExportFormatSVG), @"SVG");
}

@end
