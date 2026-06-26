#import "TSOfflineSketchEngine.h"
#import <math.h>

typedef struct {
    uint64_t state;
} TSRandom;

static uint64_t TSRandomNext(TSRandom *rng) {
    rng->state = rng->state * 6364136223846793005ULL + 1442695040888963407ULL;
    return rng->state;
}

static double TSRandomUnit(TSRandom *rng) {
    return (double)(TSRandomNext(rng) >> 11) * (1.0 / 9007199254740992.0);
}

static double TSRandomRange(TSRandom *rng, double low, double high) {
    return low + (high - low) * TSRandomUnit(rng);
}

static NSValue *TSV(double x, double y) {
    return [NSValue valueWithPoint:NSMakePoint(x, y)];
}

static NSArray<NSValue *> *TSLine(double x1, double y1, double x2, double y2, NSInteger steps) {
    NSMutableArray *points = [NSMutableArray array];
    for (NSInteger i = 0; i <= steps; i++) {
        double t = (double)i / (double)MAX(1, steps);
        [points addObject:TSV(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t)];
    }
    return points;
}

static NSArray<NSValue *> *TSArc(double cx, double cy, double rx, double ry,
                                 double startAngle, double endAngle, NSInteger steps) {
    NSMutableArray *points = [NSMutableArray array];
    for (NSInteger i = 0; i <= steps; i++) {
        double t = (double)i / (double)MAX(1, steps);
        double angle = startAngle + (endAngle - startAngle) * t;
        [points addObject:TSV(cx + cos(angle) * rx, cy + sin(angle) * ry)];
    }
    return points;
}

static NSArray<NSValue *> *TSBezier(double x0, double y0,
                                    double x1, double y1,
                                    double x2, double y2,
                                    double x3, double y3) {
    NSInteger steps = 18;
    NSMutableArray *points = [NSMutableArray array];
    for (NSInteger i = 0; i <= steps; i++) {
        double t = (double)i / (double)MAX(1, steps);
        double mt = 1.0 - t;
        double x = mt * mt * mt * x0 + 3 * mt * mt * t * x1 + 3 * mt * t * t * x2 + t * t * t * x3;
        double y = mt * mt * mt * y0 + 3 * mt * mt * t * y1 + 3 * mt * t * t * y2 + t * t * t * y3;
        [points addObject:TSV(x, y)];
    }
    return points;
}

static NSArray<NSValue *> *TSJoin(NSArray<NSValue *> *first, NSArray<NSValue *> *second) {
    NSMutableArray *points = [NSMutableArray arrayWithArray:first ?: @[]];
    [points addObjectsFromArray:second ?: @[]];
    return points;
}

static NSArray<NSValue *> *TSClosed(NSArray<NSValue *> *points) {
    if (points.count == 0) return points;
    return TSJoin(points, @[points.firstObject]);
}

static NSArray<NSValue *> *TSJitter(NSArray<NSValue *> *points, double amount, TSRandom *rng) {
    if (amount <= 0) return points;
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:points.count];
    for (NSUInteger i = 0; i < points.count; i++) {
        NSPoint p = [points[i] pointValue];
        double edgeFactor = (i == 0 || i == points.count - 1) ? 0.25 : 1.0;
        [out addObject:TSV(p.x + TSRandomRange(rng, -amount, amount) * edgeFactor,
                           p.y + TSRandomRange(rng, -amount, amount) * edgeFactor)];
    }
    return out;
}

static void TSAdd(NSMutableArray<TSStroke *> *strokes,
                  NSArray<NSValue *> *points,
                  TSColorRole role,
                  double width,
                  NSString *tool) {
    if (points.count < 2) return;
    NSMutableArray<TSVertex *> *vertices = [NSMutableArray arrayWithCapacity:points.count];
    for (NSValue *value in points) {
        NSPoint p = value.pointValue;
        double pressure = 0.48 + 0.18 * sin(p.x * 23.0 + p.y * 17.0);
        [vertices addObject:[TSVertex vertexWithX:p.x y:p.y pressure:pressure]];
    }
    TSStroke *stroke = [TSStroke strokeWithVertices:vertices width:width role:role colorHex:nil tool:tool];
    [strokes addObject:stroke];
}

static void TSAddJittered(NSMutableArray<TSStroke *> *strokes,
                          NSArray<NSValue *> *points,
                          TSColorRole role,
                          double width,
                          double jitter,
                          TSRandom *rng) {
    TSAdd(strokes, TSJitter(points, jitter, rng), role, width, @"offline");
}

static BOOL TSContainsAny(NSString *prompt, NSArray<NSString *> *needles) {
    for (NSString *needle in needles) {
        if ([prompt rangeOfString:needle].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL TSIsDetailed(NSString *prompt) {
    return TSContainsAny(prompt, @[@"detail", @"complex", @"ornate", @"intricate", @"comic"]);
}

static double TSLineWidth(TSRandom *rng, double base) {
    return base + TSRandomRange(rng, -0.35, 0.45);
}

#pragma mark - Scenes

static void TSDrawCat(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 3.1);
    // Head
    TSAddJittered(strokes, TSArc(0.50, 0.35, 0.175, 0.155, -M_PI_2, M_PI * 1.5, 34), TSColorRoleInk, inkW, 0.0035, rng);
    // Ears
    TSAddJittered(strokes, TSClosed(@[TSV(0.365, 0.245), TSV(0.335, 0.09), TSV(0.455, 0.205)]), TSColorRoleInk, inkW, 0.003, rng);
    TSAddJittered(strokes, TSClosed(@[TSV(0.635, 0.245), TSV(0.665, 0.09), TSV(0.545, 0.205)]), TSColorRoleInk, inkW, 0.003, rng);
    // Inner ears
    TSAddJittered(strokes, TSClosed(@[TSV(0.385, 0.215), TSV(0.365, 0.135), TSV(0.425, 0.20)]), TSColorRoleVermilion, 1.8, 0.002, rng);
    TSAddJittered(strokes, TSClosed(@[TSV(0.615, 0.215), TSV(0.635, 0.135), TSV(0.575, 0.20)]), TSColorRoleVermilion, 1.8, 0.002, rng);
    // Eyes
    TSAdd(strokes, TSArc(0.435, 0.345, 0.024, 0.034, 0, M_PI * 2, 16), TSColorRoleInk, TSLineWidth(rng, 2.2), @"offline");
    TSAdd(strokes, TSArc(0.565, 0.345, 0.024, 0.034, 0, M_PI * 2, 16), TSColorRoleInk, TSLineWidth(rng, 2.2), @"offline");
    // Nose and mouth
    TSAdd(strokes, TSClosed(@[TSV(0.482, 0.415), TSV(0.518, 0.415), TSV(0.500, 0.438)]), TSColorRoleVermilion, 2.0, @"offline");
    TSAddJittered(strokes, TSBezier(0.500, 0.438, 0.500, 0.465, 0.468, 0.47, 0.452, 0.452), TSColorRoleInk, 1.8, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.500, 0.438, 0.500, 0.465, 0.532, 0.47, 0.548, 0.452), TSColorRoleInk, 1.8, 0.002, rng);
    // Whiskers
    for (NSInteger i = 0; i < 3; i++) {
        double y = 0.405 + i * 0.026;
        TSAddJittered(strokes, TSLine(0.43, y, 0.275, y - 0.025 + i * 0.018, 6), TSColorRoleInk, 1.4, 0.002, rng);
        TSAddJittered(strokes, TSLine(0.57, y, 0.725, y - 0.025 + i * 0.018, 6), TSColorRoleInk, 1.4, 0.002, rng);
    }
    // Body outline
    NSArray *body = TSJoin(TSBezier(0.345, 0.47, 0.28, 0.56, 0.29, 0.78, 0.365, 0.845),
                           TSBezier(0.365, 0.845, 0.44, 0.875, 0.56, 0.875, 0.635, 0.845));
    body = TSJoin(body, TSBezier(0.635, 0.845, 0.71, 0.78, 0.72, 0.56, 0.655, 0.47));
    TSAddJittered(strokes, body, TSColorRoleInk, inkW, 0.003, rng);
    // Chest line
    TSAddJittered(strokes, TSBezier(0.455, 0.49, 0.43, 0.59, 0.45, 0.72, 0.455, 0.82), TSColorRoleInk, 2.1, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.545, 0.49, 0.57, 0.59, 0.55, 0.72, 0.545, 0.82), TSColorRoleInk, 2.1, 0.002, rng);
    // Paws
    TSAddJittered(strokes, TSArc(0.415, 0.845, 0.055, 0.022, 0, M_PI, 12), TSColorRoleInk, 2.4, 0.002, rng);
    TSAddJittered(strokes, TSArc(0.585, 0.845, 0.055, 0.022, 0, M_PI, 12), TSColorRoleInk, 2.4, 0.002, rng);
    // Tail
    NSArray *tail = TSBezier(0.65, 0.79, 0.80, 0.80, 0.87, 0.66, 0.80, 0.565);
    tail = TSJoin(tail, TSBezier(0.80, 0.565, 0.75, 0.50, 0.68, 0.53, 0.70, 0.585));
    TSAddJittered(strokes, tail, TSColorRoleInk, inkW, 0.003, rng);
    // Hatching
    NSInteger hatchCount = detailed ? 7 : 4;
    for (NSInteger i = 0; i < hatchCount; i++) {
        double x = 0.58 + i * 0.018;
        TSAdd(strokes, TSLine(x, 0.64 + i * 0.012, x + 0.045, 0.70 + i * 0.012, 4), TSColorRoleInk, 1.2, @"offline");
    }
    // Ground
    TSAddJittered(strokes, TSLine(0.13, 0.885, 0.87, 0.885, 20), TSColorRoleInk, 1.5, 0.002, rng);
    for (NSInteger i = 0; i < 5; i++) {
        double x = 0.16 + i * 0.16;
        TSAdd(strokes, TSLine(x, 0.885, x - 0.012, 0.855, 3), TSColorRoleTeal, 1.3, @"offline");
        TSAdd(strokes, TSLine(x + 0.012, 0.885, x + 0.025, 0.852, 3), TSColorRoleTeal, 1.3, @"offline");
    }
}

