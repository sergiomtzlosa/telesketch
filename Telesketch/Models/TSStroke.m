#import "TSStroke.h"

NSNotificationName const TSDrawingDidChangeNotification = @"TSDrawingDidChangeNotification";
NSErrorDomain const TSSketchErrorDomain = @"com.sid.telesketch.error";

NSString *TSColorRoleToString(TSColorRole role) {
    switch (role) {
        case TSColorRoleInk: return @"ink";
        case TSColorRoleVermilion: return @"vermilion";
        case TSColorRoleTeal: return @"teal";
        case TSColorRoleOchre: return @"ochre";
        case TSColorRoleBlue: return @"blue";
        case TSColorRoleCustom: return @"custom";
    }
    return @"ink";
}

TSColorRole TSColorRoleFromString(NSString *string) {
    NSString *lower = string.lowercaseString;
    if ([lower isEqualToString:@"vermilion"]) return TSColorRoleVermilion;
    if ([lower isEqualToString:@"teal"]) return TSColorRoleTeal;
    if ([lower isEqualToString:@"ochre"]) return TSColorRoleOchre;
    if ([lower isEqualToString:@"blue"]) return TSColorRoleBlue;
    if ([lower isEqualToString:@"custom"]) return TSColorRoleCustom;
    return TSColorRoleInk;
}

@implementation TSStroke

+ (instancetype)strokeWithVertices:(NSArray<TSVertex *> *)vertices
                             width:(double)width
                              role:(TSColorRole)role
                          colorHex:(nullable NSString *)colorHex
                              tool:(NSString *)tool {
    return [[self alloc] initWithVertices:vertices width:width role:role colorHex:colorHex tool:tool];
}

- (instancetype)initWithVertices:(NSArray<TSVertex *> *)vertices
                           width:(double)width
                            role:(TSColorRole)role
                        colorHex:(nullable NSString *)colorHex
                            tool:(NSString *)tool {
    self = [super init];
    if (self) {
        _vertices = [vertices copy] ?: @[];
        _width = MAX(0.5, MIN(16.0, width));
        _role = role;
        _colorHex = [[(colorHex ?: @"") uppercaseString] copy];
        _tool = [tool copy] ?: @"pen";
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSDictionary<NSString *, id> *)JSONObject {
    NSMutableArray *points = [NSMutableArray arrayWithCapacity:self.vertices.count];
    for (TSVertex *vertex in self.vertices) {
        [points addObject:[vertex JSONArray]];
    }
    NSMutableDictionary *object = [NSMutableDictionary dictionary];
    object[@"points"] = points;
    object[@"width"] = @(self.width);
    object[@"role"] = TSColorRoleToString(self.role);
    object[@"tool"] = self.tool;
    if (self.colorHex.length > 0) {
        object[@"color"] = self.colorHex;
    }
    return object;
}

+ (instancetype)strokeWithJSONObject:(NSDictionary *)dictionary error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidShape
                                     userInfo:@{NSLocalizedDescriptionKey: @"A stroke was not an object."}];
        }
        return nil;
    }
    NSArray *rawPoints = dictionary[@"points"];
    if (![rawPoints isKindOfClass:[NSArray class]] || rawPoints.count < 2) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidShape
                                     userInfo:@{NSLocalizedDescriptionKey: @"A stroke needs at least two points."}];
        }
        return nil;
    }
    NSMutableArray<TSVertex *> *vertices = [NSMutableArray arrayWithCapacity:rawPoints.count];
    for (NSArray *point in rawPoints) {
        TSVertex *vertex = [TSVertex vertexWithJSONArray:point];
        if (vertex) {
            [vertices addObject:vertex];
        }
    }
    if (vertices.count < 2) {
        if (error) {
            *error = [NSError errorWithDomain:TSSketchErrorDomain
                                         code:TSSketchErrorInvalidShape
                                     userInfo:@{NSLocalizedDescriptionKey: @"A stroke had no valid points."}];
        }
        return nil;
    }
    double width = [dictionary[@"width"] doubleValue];
    if (width <= 0) {
        width = 3.0;
    }
    NSString *roleString = [dictionary[@"role"] isKindOfClass:[NSString class]] ? dictionary[@"role"] : @"ink";
    NSString *color = [dictionary[@"color"] isKindOfClass:[NSString class]] ? dictionary[@"color"] : @"";
    NSString *tool = [dictionary[@"tool"] isKindOfClass:[NSString class]] ? dictionary[@"tool"] : @"pen";
    return [self strokeWithVertices:vertices
                              width:width
                               role:TSColorRoleFromString(roleString)
                           colorHex:color
                               tool:tool];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TSStroke class]]) {
        return NO;
    }
    TSStroke *other = object;
    return [self.vertices isEqualToArray:other.vertices] &&
           fabs(self.width - other.width) < 1e-9 &&
           self.role == other.role &&
           [self.colorHex isEqualToString:other.colorHex] &&
           [self.tool isEqualToString:other.tool];
}

- (NSUInteger)hash {
    return self.vertices.count * 31 + (NSUInteger)(self.width * 100) + self.role;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<TSStroke %lu pts role=%@ width=%.1f>",
            (unsigned long)self.vertices.count, TSColorRoleToString(self.role), self.width];
}

@end
