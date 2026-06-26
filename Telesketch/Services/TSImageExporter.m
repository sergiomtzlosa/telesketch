#import "TSImageExporter.h"
#import "TSStrokeRenderer.h"
#import "NSColor+TSHex.h"

static const CGFloat TSSVGExportWidth = 2000.0;
static const CGFloat TSPDFExportWidth = 1440.0;

NSString *TSExportFormatDisplayName(TSExportFormat format) {
    switch (format) {
        case TSExportFormatPNG: return @"PNG";
        case TSExportFormatSVG: return @"SVG";
        case TSExportFormatPDF: return @"PDF";
    }
    return @"PNG";
}

NSString *TSExportFormatFileExtension(TSExportFormat format) {
    switch (format) {
        case TSExportFormatPNG: return @"png";
        case TSExportFormatSVG: return @"svg";
        case TSExportFormatPDF: return @"pdf";
    }
    return @"png";
}

static NSError *TSExportError(NSString *message) {
    return [NSError errorWithDomain:TSSketchErrorDomain
                               code:TSSketchErrorTooLarge
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static NSError *TSExportMissingDrawingError(void) {
    return [NSError errorWithDomain:TSSketchErrorDomain
                               code:TSSketchErrorInvalidShape
                           userInfo:@{NSLocalizedDescriptionKey: @"There is no drawing to export."}];
}

static BOOL TSValidateDrawingAndURL(TSDrawing *drawing, NSURL *url, NSError **error) {
    if (!drawing || !url) {
        if (error) {
            *error = TSExportMissingDrawingError();
        }
        return NO;
    }
    return YES;
}

static NSString *TSSVGNumber(CGFloat value) {
    if (fabs(value - llround(value)) < 0.005) {
        return [NSString stringWithFormat:@"%ld", (long)llround(value)];
    }
    return [NSString stringWithFormat:@"%.2f", value];
}

static NSString *TSSVGEscapedString(NSString *string) {
    NSMutableString *escaped = [string mutableCopy];
    [escaped replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"'" withString:@"&apos;" options:0 range:NSMakeRange(0, escaped.length)];
    return escaped;
}

static NSString *TSSVGPathDataForVertices(NSArray<TSVertex *> *vertices, NSRect rect) {
    if (vertices.count == 0 || rect.size.width <= 0 || rect.size.height <= 0) {
        return @"";
    }
    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:vertices.count];
    for (TSVertex *vertex in vertices) {
        CGFloat x = rect.origin.x + vertex.x * rect.size.width;
        CGFloat y = rect.origin.y + (1.0 - vertex.y) * rect.size.height;
        [points addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
    }

    NSMutableString *data = [NSMutableString string];
    NSPoint first = points.firstObject.pointValue;
    [data appendFormat:@"M%@ %@", TSSVGNumber(first.x), TSSVGNumber(first.y)];
    if (points.count == 1) {
        [data appendFormat:@"L%@ %@", TSSVGNumber(first.x), TSSVGNumber(first.y)];
        return data;
    }
    if (points.count == 2) {
        NSPoint last = points.lastObject.pointValue;
        [data appendFormat:@"L%@ %@", TSSVGNumber(last.x), TSSVGNumber(last.y)];
        return data;
    }
    for (NSUInteger i = 0; i < points.count - 1; i++) {
        NSPoint p0 = points[i == 0 ? 0 : i - 1].pointValue;
        NSPoint p1 = points[i].pointValue;
        NSPoint p2 = points[i + 1].pointValue;
        NSPoint p3 = points[MIN(i + 2, points.count - 1)].pointValue;
        NSPoint cp1 = NSMakePoint(p1.x + (p2.x - p0.x) / 6.0, p1.y + (p2.y - p0.y) / 6.0);
        NSPoint cp2 = NSMakePoint(p2.x - (p3.x - p1.x) / 6.0, p2.y - (p3.y - p1.y) / 6.0);
        [data appendFormat:@"C%@ %@ %@ %@ %@ %@",
         TSSVGNumber(cp1.x), TSSVGNumber(cp1.y),
         TSSVGNumber(cp2.x), TSSVGNumber(cp2.y),
         TSSVGNumber(p2.x), TSSVGNumber(p2.y)];
    }
    return data;
}

@implementation TSImageExporter

+ (BOOL)writePNGForDrawing:(TSDrawing *)drawing
                     theme:(TSTheme *)theme
                     toURL:(NSURL *)url
                 pixelSize:(NSSize)pixelSize
                     error:(NSError **)error {
    if (!TSValidateDrawingAndURL(drawing, url, error)) {
        return NO;
    }
    NSInteger width = MAX(64, (NSInteger)llround(pixelSize.width));
    NSInteger height = MAX(48, (NSInteger)llround(pixelSize.height));
    if (drawing.aspect > 0.01) {
        height = (NSInteger)llround(width / drawing.aspect);
    }

    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                       pixelsWide:width
                                                                       pixelsHigh:height
                                                                    bitsPerSample:8
                                                                  samplesPerPixel:4
                                                                         hasAlpha:YES
                                                                         isPlanar:NO
                                                                   colorSpaceName:NSCalibratedRGBColorSpace
                                                                      bytesPerRow:0
                                                                     bitsPerPixel:0];
    if (!bitmap) {
        if (error) {
            *error = TSExportError(@"Could not create the export image.");
        }
        return NO;
    }
    bitmap.size = NSMakeSize(width, height);
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    if (!context) {
        if (error) {
            *error = TSExportError(@"Could not create the export graphics context.");
        }
        return NO;
    }

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [context setShouldAntialias:YES];
    NSRect rect = NSMakeRect(0, 0, width, height);
    [TSStrokeRenderer drawScreenBackgroundInRect:rect theme:theme];
    CGFloat margin = width * 0.035;
    [TSStrokeRenderer drawStrokes:drawing.strokes inRect:NSInsetRect(rect, margin, margin) theme:theme];
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (!png) {
        if (error) {
            *error = TSExportError(@"Could not encode the PNG.");
        }
        return NO;
    }
    return [png writeToURL:url options:NSDataWritingAtomic error:error];
}

+ (BOOL)writeSVGForDrawing:(TSDrawing *)drawing
                     theme:(TSTheme *)theme
                     toURL:(NSURL *)url
                     error:(NSError **)error {
    if (!TSValidateDrawingAndURL(drawing, url, error)) {
        return NO;
    }
    double aspect = drawing.aspect > 0.01 ? drawing.aspect : 4.0 / 3.0;
    CGFloat width = TSSVGExportWidth;
    CGFloat height = MAX(48.0, round(width / aspect));
    NSRect canvas = NSMakeRect(0, 0, width, height);
    CGFloat margin = width * 0.035;
    NSRect strokeRect = NSInsetRect(canvas, margin, margin);
    CGFloat strokeScale = MAX(0.55, MIN(3.0, strokeRect.size.width / 640.0));

    NSMutableString *svg = [NSMutableString string];
    [svg appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
    [svg appendFormat:@"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%@\" height=\"%@\" viewBox=\"0 0 %@ %@\">\n",
     TSSVGNumber(width), TSSVGNumber(height), TSSVGNumber(width), TSSVGNumber(height)];
    NSString *title = drawing.title.length > 0 ? drawing.title : @"Telesketch drawing";
    [svg appendFormat:@"<title>%@</title>\n", TSSVGEscapedString(title)];
    [svg appendString:@"<defs>\n"];
    [svg appendFormat:@"<linearGradient id=\"screen\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">"
                       @"<stop offset=\"0\" stop-color=\"%@\"/><stop offset=\"1\" stop-color=\"%@\"/>"
                       @"</linearGradient>\n",
     TSSVGEscapedString(theme.screenTopHex), TSSVGEscapedString(theme.screenBottomHex)];
    [svg appendFormat:@"<radialGradient id=\"vignette\" cx=\"0.5\" cy=\"0.52\" r=\"0.72\">"
                       @"<stop offset=\"0.55\" stop-color=\"#000000\" stop-opacity=\"0\"/>"
                       @"<stop offset=\"1\" stop-color=\"#000000\" stop-opacity=\"%@\"/>"
                       @"</radialGradient>\n",
     theme.darkScreen ? @"0.22" : @"0.10"];
    [svg appendString:@"</defs>\n"];
    [svg appendFormat:@"<rect width=\"%@\" height=\"%@\" fill=\"url(#screen)\"/>\n",
     TSSVGNumber(width), TSSVGNumber(height)];
    [svg appendFormat:@"<rect width=\"%@\" height=\"%@\" fill=\"url(#vignette)\"/>\n",
     TSSVGNumber(width), TSSVGNumber(height)];

    for (TSStroke *stroke in drawing.strokes) {
        NSString *pathData = TSSVGPathDataForVertices(stroke.vertices, strokeRect);
        if (pathData.length == 0) continue;
        NSColor *color = [TSStrokeRenderer colorForStroke:stroke theme:theme];
        NSString *hex = [color ts_hexString];
        CGFloat strokeWidth = MAX(0.9, stroke.width * strokeScale);
        CGFloat haloWidth = strokeWidth + 2.1 * strokeScale;
        [svg appendFormat:@"<path d=\"%@\" fill=\"none\" stroke=\"%@\" stroke-opacity=\"%@\" "
                           @"stroke-width=\"%@\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
         pathData, hex, theme.darkScreen ? @"0.16" : @"0.10", TSSVGNumber(haloWidth)];
        [svg appendFormat:@"<path d=\"%@\" fill=\"none\" stroke=\"%@\" "
                           @"stroke-width=\"%@\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n",
         pathData, hex, TSSVGNumber(strokeWidth)];
    }
    [svg appendString:@"</svg>\n"];

    NSData *data = [svg dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        if (error) {
            *error = TSExportError(@"Could not encode the SVG.");
        }
        return NO;
    }
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

+ (BOOL)writePDFForDrawing:(TSDrawing *)drawing
                     theme:(TSTheme *)theme
                     toURL:(NSURL *)url
                  pageSize:(NSSize)pageSize
                     error:(NSError **)error {
    if (!TSValidateDrawingAndURL(drawing, url, error)) {
        return NO;
    }
    CGFloat width = MAX(72.0, pageSize.width > 0 ? pageSize.width : TSPDFExportWidth);
    double aspect = drawing.aspect > 0.01 ? drawing.aspect : 4.0 / 3.0;
    CGFloat height = MAX(72.0, round(width / aspect));
    NSRect pageRect = NSMakeRect(0, 0, width, height);

    NSMutableData *data = [NSMutableData data];
    CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)data);
    if (!consumer) {
        if (error) {
            *error = TSExportError(@"Could not create the PDF data consumer.");
        }
        return NO;
    }
    CGRect mediaBox = CGRectMake(0, 0, width, height);
    CGContextRef pdfContext = CGPDFContextCreate(consumer, &mediaBox, NULL);
    CGDataConsumerRelease(consumer);
    if (!pdfContext) {
        if (error) {
            *error = TSExportError(@"Could not create the PDF context.");
        }
        return NO;
    }

    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithCGContext:pdfContext flipped:NO];
    if (!context) {
        CGContextRelease(pdfContext);
        if (error) {
            *error = TSExportError(@"Could not create the PDF graphics context.");
        }
        return NO;
    }

    CGPDFContextBeginPage(pdfContext, NULL);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [context setShouldAntialias:YES];
    [TSStrokeRenderer drawVectorBackgroundInRect:pageRect theme:theme];
    CGFloat margin = width * 0.035;
    [TSStrokeRenderer drawStrokes:drawing.strokes inRect:NSInsetRect(pageRect, margin, margin) theme:theme];
    [NSGraphicsContext restoreGraphicsState];
    CGPDFContextEndPage(pdfContext);

    CGPDFContextClose(pdfContext);
    CGContextRelease(pdfContext);

    if (data.length == 0) {
        if (error) {
            *error = TSExportError(@"The PDF export produced no data.");
        }
        return NO;
    }
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

@end
