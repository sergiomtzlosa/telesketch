#import <XCTest/XCTest.h>
#import "TSOfflineSketchEngine.h"
#import "TSDrawing.h"
#import "TSStroke.h"
#import "TSTheme.h"

@interface TSOfflineSketchEngineTests : XCTestCase
@property (nonatomic, strong) TSTheme *theme;
@end

@implementation TSOfflineSketchEngineTests

- (void)setUp {
    [super setUp];
    self.theme = [TSTheme themeWithIdentifier:@"classic"];
}

- (void)testEverySceneProducesAValidDrawing {
    for (NSString *scene in [TSOfflineSketchEngine sceneNames]) {
        TSDrawing *drawing = [TSOfflineSketchEngine drawingForPrompt:scene theme:self.theme seed:42];
        XCTAssertNotNil(drawing, @"scene %@ returned nil", scene);
        XCTAssertGreaterThanOrEqual(drawing.strokes.count, 8u, @"scene %@ had too few strokes", scene);
        XCTAssertEqualObjects(drawing.themeIdentifier, @"classic");
        XCTAssertEqualWithAccuracy(drawing.aspect, 4.0 / 3.0, 0.0001);

        for (TSStroke *stroke in drawing.strokes) {
            XCTAssertGreaterThanOrEqual(stroke.vertices.count, 2u);
            XCTAssertGreaterThan(stroke.width, 0.0);
            XCTAssertLessThanOrEqual(stroke.width, 12.0);
            for (TSVertex *vertex in stroke.vertices) {
                XCTAssertGreaterThanOrEqual(vertex.x, 0.0);
                XCTAssertLessThanOrEqual(vertex.x, 1.0);
                XCTAssertGreaterThanOrEqual(vertex.y, 0.0);
                XCTAssertLessThanOrEqual(vertex.y, 1.0);
                XCTAssertGreaterThanOrEqual(vertex.pressure, 0.0);
                XCTAssertLessThanOrEqual(vertex.pressure, 1.0);
            }
        }
    }
}

- (void)testSamePromptAndSeedIsDeterministic {
    TSDrawing *first = [TSOfflineSketchEngine drawingForPrompt:@"a curious cat" theme:self.theme seed:1234];
    TSDrawing *second = [TSOfflineSketchEngine drawingForPrompt:@"a curious cat" theme:self.theme seed:1234];
    XCTAssertEqualObjects([first JSONDataWithError:NULL], [second JSONDataWithError:NULL]);
}

- (void)testDifferentSeedsProduceDifferentJitter {
    TSDrawing *first = [TSOfflineSketchEngine drawingForPrompt:@"house" theme:self.theme seed:7];
    TSDrawing *second = [TSOfflineSketchEngine drawingForPrompt:@"house" theme:self.theme seed:8];
    XCTAssertNotEqualObjects([first JSONDataWithError:NULL], [second JSONDataWithError:NULL]);
}

- (void)testFrenchSynonymsMatchScenes {
    TSDrawing *cat = [TSOfflineSketchEngine drawingForPrompt:@"un chat curieux" theme:self.theme seed:1];
    XCTAssertEqualObjects(cat.title, @"Curious Cat");
    TSDrawing *house = [TSOfflineSketchEngine drawingForPrompt:@"une petite maison" theme:self.theme seed:2];
    XCTAssertEqualObjects(house.title, @"Little House");
    TSDrawing *rocket = [TSOfflineSketchEngine drawingForPrompt:@"une fusée" theme:self.theme seed:3];
    XCTAssertEqualObjects(rocket.title, @"Retro Rocket");
}

- (void)testUnknownPromptStillYieldsDrawing {
    TSDrawing *drawing = [TSOfflineSketchEngine drawingForPrompt:@"quantum marmalade on Tuesdays" theme:self.theme seed:99];
    XCTAssertNotNil(drawing);
    XCTAssertGreaterThanOrEqual(drawing.strokes.count, 8u);
    XCTAssertEqualObjects(drawing.title, @"Imagined Landscape");
}

- (void)testEveryThemeRendersItsOwnIdentifier {
    for (TSTheme *theme in [TSTheme allThemes]) {
        TSDrawing *drawing = [TSOfflineSketchEngine drawingForPrompt:@"robot" theme:theme seed:5];
        XCTAssertEqualObjects(drawing.themeIdentifier, theme.identifier);
    }
}

- (void)testDetailedModifierAddsStrokes {
    TSDrawing *minimal = [TSOfflineSketchEngine drawingForPrompt:@"minimal cat" theme:self.theme seed:11];
    TSDrawing *detailed = [TSOfflineSketchEngine drawingForPrompt:@"detailed cat" theme:self.theme seed:11];
    XCTAssertGreaterThan(detailed.strokes.count, minimal.strokes.count);
}

@end
