#import <XCTest/XCTest.h>
#import "TSDrawing.h"
#import "TSStroke.h"
#import "TSTheme.h"

@interface TSDrawingSerializationTests : XCTestCase
@end

@implementation TSDrawingSerializationTests

- (TSDrawing *)sampleDrawing {
    TSStroke *inkStroke = [TSStroke strokeWithVertices:@[
        [TSVertex vertexWithX:0.10 y:0.20 pressure:0.45],
        [TSVertex vertexWithX:0.35 y:0.28 pressure:0.60],
        [TSVertex vertexWithX:0.62 y:0.24 pressure:0.75]
    ] width:3.25 role:TSColorRoleInk colorHex:nil tool:@"pen"];

    TSStroke *tealStroke = [TSStroke strokeWithVertices:@[
        [TSVertex vertexWithX:0.20 y:0.75 pressure:0.5],
        [TSVertex vertexWithX:0.80 y:0.70 pressure:0.9]
    ] width:5.0 role:TSColorRoleTeal colorHex:@"#397C77" tool:@"ai"];

    TSStroke *customStroke = [TSStroke strokeWithVertices:@[
        [TSVertex vertexWithX:0.4 y:0.4 pressure:0.5],
        [TSVertex vertexWithX:0.6 y:0.6 pressure:0.5]
    ] width:2.0 role:TSColorRoleCustom colorHex:@"#7A5CA8" tool:@"offline"];

    return [[TSDrawing alloc] initWithTitle:@"Serialization Study"
                                      aspect:4.0 / 3.0
                           themeIdentifier:@"midnight"
                                    strokes:@[inkStroke, tealStroke, customStroke]];
}

- (void)testJSONRoundTripPreservesEverything {
    TSDrawing *original = [self sampleDrawing];
    NSError *error = nil;
    NSData *data = [original JSONDataWithError:&error];
    XCTAssertNotNil(data);
    XCTAssertNil(error);

    TSDrawing *restored = [TSDrawing drawingWithJSONData:data error:&error];
    XCTAssertNotNil(restored);
    XCTAssertNil(error);
    XCTAssertEqualObjects(restored.title, original.title);
    XCTAssertEqualObjects(restored.themeIdentifier, original.themeIdentifier);
    XCTAssertEqualWithAccuracy(restored.aspect, original.aspect, 1e-9);
    XCTAssertEqual(restored.strokes.count, original.strokes.count);

    for (NSUInteger i = 0; i < restored.strokes.count; i++) {
        TSStroke *expected = original.strokes[i];
        TSStroke *actual = restored.strokes[i];
        XCTAssertEqualWithAccuracy(actual.width, expected.width, 1e-9);
        XCTAssertEqual(actual.role, expected.role);
        XCTAssertEqualObjects(actual.tool, expected.tool);
        XCTAssertEqual(actual.vertices.count, expected.vertices.count);
        for (NSUInteger j = 0; j < actual.vertices.count; j++) {
            TSVertex *expectedVertex = expected.vertices[j];
            TSVertex *actualVertex = actual.vertices[j];
            XCTAssertEqualWithAccuracy(actualVertex.x, expectedVertex.x, 1e-9);
            XCTAssertEqualWithAccuracy(actualVertex.y, expectedVertex.y, 1e-9);
            XCTAssertEqualWithAccuracy(actualVertex.pressure, expectedVertex.pressure, 1e-9);
        }
    }
}

- (void)testCustomRoleSurvivesRoundTrip {
    TSDrawing *original = [self sampleDrawing];
    TSDrawing *restored = [TSDrawing drawingWithJSONData:[original JSONDataWithError:NULL] error:NULL];
    TSStroke *custom = restored.strokes.lastObject;
    XCTAssertEqual(custom.role, TSColorRoleCustom);
    XCTAssertEqualObjects(custom.colorHex, @"#7A5CA8");
}

