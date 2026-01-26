#import "TSSketchParser.h"

static id TSJSONValueByScanningText(NSString *text);

static NSString *TSStringFromJSONValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

/// Small models occasionally HTML-escape quotes inside otherwise valid JSON
/// (for example `&quot;strokes&quot;`). Decode the common entities when a raw
/// parse fails.
static NSString *TSStringByDecodingHTMLEntities(NSString *text) {
    if ([text rangeOfString:@"&"].location == NSNotFound) {
        return text;
    }
    NSMutableString *decoded = [text mutableCopy];
    NSArray<NSArray<NSString *> *> *entities = @[
        @[@"&quot;", @"\""],
        @[@"&#34;", @"\""],
        @[@"&#x22;", @"\""],
        @[@"&apos;", @"'"],
        @[@"&#39;", @"'"],
        @[@"&lt;", @"<"],
        @[@"&gt;", @">"],
        @[@"&amp;", @"&"]
    ];
    for (NSArray<NSString *> *entity in entities) {
        [decoded replaceOccurrencesOfString:entity[0]
                                withString:entity[1]
                                   options:NSCaseInsensitiveSearch
                                     range:NSMakeRange(0, decoded.length)];
    }
    return decoded;
}

/// Token limits sometimes cut a response off after the last stroke but before
/// the final closing brace. Append the missing delimiters when the remaining
/// text is otherwise well formed.
static NSString *TSStringByClosingUnbalancedJSON(NSString *text) {
    NSRange objectStart = [text rangeOfString:@"{"];
    NSRange arrayStart = [text rangeOfString:@"["];
    NSUInteger start = NSNotFound;
    if (objectStart.location != NSNotFound && (arrayStart.location == NSNotFound || objectStart.location < arrayStart.location)) {
        start = objectStart.location;
    } else if (arrayStart.location != NSNotFound) {
        start = arrayStart.location;
    }
    if (start == NSNotFound) {
        return text;
    }

    NSMutableString *stack = [NSMutableString string];
    BOOL inString = NO;
    BOOL escaped = NO;
    for (NSUInteger i = start; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (inString) {
            if (escaped) {
                escaped = NO;
            } else if (c == '\\') {
                escaped = YES;
            } else if (c == '"') {
                inString = NO;
            }
            continue;
        }
        if (c == '"') {
            inString = YES;
        } else if (c == '{' || c == '[') {
            [stack appendFormat:@"%C", c];
        } else if (c == '}' || c == ']') {
            unichar expected = (c == '}') ? '{' : '[';
            if (stack.length == 0 || [stack characterAtIndex:stack.length - 1] != expected) {
                return text;
            }
            [stack deleteCharactersInRange:NSMakeRange(stack.length - 1, 1)];
        }
    }

    if (stack.length == 0) {
        return text;
    }

    NSMutableString *result = [text mutableCopy];
    if (inString) {
        [result appendString:@"\""];
    }
    for (NSInteger i = (NSInteger)stack.length - 1; i >= 0; i--) {
        unichar opener = [stack characterAtIndex:(NSUInteger)i];
        [result appendString:(opener == '{') ? @"}" : @"]"];
    }
    return result;
}

/// Some models escape only one side of a key's quotes, leaving a duplicated
/// quote such as `""strokes"`. Collapse those key quotes after decoding.
static NSString *TSStringByCollapsingRepeatedKeyQuotes(NSString *text) {
    if ([text rangeOfString:@"\"\""].location == NSNotFound) {
        return text;
    }
    NSString *result = text;
    for (NSString *pattern in @[@"\"{2}([A-Za-z_][A-Za-z0-9_]*)\"\\s*:",
                                @"\"([A-Za-z_][A-Za-z0-9_]*)\"{2}\\s*:"]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:0
                                                                                 error:NULL];
        result = [regex stringByReplacingMatchesInString:result
                                                 options:0
                                                   range:NSMakeRange(0, result.length)
                                            withTemplate:@"\"$1\":"];
    }
    return result;
}

