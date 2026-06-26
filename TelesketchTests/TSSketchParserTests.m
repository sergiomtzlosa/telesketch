#import <XCTest/XCTest.h>
#import "TSSketchParser.h"
#import "TSDrawing.h"
#import "TSStroke.h"
#import "TSTheme.h"

@interface TSSketchParserTests : XCTestCase
@property (nonatomic, strong) TSTheme *theme;
@end

@implementation TSSketchParserTests

- (void)setUp {
    [super setUp];
    self.theme = [TSTheme themeWithIdentifier:@"classic"];
}

- (NSString *)twoStrokeJSON {
    NSString *vermilion = [self.theme colorHexForRole:TSColorRoleVermilion];
    return [NSString stringWithFormat:@"{\"title\":\"Test Cat\",\"strokes\":["
           @"{\"width\":2.5,\"color\":\"#2B2E2C\",\"tool\":\"ai\",\"points\":[[0.1,0.2],[0.2,0.3],[0.3,0.25]]},"
           @"{\"width\":4,\"color\":\"%@\",\"tool\":\"ai\",\"points\":[[0.4,0.5,0.6],[0.6,0.7,0.8]]}"
           @"]}", vermilion];
}

- (void)testParsesValidJSONObject {
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:[self twoStrokeJSON] theme:self.theme error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    XCTAssertEqualObjects(drawing.title, @"Test Cat");
    XCTAssertEqual(drawing.strokes.count, 2);
    XCTAssertEqualObjects(drawing.themeIdentifier, @"classic");
    TSStroke *first = drawing.strokes.firstObject;
    XCTAssertEqualWithAccuracy(first.width, 2.5, 0.001);
    XCTAssertEqual(first.role, TSColorRoleInk);
    XCTAssertEqual(first.vertices.count, 3);
    TSStroke *second = drawing.strokes.lastObject;
    XCTAssertEqual(second.role, TSColorRoleVermilion);
    XCTAssertEqualWithAccuracy(second.vertices.lastObject.pressure, 0.8, 0.001);
}

- (void)testParsesMarkdownFencedJSON {
    NSString *fenced = [NSString stringWithFormat:@"Here is your sketch:\n```json\n%@\n```\nEnjoy!", [self twoStrokeJSON]];
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:fenced theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertEqual(drawing.strokes.count, 2);
}

- (void)testParsesProseWrappedJSON {
    NSString *prose = [NSString stringWithFormat:@"Sure. I drew a cat. %@ That's all.", [self twoStrokeJSON]];
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:prose theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertEqualObjects(drawing.title, @"Test Cat");
}

- (void)testParsesBareStrokeArray {
    NSString *array = @"["
        @"{\"width\":2,\"points\":[[0.1,0.1],[0.2,0.2]]},"
        @"{\"width\":2,\"points\":[[0.3,0.3],[0.4,0.4]]}"
        @"]";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:array theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertEqual(drawing.strokes.count, 2);
    XCTAssertEqualObjects(drawing.title, @"AI Sketch");
}

- (void)testScalesZeroToOneHundredCoordinates {
    NSString *json = @"{\"strokes\":["
        @"{\"points\":[[10,20],[30,40]]},"
        @"{\"points\":[[50,60],[70,80]]}"
        @"]}";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:json theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    TSStroke *stroke = drawing.strokes.firstObject;
    XCTAssertEqualWithAccuracy(stroke.vertices.firstObject.x, 0.1, 0.0001);
    XCTAssertEqualWithAccuracy(stroke.vertices.firstObject.y, 0.2, 0.0001);
    XCTAssertEqualWithAccuracy(stroke.vertices.lastObject.x, 0.3, 0.0001);
}