static void TSDrawHouse(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.8);
    // Ground
    TSAddJittered(strokes, TSLine(0.08, 0.855, 0.92, 0.855, 24), TSColorRoleInk, 1.6, 0.002, rng);
    // Body
    TSAddJittered(strokes, TSClosed(@[TSV(0.25, 0.43), TSV(0.67, 0.43), TSV(0.67, 0.855), TSV(0.25, 0.855)]), TSColorRoleInk, inkW, 0.003, rng);
    // Roof
    TSAddJittered(strokes, TSClosed(@[TSV(0.19, 0.43), TSV(0.46, 0.16), TSV(0.73, 0.43)]), TSColorRoleInk, inkW + 0.3, 0.003, rng);
    // Roof hatching
    for (NSInteger i = 0; i < (detailed ? 8 : 5); i++) {
        double x = 0.28 + i * 0.055;
        TSAdd(strokes, TSLine(x, 0.42, x + 0.10, 0.31, 4), TSColorRoleInk, 1.2, @"offline");
    }
    // Chimney
    TSAddJittered(strokes, TSClosed(@[TSV(0.56, 0.24), TSV(0.625, 0.24), TSV(0.625, 0.36), TSV(0.56, 0.36)]), TSColorRoleInk, 2.2, 0.002, rng);
    // Smoke
    TSAddJittered(strokes, TSBezier(0.595, 0.22, 0.55, 0.16, 0.65, 0.12, 0.60, 0.06), TSColorRoleTeal, 1.7, 0.004, rng);
    TSAddJittered(strokes, TSBezier(0.60, 0.14, 0.68, 0.10, 0.55, 0.055, 0.66, 0.025), TSColorRoleTeal, 1.5, 0.004, rng);
    // Door
    TSAddJittered(strokes, TSClosed(@[TSV(0.415, 0.635), TSV(0.525, 0.635), TSV(0.525, 0.855), TSV(0.415, 0.855)]), TSColorRoleInk, 2.3, 0.002, rng);
    TSAdd(strokes, TSArc(0.495, 0.75, 0.009, 0.009, 0, M_PI * 2, 10), TSColorRoleOchre, 2.0, @"offline");
    // Windows
    for (NSInteger i = 0; i < 2; i++) {
        double x = 0.295 + i * 0.245;
        TSAddJittered(strokes, TSClosed(@[TSV(x, 0.49), TSV(x + 0.075, 0.49), TSV(x + 0.075, 0.57), TSV(x, 0.57)]), TSColorRoleInk, 2.0, 0.002, rng);
        TSAdd(strokes, TSLine(x + 0.0375, 0.49, x + 0.0375, 0.57, 4), TSColorRoleInk, 1.3, @"offline");
        TSAdd(strokes, TSLine(x, 0.53, x + 0.075, 0.53, 4), TSColorRoleInk, 1.3, @"offline");
    }
    // Sun
    TSAdd(strokes, TSArc(0.84, 0.18, 0.055, 0.055, 0, M_PI * 2, 24), TSColorRoleOchre, 2.0, @"offline");
    for (NSInteger i = 0; i < 8; i++) {
        double angle = i * M_PI / 4.0;
        TSAdd(strokes, TSLine(0.84 + cos(angle) * 0.07, 0.18 + sin(angle) * 0.07,
                              0.84 + cos(angle) * 0.095, 0.18 + sin(angle) * 0.095, 3), TSColorRoleOchre, 1.4, @"offline");
    }
    // Tree
    TSAddJittered(strokes, TSBezier(0.80, 0.855, 0.80, 0.72, 0.77, 0.67, 0.78, 0.58), TSColorRoleInk, 2.4, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.80, 0.855, 0.80, 0.72, 0.83, 0.67, 0.82, 0.58), TSColorRoleInk, 2.4, 0.002, rng);
    TSAddJittered(strokes, TSArc(0.80, 0.50, 0.11, 0.10, 0, M_PI * 2, 26), TSColorRoleTeal, 2.1, 0.004, rng);
    TSAddJittered(strokes, TSArc(0.73, 0.54, 0.07, 0.065, 0, M_PI * 2, 20), TSColorRoleTeal, 1.8, 0.004, rng);
    TSAddJittered(strokes, TSArc(0.87, 0.54, 0.07, 0.06, 0, M_PI * 2, 20), TSColorRoleTeal, 1.8, 0.004, rng);
    // Path
    TSAddJittered(strokes, TSLine(0.47, 0.855, 0.40, 0.94, 8), TSColorRoleInk, 1.4, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.50, 0.855, 0.57, 0.94, 8), TSColorRoleInk, 1.4, 0.002, rng);
}