- (void)testEmptyDrawingRoundTrips {
    TSDrawing *empty = [TSDrawing emptyDrawingWithThemeIdentifier:@"blueprint"];
    TSDrawing *restored = [TSDrawing drawingWithJSONData:[empty JSONDataWithError:NULL] error:NULL];
    XCTAssertNotNil(restored);
    XCTAssertTrue(restored.isEmpty);
    XCTAssertEqualObjects(restored.themeIdentifier, @"blueprint");
}

- (void)testRejectsCorruptData {
    NSError *error = nil;
    TSDrawing *drawing = [TSDrawing drawingWithJSONData:[@"this is not json" dataUsingEncoding:NSUTF8StringEncoding]
                                                   error:&error];
    XCTAssertNil(drawing);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, TSSketchErrorDomain);
}

- (void)testRejectsTruncatedJSON {
    NSError *error = nil;
    TSDrawing *drawing = [TSDrawing drawingWithJSONData:[@"{\"strokes\":[" dataUsingEncoding:NSUTF8StringEncoding]
                                                   error:&error];
    XCTAssertNil(drawing);
    XCTAssertNotNil(error);
}

- (void)testRejectsNewerFormatVersion {
    NSString *json = @"{\"format\":99,\"strokes\":[]}";
    NSError *error = nil;
    TSDrawing *drawing = [TSDrawing drawingWithJSONData:[json dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    XCTAssertNil(drawing);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, TSSketchErrorUnsupportedVersion);
}

- (void)testThemeRemapPreservesStrokes {
    TSDrawing *original = [self sampleDrawing];
    TSDrawing *remapped = [original drawingWithThemeIdentifier:@"blueprint"];
    XCTAssertEqualObjects(remapped.themeIdentifier, @"blueprint");
    XCTAssertEqual(remapped.strokes.count, original.strokes.count);
    XCTAssertEqualObjects(remapped.title, original.title);
}

- (void)testAddingAndRemovingStrokes {
    TSDrawing *empty = [TSDrawing emptyDrawingWithThemeIdentifier:@"classic"];
    TSStroke *stroke = [TSStroke strokeWithVertices:@[
        [TSVertex vertexWithX:0.1 y:0.1 pressure:0.5],
        [TSVertex vertexWithX:0.2 y:0.2 pressure:0.5]
    ] width:2.0 role:TSColorRoleInk colorHex:nil tool:@"pen"];
    TSDrawing *added = [empty drawingByAddingStroke:stroke];
    XCTAssertEqual(added.strokes.count, 1);
    XCTAssertEqual([added totalPointCount], 2u);
    TSDrawing *removed = [added drawingByRemovingStroke:stroke];
    XCTAssertEqual(removed.strokes.count, 0);
}

- (void)testRoleStringRoundTrip {
    NSArray<NSNumber *> *roles = @[@(TSColorRoleInk), @(TSColorRoleVermilion), @(TSColorRoleTeal),
                                   @(TSColorRoleOchre), @(TSColorRoleBlue), @(TSColorRoleCustom)];
    for (NSNumber *role in roles) {
        TSColorRole value = (TSColorRole)role.integerValue;
        NSString *name = TSColorRoleToString(value);
        XCTAssertTrue(name.length > 0);
        XCTAssertEqual(TSColorRoleFromString(name), value);
        XCTAssertEqual(TSColorRoleFromString(name.uppercaseString), value);
    }
    XCTAssertEqual(TSColorRoleFromString(@"nonsense"), TSColorRoleInk);
}

- (void)testThemeRolesMapToDistinctClassicColours {
    TSTheme *classic = [TSTheme themeWithIdentifier:@"classic"];
    XCTAssertNotEqualObjects([classic colorHexForRole:TSColorRoleInk],
                             [classic colorHexForRole:TSColorRoleVermilion]);
    XCTAssertNotEqualObjects([classic colorHexForRole:TSColorRoleTeal],
                             [classic colorHexForRole:TSColorRoleBlue]);
    XCTAssertEqualObjects([TSTheme themeWithIdentifier:@"nope"].identifier, @"classic");
}

@end