- (void)testClampsOutOfRangeCoordinates {
    NSString *json = @"{\"strokes\":["
        @"{\"points\":[[-2.0,0.5],[4.0,0.9]]},"
        @"{\"points\":[[0.2,0.2],[0.3,0.3]]}"
        @"]}";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:json theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    for (TSStroke *stroke in drawing.strokes) {
        for (TSVertex *vertex in stroke.vertices) {
            XCTAssertGreaterThanOrEqual(vertex.x, 0.0);
            XCTAssertLessThanOrEqual(vertex.x, 1.0);
            XCTAssertGreaterThanOrEqual(vertex.y, 0.0);
            XCTAssertLessThanOrEqual(vertex.y, 1.0);
        }
    }
}

- (void)testMissingColorFallsBackToInkRole {
    NSString *json = @"{\"strokes\":["
        @"{\"points\":[[0.1,0.1],[0.2,0.2]]},"
        @"{\"points\":[[0.3,0.3],[0.4,0.4]]}"
        @"]}";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:json theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    for (TSStroke *stroke in drawing.strokes) {
        XCTAssertEqual(stroke.role, TSColorRoleInk);
    }
}

- (void)testUnknownColorBecomesCustomRole {
    NSString *json = @"{\"strokes\":["
        @"{\"color\":\"#123456\",\"points\":[[0.1,0.1],[0.2,0.2]]},"
        @"{\"points\":[[0.3,0.3],[0.4,0.4]]}"
        @"]}";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:json theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertEqual(drawing.strokes.firstObject.role, TSColorRoleCustom);
    XCTAssertEqualObjects(drawing.strokes.firstObject.colorHex, @"#123456");
}

- (void)testRejectsInvalidJSON {
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:@"I cannot draw that." theme:self.theme error:&error];
    XCTAssertNil(drawing);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, TSSketchErrorDomain);
}

- (void)testRejectsTooFewStrokes {
    NSError *error = nil;
    NSString *json = @"{\"strokes\":[{\"points\":[[0.1,0.1],[0.2,0.2]]}]}";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:json theme:self.theme error:&error];
    XCTAssertNil(drawing);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, TSSketchErrorEmptyDrawing);
}

- (void)testCapsPointBudget {
    NSMutableString *points = [NSMutableString string];
    for (NSInteger i = 0; i < 300; i++) {
        [points appendFormat:@"[%f,%f],", (double)i / 300.0, (double)i / 600.0];
    }
    NSString *trimmed = [points substringToIndex:points.length - 1];
    NSMutableString *json = [NSMutableString stringWithString:@"{\"strokes\":["];
    for (NSInteger i = 0; i < 40; i++) {
        if (i > 0) [json appendString:@","];
        [json appendFormat:@"{\"points\":[%@]}", trimmed];
    }
    [json appendString:@"]}"];
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:json theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertLessThanOrEqual([drawing totalPointCount], 4000u);
    XCTAssertLessThanOrEqual(drawing.strokes.count, 64u);
}

- (void)testRepairsHTMLEscapedKeyQuotes {
    NSString *text = [[self twoStrokeJSON] stringByReplacingOccurrencesOfString:@"\"strokes\""
                                                                     withString:@"&quot;\"strokes&quot;"];
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:self.theme error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    XCTAssertEqualObjects(drawing.title, @"Test Cat");
    XCTAssertEqual(drawing.strokes.count, 2);
}

- (void)testClosesTruncatedJSONDelimiters {
    NSString *valid = [self twoStrokeJSON];
    NSString *truncated = [valid substringToIndex:valid.length - 1];
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:truncated theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertEqual(drawing.strokes.count, 2);
}

- (void)testExtractsBalancedJSONWithBracesInsideStrings {
    NSString *text = @"prefix {\"title\":\"A {curly} title\",\"strokes\":[" 
                     @"{\"points\":[[0.1,0.1],[0.2,0.2]]},"
                     @"{\"points\":[[0.3,0.3],[0.4,0.4]]}]} suffix";
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:self.theme error:NULL];
    XCTAssertNotNil(drawing);
    XCTAssertEqualObjects(drawing.title, @"A {curly} title");
}

