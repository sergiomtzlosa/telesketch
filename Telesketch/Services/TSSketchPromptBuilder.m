#import "TSSketchPromptBuilder.h"

@implementation TSSketchPromptBuilder

+ (NSString *)paletteStringForTheme:(TSTheme *)theme {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *entry in [theme paletteDescription]) {
        [parts addObject:[NSString stringWithFormat:@"%@ %@", entry[@"name"], entry[@"hex"]]];
    }
    return [parts componentsJoinedByString:@", "];
}

+ (NSString *)promptForSubject:(NSString *)subject theme:(TSTheme *)theme {
    NSString *cleanSubject = [subject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanSubject.length == 0) {
        cleanSubject = @"a whimsical line-art creature";
    }
    if (cleanSubject.length > 280) {
        cleanSubject = [cleanSubject substringToIndex:280];
    }

    return [NSString stringWithFormat:
            @"Draw \"%@\" as a charming, hand-drawn single-subject line illustration, large and centred, with slightly imperfect contours and hatching.\n"
             "Return ONLY minified JSON, no markdown or prose:\n"
             "{\"title\":\"Short title\",\"strokes\":[{\"color\":\"%@\",\"width\":3,\"points\":[[0.30,0.30],[0.35,0.25],[0.40,0.30],[0.45,0.25]]}]}\n"
             "Rules: 6-10 strokes; 4-9 points per stroke; every point is [x,y] decimal numbers 0.08-0.92, origin top-left, never a string; outlines and hatching only; no fills, text, gradients or background; use only %@. Stop after the final closing brace.",
            cleanSubject,
            [theme colorHexForRole:TSColorRoleInk],
            [self paletteStringForTheme:theme]];
}

+ (NSString *)repairPromptForSubject:(NSString *)subject theme:(TSTheme *)theme {
    NSString *cleanSubject = [subject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [NSString stringWithFormat:
            @"Return ONLY minified JSON for a line drawing of \"%@\". No prose or markdown.\n"
             "{\"title\":\"...\",\"strokes\":[{\"color\":\"%@\",\"width\":3,\"points\":[[0.30,0.30],[0.35,0.25],[0.40,0.30]]}]}\n"
             "Use 4-8 strokes, 3-8 points each. Every point is [x,y] numbers 0.08-0.92. Outlines and hatching only. Palette %@. Stop after the final brace.",
            cleanSubject.length > 0 ? cleanSubject : @"a simple cat",
            [theme colorHexForRole:TSColorRoleInk],
            [self paletteStringForTheme:theme]];
}

+ (NSArray<NSString *> *)suggestedSubjects {
    return @[@"a curious cat", @"a mountain cabin", @"a retro rocket"];
}

@end