static void TSDrawTree(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 3.0);
    TSAddJittered(strokes, TSLine(0.12, 0.88, 0.88, 0.88, 20), TSColorRoleInk, 1.5, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.44, 0.88, 0.41, 0.70, 0.48, 0.55, 0.46, 0.38), TSColorRoleInk, inkW, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.56, 0.88, 0.59, 0.70, 0.52, 0.55, 0.54, 0.38), TSColorRoleInk, inkW, 0.003, rng);
    TSAddJittered(strokes, TSLine(0.46, 0.88, 0.39, 0.92, 4), TSColorRoleInk, 2.2, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.54, 0.88, 0.61, 0.92, 4), TSColorRoleInk, 2.2, 0.002, rng);
    // Branches
    TSAddJittered(strokes, TSLine(0.46, 0.55, 0.35, 0.43, 7), TSColorRoleInk, 2.2, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.54, 0.52, 0.66, 0.40, 7), TSColorRoleInk, 2.2, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.47, 0.44, 0.43, 0.33, 6), TSColorRoleInk, 2.0, 0.002, rng);
    // Foliage
    TSAddJittered(strokes, TSArc(0.50, 0.27, 0.26, 0.18, M_PI * 0.95, M_PI * 2.05, 34), TSColorRoleTeal, 2.5, 0.005, rng);
    TSAddJittered(strokes, TSArc(0.38, 0.31, 0.14, 0.13, 0, M_PI * 2, 22), TSColorRoleTeal, 2.0, 0.005, rng);
    TSAddJittered(strokes, TSArc(0.62, 0.31, 0.15, 0.13, 0, M_PI * 2, 22), TSColorRoleTeal, 2.0, 0.005, rng);
    TSAddJittered(strokes, TSArc(0.50, 0.42, 0.22, 0.12, 0, M_PI, 20), TSColorRoleTeal, 2.0, 0.005, rng);
    // Leaf marks
    NSInteger leafCount = detailed ? 9 : 5;
    for (NSInteger i = 0; i < leafCount; i++) {
        double x = 0.32 + i * 0.045;
        double y = 0.20 + (i % 3) * 0.045;
        TSAdd(strokes, TSArc(x, y, 0.022, 0.010, 0, M_PI * 2, 8), TSColorRoleTeal, 1.2, @"offline");
    }
    // Grass
    for (NSInteger i = 0; i < 7; i++) {
        double x = 0.18 + i * 0.11;
        TSAdd(strokes, TSLine(x, 0.88, x - 0.012, 0.845, 3), TSColorRoleTeal, 1.2, @"offline");
        TSAdd(strokes, TSLine(x + 0.01, 0.88, x + 0.024, 0.84, 3), TSColorRoleTeal, 1.2, @"offline");
    }
}

static void TSDrawFlower(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.8);
    TSAddJittered(strokes, TSLine(0.12, 0.88, 0.88, 0.88, 20), TSColorRoleInk, 1.4, 0.002, rng);
    // Stem
    TSAddJittered(strokes, TSBezier(0.51, 0.88, 0.47, 0.70, 0.54, 0.55, 0.50, 0.36), TSColorRoleTeal, 2.9, 0.003, rng);
    // Leaves
    TSAddJittered(strokes, TSBezier(0.50, 0.68, 0.36, 0.63, 0.30, 0.52, 0.38, 0.49), TSColorRoleTeal, 2.1, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.38, 0.49, 0.45, 0.55, 0.49, 0.60, 0.50, 0.68), TSColorRoleTeal, 2.1, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.52, 0.62, 0.65, 0.56, 0.72, 0.47, 0.63, 0.43), TSColorRoleTeal, 2.1, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.63, 0.43, 0.57, 0.49, 0.53, 0.55, 0.52, 0.62), TSColorRoleTeal, 2.1, 0.003, rng);
    // Petals
    NSInteger petals = 7;
    for (NSInteger i = 0; i < petals; i++) {
        double angle = i * 2.0 * M_PI / petals - M_PI_2;
        double cx = 0.50 + cos(angle) * 0.105;
        double cy = 0.27 + sin(angle) * 0.105;
        NSArray *petal = TSBezier(0.50, 0.27, 0.50 + cos(angle - 0.55) * 0.15, 0.27 + sin(angle - 0.55) * 0.15,
                                  cx + cos(angle) * 0.06, cy + sin(angle) * 0.06, cx + cos(angle) * 0.075, cy + sin(angle) * 0.075);
        petal = TSJoin(petal, TSBezier(cx + cos(angle) * 0.075, cy + sin(angle) * 0.075,
                                       cx + cos(angle + 0.5) * 0.055, cy + sin(angle + 0.5) * 0.055,
                                       0.50 + cos(angle + 0.55) * 0.15, 0.27 + sin(angle + 0.55) * 0.15,
                                       0.50, 0.27));
        TSAddJittered(strokes, petal, i % 3 == 0 ? TSColorRoleVermilion : TSColorRoleOchre, 2.0, 0.003, rng);
    }
    // Center
    TSAdd(strokes, TSArc(0.50, 0.27, 0.045, 0.045, 0, M_PI * 2, 20), TSColorRoleInk, 2.0, @"offline");
    TSAdd(strokes, TSArc(0.50, 0.27, 0.022, 0.022, 0, M_PI * 1.6, 12), TSColorRoleOchre, 1.6, @"offline");
    // Grass
    NSInteger grass = detailed ? 9 : 5;
    for (NSInteger i = 0; i < grass; i++) {
        double x = 0.16 + i * 0.085;
        TSAdd(strokes, TSLine(x, 0.88, x - 0.010, 0.845, 3), TSColorRoleTeal, 1.2, @"offline");
        TSAdd(strokes, TSLine(x + 0.008, 0.88, x + 0.022, 0.84, 3), TSColorRoleTeal, 1.2, @"offline");
    }
    // Little sun
    TSAdd(strokes, TSArc(0.83, 0.17, 0.045, 0.045, 0, M_PI * 2, 18), TSColorRoleOchre, 1.7, @"offline");
    (void)inkW;
}