- (void)testRepairsMissingStrokeBoundaryBrace {
    NSString *text = @"{\"title\":\"Cat\",\"strokes\":["
        @"{\"color\":\"#2B2E2C\",\"width\":2,\"points\":[[0.1,0.1],[0.2,0.2],[0.3,0.3]]},"
        @"{\"color\":\"#C64B3C\",\"width\":2,\"points\":[[0.4,0.4],[0.5,0.5],[0.6,0.6]]},"
        @"{\"color\":\"#397C77\",\"width\":2,\"points\":[[0.7,0.7],[0.8,0.8],[0.9,0.9]]}"
        @"]}";
    // File 2 from the production failure log: the closing brace of the second
    // stroke is missing, so `]]` is followed directly by `,{"color"...}`.
    NSString *broken = [text stringByReplacingOccurrencesOfString:@"\"points\":[[0.4,0.4],[0.5,0.5],[0.6,0.6]]},"
                                                        withString:@"\"points\":[[0.4,0.4],[0.5,0.5],[0.6,0.6]],"];
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:broken theme:self.theme error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    XCTAssertEqual(drawing.strokes.count, 3);
}

- (void)testSalvagesStrokesBeforeTruncatedFinalPoint {
    NSString *text = @"{\"title\":\"Cat\",\"strokes\":["
        @"{\"color\":\"#2B2E2C\",\"width\":2,\"points\":[[0.1,0.1],[0.2,0.2],[0.3,0.3]]},"
        @"{\"color\":\"#C64B3C\",\"width\":2,\"points\":[[0.4,0.4],[0.5,0.5],[0.6,0.6]]},"
        @"{\"color\":\"#397C77\",\"width\":2,\"points\":[[0.7,0.7],[0.8,0.8],[0.9,0.";
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:self.theme error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    // The truncated stroke still has two complete points, so salvage keeps it.
    XCTAssertEqual(drawing.strokes.count, 3);
    XCTAssertEqual(drawing.strokes.lastObject.vertices.count, 2);
    for (TSStroke *stroke in drawing.strokes) {
        for (TSVertex *vertex in stroke.vertices) {
            XCTAssertTrue(isfinite(vertex.x));
            XCTAssertTrue(isfinite(vertex.y));
        }
    }
}

- (void)testRepairsStrayComparisonCharacterInPoint {
    NSString *text = @"{\"title\":\"Cat\",\"strokes\":["
        @"{\"color\":\"#2B2E2C\",\"width\":2,\"points\":[[0.10,0.10],[0.20,0.20],[0.30,0.30]]},"
        @"{\"color\":\"#C64B3C\",\"width\":2,\"points\":[[0.40,0.40],[0.00,0.25,<0.01,0.30],[0.60,0.60]]}"
        @"]}";
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:self.theme error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    XCTAssertEqual(drawing.strokes.count, 2);
    XCTAssertEqual(drawing.strokes.lastObject.vertices.count, 3);
}

- (void)testSalvagesCompleteStrokesFromLongTruncatedResponse {
    NSMutableString *text = [NSMutableString stringWithString:@"{\"title\":\"Cat\",\"strokes\":["];
    for (NSInteger i = 0; i < 6; i++) {
        if (i > 0) [text appendString:@","];
        [text appendFormat:@"{\"color\":\"#2B2E2C\",\"width\":2,\"points\":[[0.%ld,0.%ld],[0.%ld,0.%ld],[0.%ld,0.%ld]]}",
         (long)i + 1, (long)i + 1, (long)i + 2, (long)i + 2, (long)i + 3, (long)i + 3];
    }
    [text appendString:@",{\"color\":\"#C64B3C\",\"width\":2,\"points\":[[0.8,0.8],[0.9,0."];
    NSError *error = nil;
    TSDrawing *drawing = [TSSketchParser drawingFromModelText:text theme:self.theme error:&error];
    XCTAssertNotNil(drawing);
    XCTAssertNil(error);
    XCTAssertEqual(drawing.strokes.count, 6);
}

@end
