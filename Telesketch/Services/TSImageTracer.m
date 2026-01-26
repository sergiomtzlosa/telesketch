#import "TSImageTracer.h"
#import <Vision/Vision.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>

static const NSInteger TSImageTracerMaximumStrokes = 90;
static const NSInteger TSImageTracerMaximumPointsPerStroke = 220;

static NSError *TSTraceError(TSSketchErrorCode code, NSString *message) {
    return [NSError errorWithDomain:TSSketchErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

typedef struct {
    CGFloat x;
    CGFloat y;
    CGFloat width;
    CGFloat height;
} TSTraceBounds;

@implementation TSImageTracer

+ (nullable TSDrawing *)drawingFromImageAtURL:(NSURL *)url
                                        theme:(TSTheme *)theme
                                        title:(NSString *)title
                                        error:(NSError **)error {
    if (!url || !url.isFileURL) {
        if (error) {
            *error = TSTraceError(TSSketchErrorInvalidShape, @"Choose an image file to trace.");
        }
        return nil;
    }

    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) {
        if (error) {
            *error = TSTraceError(TSSketchErrorInvalidShape, @"That file could not be opened as an image.");
        }
        return nil;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!image) {
        if (error) {
            *error = TSTraceError(TSSketchErrorInvalidShape, @"That image format is not supported.");
        }
        return nil;
    }

    VNDetectContoursRequest *request = [[VNDetectContoursRequest alloc] init];
    request.detectsDarkOnLight = YES;
    request.contrastAdjustment = 1.8;
    request.maximumImageDimension = 1600;

    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:image options:@{}];
    NSError *visionError = nil;
    BOOL performed = [handler performRequests:@[request] error:&visionError];
    if (!performed || visionError) {
        CGImageRelease(image);
        if (error) {
            *error = TSTraceError(TSSketchErrorInvalidShape,
                                  [NSString stringWithFormat:@"Image analysis failed: %@",
                                   visionError.localizedDescription ?: @"unknown error"]);
        }
        return nil;
    }

    VNContoursObservation *observation = request.results.firstObject;
    if (!observation || observation.contourCount == 0) {
        CGImageRelease(image);
        if (error) {
            *error = TSTraceError(TSSketchErrorEmptyDrawing,
                                  @"No outlines were found. Try a higher-contrast image.");
        }
        return nil;
    }

    CGFloat imageAspect = (CGFloat)CGImageGetWidth(image) / MAX(1.0, (CGFloat)CGImageGetHeight(image));
    CGImageRelease(image);
    CGFloat targetAspect = 4.0 / 3.0;
    CGFloat boxWidth = 0.88;
    CGFloat boxHeight = 0.88;
    CGFloat fitWidth = boxWidth;
    CGFloat fitHeight = boxHeight;
    if (imageAspect > targetAspect) {
        fitHeight = boxWidth * targetAspect / imageAspect;
    } else {
        fitWidth = boxHeight * imageAspect / targetAspect;
    }
    CGFloat offsetX = (1.0 - fitWidth) * 0.5;
    CGFloat offsetY = (1.0 - fitHeight) * 0.5;

    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    for (NSInteger index = 0; index < observation.contourCount; index++) {
        NSError *contourError = nil;
        VNContour *contour = [observation contourAtIndex:index error:&contourError];
        if (!contour || contour.pointCount < 6) continue;

        NSInteger pointCount = contour.pointCount;
        simd_float2 const *points = contour.normalizedPoints;
        if (!points || pointCount <= 0) continue;

        CGFloat minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
        for (NSInteger i = 0; i < pointCount; i++) {
            CGFloat x = points[i].x;
            CGFloat y = 1.0 - points[i].y;
            minX = MIN(minX, x);
            maxX = MAX(maxX, x);
            minY = MIN(minY, y);
            maxY = MAX(maxY, y);
        }
        CGFloat spanX = maxX - minX;
        CGFloat spanY = maxY - minY;
        if (MAX(spanX, spanY) < 0.012) continue;

        NSMutableArray<TSVertex *> *vertices = [NSMutableArray array];
        CGFloat lastX = -10.0, lastY = -10.0;
        for (NSInteger i = 0; i < pointCount && vertices.count < TSImageTracerMaximumPointsPerStroke; i++) {
            CGFloat sourceX = points[i].x;
            CGFloat sourceY = 1.0 - points[i].y;
            if (vertices.count > 0) {
                CGFloat dx = sourceX - lastX;
                CGFloat dy = sourceY - lastY;
                if ((dx * dx + dy * dy) < 0.000012) continue;
            }
            CGFloat x = offsetX + sourceX * fitWidth;
            CGFloat y = offsetY + sourceY * fitHeight;
            x = MAX(0.0, MIN(1.0, x));
            y = MAX(0.0, MIN(1.0, y));
            [vertices addObject:[TSVertex vertexWithX:x y:y pressure:0.55]];
            lastX = sourceX;
            lastY = sourceY;
        }

        if (vertices.count >= 2) {
            CGFloat diagonal = sqrt(spanX * spanX + spanY * spanY);
            [candidates addObject:@{@"vertices": vertices, @"size": @(diagonal)}];
        }
    }

    if (candidates.count == 0) {
        if (error) {
            *error = TSTraceError(TSSketchErrorEmptyDrawing,
                                  @"No usable contours were found. Try a clearer, higher-contrast image.");
        }
        return nil;
    }

    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"size"] compare:a[@"size"]];
    }];
    if (candidates.count > TSImageTracerMaximumStrokes) {
        [candidates removeObjectsInRange:NSMakeRange(TSImageTracerMaximumStrokes,
                                                     candidates.count - TSImageTracerMaximumStrokes)];
    }

    NSMutableArray<TSStroke *> *strokes = [NSMutableArray arrayWithCapacity:candidates.count];
    for (NSDictionary *candidate in candidates) {
        TSStroke *stroke = [TSStroke strokeWithVertices:candidate[@"vertices"]
                                                  width:2.2
                                                   role:TSColorRoleInk
                                               colorHex:nil
                                                   tool:@"trace"];
        [strokes addObject:stroke];
    }

    NSString *drawingTitle = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (drawingTitle.length == 0) {
        drawingTitle = url.lastPathComponent.stringByDeletingPathExtension ?: @"Traced Image";
    }
    if (drawingTitle.length > 64) {
        drawingTitle = [drawingTitle substringToIndex:64];
    }
    return [[TSDrawing alloc] initWithTitle:drawingTitle
                                     aspect:4.0 / 3.0
                          themeIdentifier:theme.identifier
                                   strokes:strokes];
}

@end