static void TSDrawMountain(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 3.0);
    // Sun
    TSAdd(strokes, TSArc(0.79, 0.19, 0.065, 0.065, 0, M_PI * 2, 24), TSColorRoleOchre, 2.2, @"offline");
    for (NSInteger i = 0; i < 8; i++) {
        double angle = i * M_PI / 4;
        TSAdd(strokes, TSLine(0.79 + cos(angle) * 0.08, 0.19 + sin(angle) * 0.08,
                              0.79 + cos(angle) * 0.105, 0.19 + sin(angle) * 0.105, 3), TSColorRoleOchre, 1.4, @"offline");
    }
    // Back peak
    TSAddJittered(strokes, TSClosed(@[TSV(0.07, 0.80), TSV(0.31, 0.31), TSV(0.56, 0.80)]), TSColorRoleInk, inkW, 0.004, rng);
    TSAddJittered(strokes, @[TSV(0.225, 0.46), TSV(0.255, 0.50), TSV(0.285, 0.43), TSV(0.315, 0.49), TSV(0.345, 0.42), TSV(0.38, 0.50)], TSColorRoleInk, 1.8, 0.003, rng);
    // Front peak
    TSAddJittered(strokes, TSClosed(@[TSV(0.36, 0.84), TSV(0.62, 0.40), TSV(0.93, 0.84)]), TSColorRoleInk, inkW + 0.3, 0.004, rng);
    TSAddJittered(strokes, @[TSV(0.535, 0.53), TSV(0.565, 0.57), TSV(0.60, 0.49), TSV(0.63, 0.55), TSV(0.66, 0.47), TSV(0.70, 0.57)], TSColorRoleInk, 1.9, 0.003, rng);
    // Shading
    NSInteger shade = detailed ? 8 : 4;
    for (NSInteger i = 0; i < shade; i++) {
        double x = 0.70 + i * 0.022;
        TSAdd(strokes, TSLine(x, 0.84, x + 0.06, 0.74 + i * 0.005, 5), TSColorRoleInk, 1.2, @"offline");
    }
    // Hills
    TSAddJittered(strokes, TSBezier(0.06, 0.80, 0.25, 0.70, 0.38, 0.88, 0.55, 0.84), TSColorRoleTeal, 2.0, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.55, 0.84, 0.70, 0.76, 0.85, 0.88, 0.96, 0.82), TSColorRoleTeal, 2.0, 0.003, rng);
    // Birds
    for (NSInteger i = 0; i < 3; i++) {
        double x = 0.58 + i * 0.08;
        double y = 0.20 + (i % 2) * 0.06;
        TSAdd(strokes, TSBezier(x - 0.035, y, x - 0.015, y - 0.02, x - 0.005, y - 0.005, x, y), TSColorRoleInk, 1.5, @"offline");
        TSAdd(strokes, TSBezier(x, y, x + 0.005, y - 0.005, x + 0.015, y - 0.02, x + 0.035, y), TSColorRoleInk, 1.5, @"offline");
    }
    // Foreground pines
    for (NSInteger i = 0; i < 2; i++) {
        double x = 0.15 + i * 0.68;
        TSAddJittered(strokes, TSLine(x, 0.90, x, 0.80, 4), TSColorRoleInk, 2.0, 0.002, rng);
        TSAddJittered(strokes, TSClosed(@[TSV(x - 0.055, 0.82), TSV(x, 0.73), TSV(x + 0.055, 0.82)]), TSColorRoleTeal, 2.0, 0.003, rng);
        TSAddJittered(strokes, TSClosed(@[TSV(x - 0.07, 0.87), TSV(x, 0.78), TSV(x + 0.07, 0.87)]), TSColorRoleTeal, 2.0, 0.003, rng);
    }
    // Ground
    TSAddJittered(strokes, TSLine(0.05, 0.92, 0.95, 0.92, 22), TSColorRoleInk, 1.5, 0.002, rng);
}

static void TSDrawRocket(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 3.1);
    // Body
    NSArray *body = TSJoin(@[TSV(0.50, 0.10)], TSBezier(0.50, 0.10, 0.62, 0.22, 0.63, 0.42, 0.61, 0.70));
    body = TSJoin(body, TSLine(0.61, 0.70, 0.39, 0.70, 8));
    body = TSJoin(body, TSBezier(0.39, 0.70, 0.37, 0.42, 0.38, 0.22, 0.50, 0.10));
    TSAddJittered(strokes, body, TSColorRoleInk, inkW, 0.003, rng);
    // Window
    TSAdd(strokes, TSArc(0.50, 0.34, 0.075, 0.075, 0, M_PI * 2, 26), TSColorRoleInk, 2.3, @"offline");
    TSAdd(strokes, TSArc(0.50, 0.34, 0.052, 0.052, 0, M_PI * 2, 22), TSColorRoleTeal, 2.0, @"offline");
    TSAdd(strokes, TSArc(0.48, 0.32, 0.018, 0.018, 0, M_PI * 2, 10), TSColorRoleTeal, 1.4, @"offline");
    // Fins
    TSAddJittered(strokes, TSClosed(@[TSV(0.39, 0.55), TSV(0.25, 0.75), TSV(0.27, 0.50), TSV(0.39, 0.64)]), TSColorRoleVermilion, 2.3, 0.003, rng);
    TSAddJittered(strokes, TSClosed(@[TSV(0.61, 0.55), TSV(0.75, 0.75), TSV(0.73, 0.50), TSV(0.61, 0.64)]), TSColorRoleVermilion, 2.3, 0.003, rng);
    // Nozzle
    TSAddJittered(strokes, TSClosed(@[TSV(0.43, 0.70), TSV(0.57, 0.70), TSV(0.54, 0.77), TSV(0.46, 0.77)]), TSColorRoleInk, 2.2, 0.002, rng);
    // Flames
    TSAddJittered(strokes, TSBezier(0.46, 0.78, 0.44, 0.86, 0.48, 0.90, 0.47, 0.95), TSColorRoleOchre, 2.4, 0.004, rng);
    TSAddJittered(strokes, TSBezier(0.50, 0.78, 0.50, 0.88, 0.54, 0.92, 0.51, 0.97), TSColorRoleVermilion, 2.7, 0.004, rng);
    TSAddJittered(strokes, TSBezier(0.54, 0.78, 0.56, 0.86, 0.52, 0.90, 0.54, 0.94), TSColorRoleOchre, 2.2, 0.004, rng);
    // Stars
    NSInteger stars = detailed ? 8 : 5;
    for (NSInteger i = 0; i < stars; i++) {
        double x = 0.12 + (i * 0.11);
        double y = 0.12 + (i % 3) * 0.12;
        TSAdd(strokes, TSLine(x - 0.018, y, x + 0.018, y, 3), TSColorRoleOchre, 1.3, @"offline");
        TSAdd(strokes, TSLine(x, y - 0.018, x, y + 0.018, 3), TSColorRoleOchre, 1.3, @"offline");
    }
    // Motion lines
    TSAdd(strokes, TSLine(0.18, 0.30, 0.30, 0.30, 5), TSColorRoleTeal, 1.5, @"offline");
    TSAdd(strokes, TSLine(0.14, 0.37, 0.27, 0.37, 5), TSColorRoleTeal, 1.5, @"offline");
    TSAdd(strokes, TSLine(0.75, 0.30, 0.87, 0.30, 5), TSColorRoleTeal, 1.5, @"offline");
    // Planet
    TSAdd(strokes, TSArc(0.84, 0.75, 0.09, 0.09, 0, M_PI * 2, 22), TSColorRoleTeal, 2.1, @"offline");
    TSAdd(strokes, TSLine(0.74, 0.72, 0.95, 0.72, 8), TSColorRoleTeal, 1.4, @"offline");
}