/// Small models sometimes forget the closing brace between two strokes:
/// `...]]},{"color"...` becomes `...]],{"color"...`. Restore the stroke
/// boundary without touching valid object separators.
static NSString *TSStringByRepairingStrokeBoundaries(NSString *text) {
    if ([text rangeOfString:@"]]" options:0].location == NSNotFound) {
        return text;
    }
    NSString *result = text;
    NSArray<NSArray<NSString *> *> *repairs = @[
        @[@"(\\]\\])\\s*,\\s*\\{", @"$1},{"],
        @[@"(\\]\\])\\s*\\{", @"$1},{"]
    ];
    for (NSArray<NSString *> *repair in repairs) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:repair[0]
                                                                               options:0
                                                                                 error:NULL];
        result = [regex stringByReplacingMatchesInString:result
                                                 options:0
                                                   range:NSMakeRange(0, result.length)
                                            withTemplate:repair[1]];
    }
    return result;
}

/// Remove the occasional comparison character a model inserts inside a number,
/// for example `[0.00,0.25,<0.01,0.30]`.
static NSString *TSStringByRemovingStrayNumericCharacters(NSString *text) {
    if ([text rangeOfString:@"<"].location == NSNotFound &&
        [text rangeOfString:@">"].location == NSNotFound) {
        return text;
    }
    NSString *result = text;
    NSRegularExpression *left = [NSRegularExpression regularExpressionWithPattern:@"([,\\[])\\s*<\\s*(?=[0-9])"
                                                                           options:0 error:NULL];
    result = [left stringByReplacingMatchesInString:result options:0
                                              range:NSMakeRange(0, result.length)
                                       withTemplate:@"$1"];
    NSRegularExpression *right = [NSRegularExpression regularExpressionWithPattern:@"([0-9])\\s*>\\s*(?=[,\\]])"
                                                                            options:0 error:NULL];
    result = [right stringByReplacingMatchesInString:result options:0
                                               range:NSMakeRange(0, result.length)
                                        withTemplate:@"$1"];
    return result;
}

static NSString *TSStringByTrimmingTrailingJSONSeparators(NSString *text) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimmed = [text stringByTrimmingCharactersInSet:whitespace];
    while (trimmed.length > 0) {
        unichar last = [trimmed characterAtIndex:trimmed.length - 1];
        if (last != ',' && last != ':') break;
        trimmed = [[trimmed substringToIndex:trimmed.length - 1]
                   stringByTrimmingCharactersInSet:whitespace];
    }
    return trimmed;
}

/// Try the raw candidate, then a version with missing closing delimiters
/// appended, then a version with a dangling comma or colon removed first.
static id TSJSONValueFromRepairCandidate(NSString *candidate) {
    if (candidate.length == 0) return nil;

    id value = TSJSONValueByScanningText(candidate);
    if (value) return value;

    NSString *trimmed = TSStringByTrimmingTrailingJSONSeparators(candidate);
    if (![trimmed isEqualToString:candidate]) {
        value = TSJSONValueByScanningText(trimmed);
        if (value) return value;
    }

    NSString *closed = TSStringByClosingUnbalancedJSON(trimmed);
    if (![closed isEqualToString:trimmed]) {
        value = TSJSONValueByScanningText(closed);
        if (value) return value;
    }
    return nil;
}

/// Last-resort salvage for token-truncated output: walk backwards through
/// completed arrays/objects and try to close the JSON at each boundary until
/// a valid document emerges. This keeps every complete stroke that arrived
/// before the model ran out of tokens.
static id TSJSONValueBySalvagingPrefix(NSString *text) {
    NSString *trimmed = TSStringByTrimmingTrailingJSONSeparators(text);
    NSString *current = trimmed;
    NSUInteger searchLimit = current.length;

    for (NSInteger attempt = 0; attempt < 400 && current.length > 1; attempt++) {
        NSRange searchRange = NSMakeRange(0, MIN(searchLimit, current.length));
        NSRange lastArray = [current rangeOfString:@"]" options:NSBackwardsSearch range:searchRange];
        NSRange lastObject = [current rangeOfString:@"}" options:NSBackwardsSearch range:searchRange];

        NSUInteger boundary = NSNotFound;
        NSUInteger boundaryLength = 0;
        if (lastArray.location != NSNotFound) {
            boundary = lastArray.location;
            boundaryLength = lastArray.length;
        }
        if (lastObject.location != NSNotFound &&
            (boundary == NSNotFound || lastObject.location > boundary)) {
            boundary = lastObject.location;
            boundaryLength = lastObject.length;
        }
        if (boundary == NSNotFound) break;

        NSString *prefix = [current substringToIndex:boundary + boundaryLength];
        id value = TSJSONValueFromRepairCandidate(prefix);
        if (value) return value;

        if (boundary == 0) break;
        searchLimit = boundary;
    }
    return nil;
}

