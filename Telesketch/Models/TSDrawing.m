#import "TSDrawing.h"

static const NSInteger TSDrawingFormatVersion = 1;

@implementation TSDrawing

+ (instancetype)emptyDrawingWithThemeIdentifier:(NSString *)themeIdentifier {
    return [[self alloc] initWithTitle:@"Untitled Sketch"
                                aspect:4.0 / 3.0
                     themeIdentifier:themeIdentifier ?: @"classic"
                              strokes:@[]];
}

- (instancetype)initWithTitle:(NSString *)title
                        aspect:(double)aspect
             themeIdentifier:(NSString *)themeIdentifier
                      strokes:(NSArray<TSStroke *> *)strokes {
    self = [super init];
    if (self) {
        _title = [(title.length ? title : @"Untitled Sketch") copy];
        _aspect = (aspect > 0.1 && aspect < 10.0) ? aspect : 4.0 / 3.0;
        _themeIdentifier = [(themeIdentifier.length ? themeIdentifier : @"classic") copy];
        _strokes = [strokes copy] ?: @[];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEmpty {
    return self.strokes.count == 0;
}

- (NSUInteger)totalPointCount {
    NSUInteger total = 0;
    for (TSStroke *stroke in self.strokes) {
        total += stroke.vertices.count;
    }
    return total;
}

- (instancetype)drawingByAddingStroke:(TSStroke *)stroke {
    if (!stroke) {
        return self;
    }
    NSMutableArray *strokes = [self.strokes mutableCopy];
    [strokes addObject:stroke];
    return [[[self class] alloc] initWithTitle:self.title
                                        aspect:self.aspect
                             themeIdentifier:self.themeIdentifier
                                      strokes:strokes];
}

- (instancetype)drawingByRemovingStroke:(TSStroke *)stroke {
    if (!stroke) {
        return self;
    }
    NSMutableArray *strokes = [self.strokes mutableCopy];
    NSUInteger index = [strokes indexOfObjectIdenticalTo:stroke];
    if (index == NSNotFound) {
        index = [strokes indexOfObject:stroke];
    }
    if (index == NSNotFound) {
        return self;
    }
    [strokes removeObjectAtIndex:index];
    return [[[self class] alloc] initWithTitle:self.title
                                        aspect:self.aspect
                             themeIdentifier:self.themeIdentifier
                                      strokes:strokes];
}

- (instancetype)drawingByReplacingStrokes:(NSArray<TSStroke *> *)strokes {
    return [[[self class] alloc] initWithTitle:self.title
                                        aspect:self.aspect
                             themeIdentifier:self.themeIdentifier
                                      strokes:strokes ?: @[]];
}

- (instancetype)drawingWithTitle:(NSString *)title {
    return [[[self class] alloc] initWithTitle:title
                                        aspect:self.aspect
                             themeIdentifier:self.themeIdentifier
                                      strokes:self.strokes];
}

- (instancetype)drawingWithThemeIdentifier:(NSString *)themeIdentifier {
    return [[[self class] alloc] initWithTitle:self.title
                                        aspect:self.aspect
                             themeIdentifier:themeIdentifier
                                      strokes:self.strokes];
}

- (NSDictionary<NSString *, id> *)JSONObject {
    NSMutableArray *strokeObjects = [NSMutableArray arrayWithCapacity:self.strokes.count];
    for (TSStroke *stroke in self.strokes) {
        [strokeObjects addObject:[stroke JSONObject]];
    }
    return @{
        @"format": @(TSDrawingFormatVersion),
        @"title": self.title,
        @"aspect": @(self.aspect),
        @"theme": self.themeIdentifier,
        @"strokes": strokeObjects
    };
}

- (nullable NSData *)JSONDataWithError:(NSError **)error {
    return [NSJSONSerialization dataWithJSONObject:[self JSONObject]
                                           options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                             error:error];
}

+ (instancetype)drawingWithJSONObject:(NSDictionary *)dictionary error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey: @"The drawing file is not a JSON object."}];
        }
        return nil;
    }

    NSNumber *format = dictionary[@"format"];
    if (format && format.integerValue > TSDrawingFormatVersion) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorUnsupportedVersion
                                     userInfo:@{NSLocalizedDescriptionKey: @"This drawing was made with a newer version of Telesketch."}];
        }
        return nil;
    }

    NSArray *rawStrokes = dictionary[@"strokes"];
    if (rawStrokes && ![rawStrokes isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidShape
                                     userInfo:@{NSLocalizedDescriptionKey: @"The drawing's strokes are malformed."}];
        }
        return nil;
    }

    NSMutableArray<TSStroke *> *strokes = [NSMutableArray array];
    for (NSDictionary *rawStroke in rawStrokes) {
        if (![rawStroke isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        TSStroke *stroke = [TSStroke strokeWithJSONObject:rawStroke error:NULL];
        if (stroke) {
            [strokes addObject:stroke];
        }
    }

    NSString *title = [dictionary[@"title"] isKindOfClass:[NSString class]] ? dictionary[@"title"] : @"Untitled Sketch";
    NSString *theme = [dictionary[@"theme"] isKindOfClass:[NSString class]] ? dictionary[@"theme"] : @"classic";
    double aspect = [dictionary[@"aspect"] doubleValue];
    return [[self alloc] initWithTitle:title aspect:aspect themeIdentifier:theme strokes:strokes];
}

+ (instancetype)drawingWithJSONData:(NSData *)data error:(NSError **)error {
    if (data.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey: @"The drawing file is empty."}];
        }
        return nil;
    }
    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!object) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidJSON
                                     userInfo:@{NSLocalizedDescriptionKey: @"The drawing file isn't valid JSON.",
                                                NSUnderlyingErrorKey: jsonError ?: [NSNull null]}];
        }
        return nil;
    }
    return [self drawingWithJSONObject:object error:error];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<TSDrawing \"%@\" %lu strokes theme=%@>",
            self.title, (unsigned long)self.strokes.count, self.themeIdentifier];
}

@end