static void TSDrawCar(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.9);
    // Body
    NSArray *body = @[TSV(0.12, 0.64), TSV(0.16, 0.52), TSV(0.30, 0.49), TSV(0.38, 0.35), TSV(0.64, 0.35), TSV(0.73, 0.49), TSV(0.88, 0.54), TSV(0.89, 0.67), TSV(0.12, 0.67)];
    TSAddJittered(strokes, TSClosed(body), TSColorRoleInk, inkW, 0.003, rng);
    // Roof
    TSAddJittered(strokes, TSBezier(0.38, 0.35, 0.46, 0.30, 0.57, 0.30, 0.64, 0.35), TSColorRoleInk, 2.4, 0.003, rng);
    // Windows
    TSAddJittered(strokes, TSClosed(@[TSV(0.40, 0.355), TSV(0.47, 0.355), TSV(0.47, 0.47), TSV(0.35, 0.47), TSV(0.40, 0.355)]), TSColorRoleTeal, 1.9, 0.002, rng);
    TSAddJittered(strokes, TSClosed(@[TSV(0.50, 0.355), TSV(0.62, 0.355), TSV(0.69, 0.47), TSV(0.50, 0.47)]), TSColorRoleTeal, 1.9, 0.002, rng);
    // Wheels
    for (NSInteger i = 0; i < 2; i++) {
        double cx = 0.30 + i * 0.41;
        TSAdd(strokes, TSArc(cx, 0.69, 0.085, 0.085, 0, M_PI * 2, 24), TSColorRoleInk, 3.0, @"offline");
        TSAdd(strokes, TSArc(cx, 0.69, 0.040, 0.040, 0, M_PI * 2, 16), TSColorRoleInk, 2.0, @"offline");
        TSAdd(strokes, TSArc(cx, 0.69, 0.012, 0.012, 0, M_PI * 2, 8), TSColorRoleInk, 1.5, @"offline");
    }
    // Headlight, grille, bumper
    TSAdd(strokes, TSArc(0.86, 0.59, 0.016, 0.016, 0, M_PI * 2, 8), TSColorRoleOchre, 2.0, @"offline");
    TSAdd(strokes, TSLine(0.84, 0.55, 0.865, 0.55, 4), TSColorRoleOchre, 1.5, @"offline");
    TSAdd(strokes, TSLine(0.17, 0.62, 0.22, 0.62, 4), TSColorRoleVermilion, 2.0, @"offline");
    TSAdd(strokes, TSLine(0.13, 0.685, 0.87, 0.685, 12), TSColorRoleInk, 1.5, @"offline");
    // Road
    TSAddJittered(strokes, TSLine(0.04, 0.82, 0.96, 0.82, 24), TSColorRoleInk, 1.5, 0.002, rng);
    for (NSInteger i = 0; i < 5; i++) {
        double x = 0.10 + i * 0.18;
        TSAdd(strokes, TSLine(x, 0.87, x + 0.08, 0.87, 4), TSColorRoleOchre, 1.6, @"offline");
    }
    if (detailed) {
        TSAdd(strokes, TSLine(0.22, 0.58, 0.34, 0.58, 5), TSColorRoleInk, 1.3, @"offline");
        TSAdd(strokes, TSLine(0.66, 0.58, 0.82, 0.58, 5), TSColorRoleInk, 1.3, @"offline");
    }
}

static void TSDrawFish(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.9);
    // Body
    TSAddJittered(strokes, TSArc(0.47, 0.48, 0.25, 0.16, 0, M_PI * 2, 34), TSColorRoleInk, inkW, 0.003, rng);
    // Tail
    TSAddJittered(strokes, TSClosed(@[TSV(0.70, 0.48), TSV(0.90, 0.34), TSV(0.86, 0.48), TSV(0.90, 0.62)]), TSColorRoleInk, 2.5, 0.003, rng);
    // Fins
    TSAddJittered(strokes, TSBezier(0.44, 0.32, 0.48, 0.22, 0.58, 0.23, 0.62, 0.34), TSColorRoleTeal, 2.1, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.36, 0.50, 0.30, 0.56, 0.35, 0.61, 0.42, 0.60), TSColorRoleTeal, 2.1, 0.003, rng);
    // Eye and mouth
    TSAdd(strokes, TSArc(0.31, 0.43, 0.022, 0.022, 0, M_PI * 2, 12), TSColorRoleInk, 2.1, @"offline");
    TSAdd(strokes, TSArc(0.31, 0.43, 0.007, 0.007, 0, M_PI * 2, 8), TSColorRoleInk, 1.6, @"offline");
    TSAdd(strokes, TSBezier(0.23, 0.50, 0.245, 0.515, 0.26, 0.515, 0.27, 0.505), TSColorRoleVermilion, 1.8, @"offline");
    // Scales
    NSInteger scales = detailed ? 6 : 3;
    for (NSInteger i = 0; i < scales; i++) {
        double x = 0.40 + i * 0.042;
        TSAdd(strokes, TSArc(x, 0.46 + (i % 2) * 0.06, 0.030, 0.031, M_PI * 0.15, M_PI * 0.85, 8), TSColorRoleTeal, 1.2, @"offline");
    }
    // Bubbles
    for (NSInteger i = 0; i < 4; i++) {
        double x = 0.16 + (i % 2) * 0.045;
        double y = 0.20 + i * 0.06;
        TSAdd(strokes, TSArc(x, y, 0.018 + i * 0.003, 0.018 + i * 0.003, 0, M_PI * 2, 10), TSColorRoleTeal, 1.4, @"offline");
    }
    // Water
    TSAddJittered(strokes, TSBezier(0.05, 0.80, 0.25, 0.76, 0.35, 0.84, 0.55, 0.80), TSColorRoleTeal, 1.7, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.45, 0.88, 0.62, 0.85, 0.76, 0.91, 0.95, 0.87), TSColorRoleTeal, 1.7, 0.003, rng);
    // Seaweed
    TSAddJittered(strokes, TSBezier(0.86, 0.88, 0.82, 0.76, 0.90, 0.70, 0.85, 0.60), TSColorRoleTeal, 2.0, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.93, 0.88, 0.89, 0.78, 0.96, 0.73, 0.92, 0.64), TSColorRoleTeal, 1.8, 0.003, rng);
}

static void TSDrawBird(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.9);
    // Body
    TSAddJittered(strokes, TSArc(0.45, 0.50, 0.19, 0.13, 0, M_PI * 2, 30), TSColorRoleInk, inkW, 0.003, rng);
    // Head
    TSAddJittered(strokes, TSArc(0.61, 0.37, 0.085, 0.085, 0, M_PI * 2, 24), TSColorRoleInk, inkW, 0.003, rng);
    // Beak
    TSAddJittered(strokes, TSClosed(@[TSV(0.685, 0.35), TSV(0.79, 0.40), TSV(0.69, 0.42)]), TSColorRoleOchre, 2.2, 0.002, rng);
    // Eye
    TSAdd(strokes, TSArc(0.635, 0.35, 0.014, 0.014, 0, M_PI * 2, 8), TSColorRoleInk, 1.8, @"offline");
    // Wing
    TSAddJittered(strokes, TSBezier(0.38, 0.44, 0.46, 0.38, 0.58, 0.43, 0.55, 0.54), TSColorRoleTeal, 2.2, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.38, 0.44, 0.34, 0.50, 0.40, 0.55, 0.50, 0.58), TSColorRoleTeal, 1.8, 0.003, rng);
    // Tail
    TSAddJittered(strokes, TSLine(0.27, 0.53, 0.10, 0.64, 6), TSColorRoleInk, 2.2, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.28, 0.56, 0.12, 0.70, 6), TSColorRoleInk, 1.8, 0.002, rng);
    // Legs
    TSAdd(strokes, TSLine(0.47, 0.62, 0.46, 0.72, 4), TSColorRoleInk, 1.8, @"offline");
    TSAdd(strokes, TSLine(0.52, 0.62, 0.53, 0.72, 4), TSColorRoleInk, 1.8, @"offline");
    TSAdd(strokes, TSLine(0.46, 0.72, 0.43, 0.745, 3), TSColorRoleInk, 1.5, @"offline");
    TSAdd(strokes, TSLine(0.53, 0.72, 0.56, 0.745, 3), TSColorRoleInk, 1.5, @"offline");
    // Branch
    TSAddJittered(strokes, TSBezier(0.06, 0.78, 0.30, 0.74, 0.64, 0.79, 0.95, 0.76), TSColorRoleInk, 2.4, 0.003, rng);
    // Leaves
    for (NSInteger i = 0; i < (detailed ? 5 : 3); i++) {
        double x = 0.16 + i * 0.16;
        TSAdd(strokes, TSArc(x, 0.755, 0.035, 0.014, M_PI, M_PI * 2, 10), TSColorRoleTeal, 1.4, @"offline");
    }
    // Clouds
    TSAddJittered(strokes, TSBezier(0.58, 0.15, 0.64, 0.08, 0.78, 0.12, 0.78, 0.17), TSColorRoleTeal, 1.5, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.78, 0.17, 0.85, 0.18, 0.84, 0.23, 0.76, 0.22), TSColorRoleTeal, 1.5, 0.003, rng);
}