static id TSJSONValueByScanningText(NSString *text) {
    NSRange objectStart = [text rangeOfString:@"{"];
    NSRange arrayStart = [text rangeOfString:@"["];
    NSUInteger start = NSNotFound;
    unichar opener = 0;
    unichar closer = 0;

    if (objectStart.location != NSNotFound && (arrayStart.location == NSNotFound || objectStart.location < arrayStart.location)) {
        start = objectStart.location;
        opener = '{';
        closer = '}';
    } else if (arrayStart.location != NSNotFound) {
        start = arrayStart.location;
        opener = '[';
        closer = ']';
    }

    if (start == NSNotFound) {
        return nil;
    }

    NSInteger depth = 0;
    BOOL inString = NO;
    BOOL escaped = NO;
    for (NSUInteger i = start; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (inString) {
            if (escaped) {
                escaped = NO;
            } else if (c == '\\') {
                escaped = YES;
            } else if (c == '"') {
                inString = NO;
            }
            continue;
        }
        if (c == '"') {
            inString = YES;
            continue;
        }
        if (c == opener) {
            depth++;
        } else if (c == closer) {
            depth--;
            if (depth == 0) {
                NSString *candidate = [text substringWithRange:NSMakeRange(start, i - start + 1)];
                return [NSJSONSerialization JSONObjectWithData:[candidate dataUsingEncoding:NSUTF8StringEncoding]
                                                       options:0
                                                         error:NULL];
            }
        }
    }
    return nil;
}

@implementation TSSketchParser

+ (id)extractJSONValueFromText:(NSString *)text {
    if (![text isKindOfClass:[NSString class]] || text.length == 0) {
        return nil;
    }

    id value = TSJSONValueByScanningText(text);
    if (value) {
        return value;
    }

    NSString *decoded = TSStringByDecodingHTMLEntities(text);
    NSString *repaired = TSStringByCollapsingRepeatedKeyQuotes(decoded);
    NSString *boundaries = TSStringByRepairingStrokeBoundaries(repaired);
    NSString *strayCharacters = TSStringByRemovingStrayNumericCharacters(repaired);
    NSString *fullyRepaired = TSStringByRepairingStrokeBoundaries(strayCharacters);

    NSMutableArray<NSString *> *candidates = [NSMutableArray arrayWithObject:text];
    for (NSString *candidate in @[decoded, repaired, boundaries, strayCharacters, fullyRepaired]) {
        if (candidate.length > 0 && ![candidates containsObject:candidate]) {
            [candidates addObject:candidate];
        }
    }

    // Prefer a full structural repair over prefix salvage. Otherwise a
    // truncation-friendly prefix from the raw text could hide a complete
    // drawing that the missing-brace or stray-character repair would recover.
    for (NSString *candidate in candidates) {
        value = TSJSONValueFromRepairCandidate(candidate);
        if (value) {
            return value;
        }
    }
    for (NSString *candidate in candidates) {
        value = TSJSONValueBySalvagingPrefix(candidate);
        if (value) {
            return value;
        }
    }
    return nil;
}

