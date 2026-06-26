#import "TSVertex.h"

@implementation TSVertex

+ (instancetype)vertexWithX:(double)x y:(double)y pressure:(double)pressure {
    return [[self alloc] initWithX:x y:y pressure:pressure];
}

- (instancetype)initWithX:(double)x y:(double)y pressure:(double)pressure {
    self = [super init];
    if (self) {
        _x = MAX(0.0, MIN(1.0, x));
        _y = MAX(0.0, MIN(1.0, y));
        _pressure = MAX(0.0, MIN(1.0, pressure));
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSArray<NSNumber *> *)JSONArray {
    return @[@(self.x), @(self.y), @(self.pressure)];
}

+ (instancetype)vertexWithJSONArray:(NSArray *)array {
    if (![array isKindOfClass:[NSArray class]] || array.count < 2) {
        return nil;
    }
    double x = [array[0] doubleValue];
    double y = [array[1] doubleValue];
    double pressure = array.count > 2 ? [array[2] doubleValue] : 0.55;
    return [self vertexWithX:x y:y pressure:pressure];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TSVertex class]]) {
        return NO;
    }
    TSVertex *other = object;
    return fabs(self.x - other.x) < 1e-9 &&
           fabs(self.y - other.y) < 1e-9 &&
           fabs(self.pressure - other.pressure) < 1e-9;
}

- (NSUInteger)hash {
    return (NSUInteger)(self.x * 73856093.0) ^ (NSUInteger)(self.y * 19349663.0);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<TSVertex %.3f,%.3f p=%.2f>", self.x, self.y, self.pressure];
}

@end