static void TSDrawRobot(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.8);
    // Antenna
    TSAdd(strokes, TSLine(0.50, 0.17, 0.50, 0.08, 4), TSColorRoleInk, 2.0, @"offline");
    TSAdd(strokes, TSArc(0.50, 0.07, 0.022, 0.022, 0, M_PI * 2, 10), TSColorRoleVermilion, 2.0, @"offline");
    // Head
    TSAddJittered(strokes, TSClosed(@[TSV(0.34, 0.18), TSV(0.66, 0.18), TSV(0.66, 0.36), TSV(0.34, 0.36)]), TSColorRoleInk, inkW, 0.003, rng);
    TSAdd(strokes, TSArc(0.43, 0.27, 0.028, 0.028, 0, M_PI * 2, 14), TSColorRoleTeal, 2.0, @"offline");
    TSAdd(strokes, TSArc(0.57, 0.27, 0.028, 0.028, 0, M_PI * 2, 14), TSColorRoleTeal, 2.0, @"offline");
    TSAdd(strokes, TSLine(0.44, 0.325, 0.56, 0.325, 5), TSColorRoleInk, 1.8, @"offline");
    // Ears
    TSAdd(strokes, TSLine(0.34, 0.24, 0.29, 0.24, 3), TSColorRoleInk, 2.0, @"offline");
    TSAdd(strokes, TSLine(0.66, 0.24, 0.71, 0.24, 3), TSColorRoleInk, 2.0, @"offline");
    // Body
    TSAddJittered(strokes, TSClosed(@[TSV(0.33, 0.40), TSV(0.67, 0.40), TSV(0.67, 0.66), TSV(0.33, 0.66)]), TSColorRoleInk, inkW, 0.003, rng);
    // Buttons
    for (NSInteger i = 0; i < 3; i++) {
        TSAdd(strokes, TSArc(0.40 + i * 0.10, 0.52, 0.022, 0.022, 0, M_PI * 2, 10), i == 0 ? TSColorRoleVermilion : TSColorRoleOchre, 1.8, @"offline");
    }
    TSAdd(strokes, TSLine(0.39, 0.60, 0.61, 0.60, 6), TSColorRoleInk, 1.5, @"offline");
    // Arms
    TSAdd(strokes, TSLine(0.33, 0.45, 0.20, 0.55, 6), TSColorRoleInk, 2.4, @"offline");
    TSAdd(strokes, TSLine(0.20, 0.55, 0.17, 0.66, 4), TSColorRoleInk, 2.4, @"offline");
    TSAdd(strokes, TSLine(0.67, 0.45, 0.80, 0.55, 6), TSColorRoleInk, 2.4, @"offline");
    TSAdd(strokes, TSLine(0.80, 0.55, 0.83, 0.66, 4), TSColorRoleInk, 2.4, @"offline");
    TSAdd(strokes, TSArc(0.17, 0.675, 0.028, 0.028, 0, M_PI * 2, 10), TSColorRoleInk, 2.0, @"offline");
    TSAdd(strokes, TSArc(0.83, 0.675, 0.028, 0.028, 0, M_PI * 2, 10), TSColorRoleInk, 2.0, @"offline");
    // Legs
    TSAdd(strokes, TSLine(0.42, 0.66, 0.42, 0.83, 5), TSColorRoleInk, 2.5, @"offline");
    TSAdd(strokes, TSLine(0.58, 0.66, 0.58, 0.83, 5), TSColorRoleInk, 2.5, @"offline");
    TSAdd(strokes, TSLine(0.42, 0.83, 0.35, 0.85, 3), TSColorRoleInk, 2.0, @"offline");
    TSAdd(strokes, TSLine(0.58, 0.83, 0.65, 0.85, 3), TSColorRoleInk, 2.0, @"offline");
    // Ground and stars
    TSAddJittered(strokes, TSLine(0.14, 0.88, 0.86, 0.88, 18), TSColorRoleInk, 1.5, 0.002, rng);
    for (NSInteger i = 0; i < (detailed ? 5 : 3); i++) {
        double x = 0.16 + i * 0.18;
        double y = 0.14 + (i % 2) * 0.07;
        TSAdd(strokes, TSLine(x - 0.012, y, x + 0.012, y, 2), TSColorRoleOchre, 1.3, @"offline");
        TSAdd(strokes, TSLine(x, y - 0.012, x, y + 0.012, 2), TSColorRoleOchre, 1.3, @"offline");
    }
}

static void TSDrawFace(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.7);
    // Head
    TSAddJittered(strokes, TSArc(0.50, 0.38, 0.19, 0.25, 0, M_PI * 2, 36), TSColorRoleInk, inkW, 0.003, rng);
    // Neck and shoulders
    TSAddJittered(strokes, TSLine(0.43, 0.61, 0.42, 0.73, 6), TSColorRoleInk, 2.2, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.57, 0.61, 0.58, 0.73, 6), TSColorRoleInk, 2.2, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.18, 0.90, 0.24, 0.76, 0.38, 0.72, 0.42, 0.73), TSColorRoleInk, 2.4, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.82, 0.90, 0.76, 0.76, 0.62, 0.72, 0.58, 0.73), TSColorRoleInk, 2.4, 0.003, rng);
    // Hair
    for (NSInteger i = 0; i < (detailed ? 8 : 5); i++) {
        double t = (double)i / (double)((detailed ? 8 : 5) - 1);
        double x = 0.33 + t * 0.34;
        TSAddJittered(strokes, TSBezier(x, 0.22, x - 0.06, 0.08, x + 0.10, 0.10, x + 0.05, 0.24), TSColorRoleInk, 2.0, 0.003, rng);
    }
    // Brows
    TSAddJittered(strokes, TSBezier(0.36, 0.31, 0.40, 0.28, 0.44, 0.28, 0.46, 0.31), TSColorRoleInk, 1.8, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.54, 0.31, 0.56, 0.28, 0.60, 0.28, 0.64, 0.31), TSColorRoleInk, 1.8, 0.002, rng);
    // Eyes
    TSAddJittered(strokes, TSBezier(0.35, 0.38, 0.38, 0.355, 0.42, 0.355, 0.45, 0.38), TSColorRoleInk, 2.0, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.55, 0.38, 0.58, 0.355, 0.62, 0.355, 0.65, 0.38), TSColorRoleInk, 2.0, 0.002, rng);
    TSAdd(strokes, TSArc(0.40, 0.385, 0.012, 0.014, 0, M_PI * 2, 8), TSColorRoleInk, 1.8, @"offline");
    TSAdd(strokes, TSArc(0.60, 0.385, 0.012, 0.014, 0, M_PI * 2, 8), TSColorRoleInk, 1.8, @"offline");
    // Nose
    TSAddJittered(strokes, TSBezier(0.50, 0.39, 0.48, 0.45, 0.48, 0.48, 0.51, 0.49), TSColorRoleInk, 1.7, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.51, 0.49, 0.46, 0.50, 3), TSColorRoleInk, 1.5, 0.002, rng);
    // Lips
    TSAddJittered(strokes, TSBezier(0.43, 0.545, 0.46, 0.53, 0.54, 0.53, 0.57, 0.545), TSColorRoleVermilion, 2.0, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.43, 0.545, 0.47, 0.57, 0.53, 0.57, 0.57, 0.545), TSColorRoleVermilion, 2.0, 0.002, rng);
    // Ears
    TSAddJittered(strokes, TSArc(0.31, 0.42, 0.028, 0.055, M_PI_2, M_PI * 1.5, 12), TSColorRoleInk, 1.8, 0.002, rng);
    TSAddJittered(strokes, TSArc(0.69, 0.42, 0.028, 0.055, M_PI * 1.5, M_PI_2, 12), TSColorRoleInk, 1.8, 0.003, rng);
    // Hatching
    for (NSInteger i = 0; i < (detailed ? 6 : 3); i++) {
        double x = 0.64 + i * 0.016;
        TSAdd(strokes, TSLine(x, 0.44 + i * 0.015, x + 0.03, 0.50 + i * 0.015, 4), TSColorRoleInk, 1.1, @"offline");
    }
}