+ (nullable TSDrawing *)drawingFromModelText:(NSString *)text
                                       theme:(TSTheme *)theme
                                       error:(NSError **)error {
    id value = [self extractJSONValueFromText:text];
    if (!value) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey: @"The model did not return a JSON sketch.",
                                                @"rawText": text ?: @""}];
        }
        return nil;
    }

    NSDictionary *dictionary = nil;
    if ([value isKindOfClass:[NSDictionary class]]) {
        dictionary = value;
    } else if ([value isKindOfClass:[NSArray class]]) {
        dictionary = @{@"strokes": value};
    } else {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidShape
                                     userInfo:@{NSLocalizedDescriptionKey: @"The model returned an unsupported JSON value."}];
        }
        return nil;
    }

    NSArray *rawStrokes = dictionary[@"strokes"];
    if (![rawStrokes isKindOfClass:[NSArray class]] || rawStrokes.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidShape
                                     userInfo:@{NSLocalizedDescriptionKey: @"The sketch JSON has no strokes."}];
        }
        return nil;
    }

    // Some models emit percentages or a 0...1000 coordinate system despite instructions.
    double maxCoordinate = 0.0;
    for (id rawStroke in rawStrokes) {
        if (![rawStroke isKindOfClass:[NSDictionary class]]) continue;
        NSArray *points = rawStroke[@"points"];
        if (![points isKindOfClass:[NSArray class]]) continue;
        for (NSArray *point in points) {
            if (![point isKindOfClass:[NSArray class]] || point.count < 2) continue;
            maxCoordinate = MAX(maxCoordinate, fabs([point[0] doubleValue]));
            maxCoordinate = MAX(maxCoordinate, fabs([point[1] doubleValue]));
        }
    }
    double scale = 1.0;
    if (maxCoordinate > 1.2) {
        scale = (maxCoordinate <= 100.0) ? 0.01 : 0.001;
    }

    NSMutableArray<TSStroke *> *strokes = [NSMutableArray array];
    NSUInteger totalPoints = 0;
    NSUInteger skipped = 0;

    for (NSDictionary *rawStroke in rawStrokes) {
        if (strokes.count >= 64 || totalPoints >= 4000) {
            break;
        }
        if (![rawStroke isKindOfClass:[NSDictionary class]]) {
            skipped++;
            continue;
        }
        NSArray *points = rawStroke[@"points"];
        if (![points isKindOfClass:[NSArray class]] || points.count < 2) {
            skipped++;
            continue;
        }

        NSMutableArray<TSVertex *> *vertices = [NSMutableArray array];
        NSUInteger pointLimit = MIN(points.count, (NSUInteger)200);
        for (NSUInteger i = 0; i < pointLimit; i++) {
            NSString *pointDescription = nil;
            id point = points[i];
            if (![point isKindOfClass:[NSArray class]] || [point count] < 2) {
                continue;
            }
            double x = [point[0] doubleValue] * scale;
            double y = [point[1] doubleValue] * scale;
            double pressure = [point count] > 2 ? [point[2] doubleValue] : 0.55;
            if (isnan(x) || isinf(x) || isnan(y) || isinf(y)) {
                continue;
            }
            [vertices addObject:[TSVertex vertexWithX:x y:y pressure:pressure]];
            (void)pointDescription;
        }
        if (vertices.count < 2) {
            skipped++;
            continue;
        }

        double width = [rawStroke[@"width"] doubleValue];
        if (width <= 0.0) {
            width = 3.0;
        }
        width = MAX(0.5, MIN(12.0, width));

        NSString *color = TSStringFromJSONValue(rawStroke[@"color"]);
        TSColorRole role = TSColorRoleInk;
        NSString *storedColor = @"";
        if (color.length > 0) {
            storedColor = [color uppercaseString];
            BOOL matched = NO;
            NSArray<NSString *> *roles = @[@"identifier", @"ink", @"vermilion", @"teal", @"ochre", @"blue"];
            (void)roles;
            for (NSString *roleName in @[@"ink", @"vermilion", @"teal", @"ochre", @"blue"]) {
                TSColorRole candidate = TSColorRoleFromString(roleName);
                NSString *themeColor = [theme colorHexForRole:candidate];
                if ([storedColor caseInsensitiveCompare:themeColor] == NSOrderedSame) {
                    role = candidate;
                    matched = YES;
                    break;
                }
            }
            if (!matched) {
                role = TSColorRoleCustom;
            }
        }

        NSString *tool = TSStringFromJSONValue(rawStroke[@"tool"]) ?: @"ai";
        TSStroke *stroke = [TSStroke strokeWithVertices:vertices
                                                  width:width
                                                   role:role
                                               colorHex:storedColor
                                                   tool:tool];
        [strokes addObject:stroke];
        totalPoints += vertices.count;
    }

    if (strokes.count < 2) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorEmptyDrawing
                                     userInfo:@{NSLocalizedDescriptionKey: @"The model returned too few valid strokes."}];
        }
        return nil;
    }

    NSString *title = TSStringFromJSONValue(dictionary[@"title"]) ?: @"AI Sketch";
    title = [[title stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length == 0) {
        title = @"AI Sketch";
    }
    if (title.length > 64) {
        title = [title substringToIndex:64];
    }

    (void)skipped;
    return [[TSDrawing alloc] initWithTitle:title
                                     aspect:4.0 / 3.0
                          themeIdentifier:theme.identifier
                                   strokes:strokes];
}

@end