static void TSDrawDog(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 3.0);
    // Head
    TSAddJittered(strokes, TSArc(0.50, 0.36, 0.17, 0.15, 0, M_PI * 2, 30), TSColorRoleInk, inkW, 0.003, rng);
    // Ears
    TSAddJittered(strokes, TSBezier(0.35, 0.28, 0.27, 0.26, 0.24, 0.43, 0.33, 0.50), TSColorRoleInk, inkW, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.65, 0.28, 0.73, 0.26, 0.76, 0.43, 0.67, 0.50), TSColorRoleInk, inkW, 0.003, rng);
    // Eyes
    TSAdd(strokes, TSArc(0.44, 0.35, 0.022, 0.03, 0, M_PI * 2, 12), TSColorRoleInk, 2.0, @"offline");
    TSAdd(strokes, TSArc(0.56, 0.35, 0.022, 0.03, 0, M_PI * 2, 12), TSColorRoleInk, 2.0, @"offline");
    // Snout
    TSAddJittered(strokes, TSArc(0.50, 0.45, 0.085, 0.065, 0, M_PI * 2, 20), TSColorRoleInk, 2.0, 0.002, rng);
    TSAdd(strokes, TSArc(0.50, 0.425, 0.026, 0.020, 0, M_PI * 2, 12), TSColorRoleInk, 2.0, @"offline");
    TSAddJittered(strokes, TSLine(0.50, 0.445, 0.50, 0.48, 4), TSColorRoleInk, 1.6, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.50, 0.48, 0.47, 0.50, 0.45, 0.49, 0.44, 0.475), TSColorRoleInk, 1.6, 0.002, rng);
    TSAddJittered(strokes, TSBezier(0.50, 0.48, 0.53, 0.50, 0.55, 0.49, 0.56, 0.475), TSColorRoleInk, 1.6, 0.002, rng);
    // Tongue
    TSAddJittered(strokes, TSBezier(0.50, 0.50, 0.47, 0.54, 0.53, 0.54, 0.50, 0.52), TSColorRoleVermilion, 2.2, 0.002, rng);
    // Body
    NSArray *body = TSJoin(TSBezier(0.36, 0.49, 0.29, 0.58, 0.30, 0.78, 0.38, 0.84),
                           TSBezier(0.38, 0.84, 0.45, 0.87, 0.55, 0.87, 0.62, 0.84));
    body = TSJoin(body, TSBezier(0.62, 0.84, 0.70, 0.78, 0.71, 0.58, 0.64, 0.49));
    TSAddJittered(strokes, body, TSColorRoleInk, inkW, 0.003, rng);
    // Legs
    TSAddJittered(strokes, TSLine(0.41, 0.72, 0.40, 0.87, 4), TSColorRoleInk, 2.3, 0.002, rng);
    TSAddJittered(strokes, TSLine(0.59, 0.72, 0.60, 0.87, 4), TSColorRoleInk, 2.3, 0.002, rng);
    TSAddJittered(strokes, TSArc(0.40, 0.87, 0.035, 0.014, 0, M_PI, 8), TSColorRoleInk, 2.0, 0.002, rng);
    TSAddJittered(strokes, TSArc(0.60, 0.87, 0.035, 0.014, 0, M_PI, 8), TSColorRoleInk, 2.0, 0.002, rng);
    // Tail
    TSAddJittered(strokes, TSBezier(0.64, 0.78, 0.78, 0.78, 0.86, 0.68, 0.79, 0.60), TSColorRoleInk, 2.5, 0.003, rng);
    // Ground + hatching
    TSAddJittered(strokes, TSLine(0.10, 0.90, 0.90, 0.90, 20), TSColorRoleInk, 1.5, 0.002, rng);
    for (NSInteger i = 0; i < (detailed ? 5 : 3); i++) {
        double x = 0.58 + i * 0.022;
        TSAdd(strokes, TSLine(x, 0.65 + i * 0.012, x + 0.04, 0.70 + i * 0.012, 4), TSColorRoleInk, 1.1, @"offline");
    }
}

static void TSDrawAbstract(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    // Flowing ribbons
    for (NSInteger i = 0; i < 4; i++) {
        double y = 0.25 + i * 0.14;
        double phase = TSRandomRange(rng, 0.0, M_PI);
        NSMutableArray *points = [NSMutableArray array];
        for (NSInteger s = 0; s <= 42; s++) {
            double t = (double)s / 42.0;
            double x = 0.08 + t * 0.84;
            double yy = y + sin(t * M_PI * 2.0 + phase) * 0.06 + cos(t * M_PI * 4.0 + phase) * 0.018;
            [points addObject:TSV(x, yy)];
        }
        TSColorRole role = (i % 3 == 0) ? TSColorRoleVermilion : ((i % 3 == 1) ? TSColorRoleTeal : TSColorRoleOchre);
        TSAddJittered(strokes, points, role, TSLineWidth(rng, 2.3), 0.004, rng);
    }
    // Circles
    for (NSInteger i = 0; i < 3; i++) {
        double cx = TSRandomRange(rng, 0.22, 0.78);
        double cy = TSRandomRange(rng, 0.22, 0.78);
        double r = TSRandomRange(rng, 0.04, 0.12);
        TSAdd(strokes, TSArc(cx, cy, r, r, 0, M_PI * 2, 22), i == 0 ? TSColorRoleVermilion : TSColorRoleTeal, 2.0, @"offline");
    }
    // Stars
    NSInteger stars = detailed ? 10 : 6;
    for (NSInteger i = 0; i < stars; i++) {
        double x = TSRandomRange(rng, 0.10, 0.90);
        double y = TSRandomRange(rng, 0.10, 0.90);
        double size = TSRandomRange(rng, 0.012, 0.03);
        TSAdd(strokes, TSLine(x - size, y, x + size, y, 2), TSColorRoleOchre, 1.3, @"offline");
        TSAdd(strokes, TSLine(x, y - size, x, y + size, 2), TSColorRoleOchre, 1.3, @"offline");
    }
    // Hatching cluster
    for (NSInteger i = 0; i < (detailed ? 8 : 4); i++) {
        double x = 0.62 + i * 0.02;
        TSAdd(strokes, TSLine(x, 0.58 + i * 0.012, x + 0.05, 0.64 + i * 0.012, 4), TSColorRoleInk, 1.2, @"offline");
    }
}

static void TSDrawLandscape(NSMutableArray<TSStroke *> *strokes, TSRandom *rng, BOOL detailed) {
    double inkW = TSLineWidth(rng, 2.8);
    TSAdd(strokes, TSArc(0.22, 0.20, 0.07, 0.07, 0, M_PI * 2, 22), TSColorRoleOchre, 2.1, @"offline");
    for (NSInteger i = 0; i < 7; i++) {
        double angle = i * M_PI * 2 / 7;
        TSAdd(strokes, TSLine(0.22 + cos(angle) * 0.085, 0.20 + sin(angle) * 0.085,
                              0.22 + cos(angle) * 0.11, 0.20 + sin(angle) * 0.11, 3), TSColorRoleOchre, 1.3, @"offline");
    }
    TSAddJittered(strokes, TSBezier(0.05, 0.78, 0.30, 0.55, 0.55, 0.88, 0.95, 0.70), TSColorRoleTeal, inkW, 0.003, rng);
    TSAddJittered(strokes, TSBezier(0.05, 0.88, 0.27, 0.72, 0.48, 0.92, 0.95, 0.80), TSColorRoleTeal, 1.9, 0.003, rng);
    for (NSInteger i = 0; i < 3; i++) {
        double x = 0.22 + i * 0.24;
        double y = 0.54 + (i % 2) * 0.08;
        TSAddJittered(strokes, TSLine(x, y + 0.18, x, y, 5), TSColorRoleInk, 2.0, 0.002, rng);
        TSAddJittered(strokes, TSClosed(@[TSV(x - 0.05, y + 0.02), TSV(x, y - 0.10), TSV(x + 0.05, y + 0.02)]), TSColorRoleTeal, 2.0, 0.003, rng);
        TSAddJittered(strokes, TSClosed(@[TSV(x - 0.065, y + 0.08), TSV(x, y - 0.04), TSV(x + 0.065, y + 0.08)]), TSColorRoleTeal, 2.0, 0.003, rng);
    }
    for (NSInteger i = 0; i < 3; i++) {
        double x = 0.55 + i * 0.09;
        double y = 0.17 + (i % 2) * 0.05;
        TSAdd(strokes, TSLine(x - 0.02, y, x, y - 0.015, 3), TSColorRoleInk, 1.4, @"offline");
        TSAdd(strokes, TSLine(x, y - 0.015, x + 0.02, y, 3), TSColorRoleInk, 1.4, @"offline");
    }
    // Waves
    for (NSInteger i = 0; i < (detailed ? 5 : 3); i++) {
        double x = 0.10 + i * 0.19;
        TSAdd(strokes, TSBezier(x, 0.94, x + 0.05, 0.91, x + 0.09, 0.97, x + 0.14, 0.94), TSColorRoleBlue, 1.5, @"offline");
    }
    TSAddJittered(strokes, TSLine(0.08, 0.90, 0.92, 0.90, 18), TSColorRoleInk, 1.4, 0.002, rng);
}

#pragma mark - Engine

@implementation TSOfflineSketchEngine

+ (NSArray<NSString *> *)sceneNames {
    return @[@"cat", @"dog", @"house", @"tree", @"flower", @"mountain",
             @"rocket", @"car", @"fish", @"bird", @"robot", @"face", @"abstract"];
}

+ (TSDrawing *)drawingForPrompt:(NSString *)prompt theme:(TSTheme *)theme seed:(uint64_t)seed {
    NSString *cleanPrompt = [prompt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lower = cleanPrompt.lowercaseString ?: @"";
    TSRandom rng = { .state = seed ^ (uint64_t)lower.hash ^ 0x9E3779B97F4A7C15ULL };
    BOOL detailed = TSIsDetailed(lower);
    NSMutableArray<TSStroke *> *strokes = [NSMutableArray array];
    NSString *title = nil;

    if (TSContainsAny(lower, @[@"cat", @"chat", @"kitten", @"kitty", @"feline"])) {
        TSDrawCat(strokes, &rng, detailed);
        title = @"Curious Cat";
    } else if (TSContainsAny(lower, @[@"dog", @"chien", @"puppy", @"corgi", @"retriever"])) {
        TSDrawDog(strokes, &rng, detailed);
        title = @"Studio Dog";
    } else if (TSContainsAny(lower, @[@"house", @"home", @"maison", @"cabin", @"cottage", @"hut"])) {
        TSDrawHouse(strokes, &rng, detailed);
        title = @"Little House";
    } else if (TSContainsAny(lower, @[@"tree", @"arbre", @"forest", @"oak", @"birch"])) {
        TSDrawTree(strokes, &rng, detailed);
        title = @"Quiet Tree";
    } else if (TSContainsAny(lower, @[@"flower", @"fleur", @"rose", @"tulip", @"bloom", @"floral"])) {
        TSDrawFlower(strokes, &rng, detailed);
        title = @"Paper Flower";
    } else if (TSContainsAny(lower, @[@"mountain", @"montagne", @"peak", @"alps", @"summit", @"hill"])) {
        TSDrawMountain(strokes, &rng, detailed);
        title = @"Distant Peaks";
    } else if (TSContainsAny(lower, @[@"rocket", @"fusee", @"fusée", @"space", @"spaceship", @"astronaut", @"galaxy"])) {
        TSDrawRocket(strokes, &rng, detailed);
        title = @"Retro Rocket";
    } else if (TSContainsAny(lower, @[@"car", @"voiture", @"auto", @"automobile", @"truck", @"drive"])) {
        TSDrawCar(strokes, &rng, detailed);
        title = @"Sunday Drive";
    } else if (TSContainsAny(lower, @[@"fish", @"poisson", @"ocean", @"sea", @"aquarium", @"whale"])) {
        TSDrawFish(strokes, &rng, detailed);
        title = @"Little Fish";
    } else if (TSContainsAny(lower, @[@"bird", @"oiseau", @"sparrow", @"robin", @"wing"])) {
        TSDrawBird(strokes, &rng, detailed);
        title = @"Garden Bird";
    } else if (TSContainsAny(lower, @[@"robot", @"android", @"machine", @"bot", @"mecha"])) {
        TSDrawRobot(strokes, &rng, detailed);
        title = @"Friendly Robot";
    } else if (TSContainsAny(lower, @[@"face", @"portrait", @"visage", @"person", @"woman", @"man", @"head"])) {
        TSDrawFace(strokes, &rng, detailed);
        title = @"Pencil Portrait";
    } else if (TSContainsAny(lower, @[@"abstract", @"abstrait", @"pattern", @"lines", @"shapes", @"dream"])) {
        TSDrawAbstract(strokes, &rng, detailed);
        title = @"Abstract Study";
    } else {
        TSDrawLandscape(strokes, &rng, detailed);
        title = @"Imagined Landscape";
    }

    return [[TSDrawing alloc] initWithTitle:title
                                     aspect:4.0 / 3.0
                          themeIdentifier:theme.identifier
                                   strokes:strokes];
}

@end
