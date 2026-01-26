#import <Cocoa/Cocoa.h>
#import "TSDrawing.h"
#import "TSTheme.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TSExportFormat) {
    TSExportFormatPNG = 0,
    TSExportFormatSVG,
    TSExportFormatPDF
};

FOUNDATION_EXPORT NSString *TSExportFormatDisplayName(TSExportFormat format);
FOUNDATION_EXPORT NSString *TSExportFormatFileExtension(TSExportFormat format);

@interface TSImageExporter : NSObject

+ (BOOL)writePNGForDrawing:(TSDrawing * _Nullable)drawing
                     theme:(TSTheme *)theme
                     toURL:(NSURL *)url
                 pixelSize:(NSSize)pixelSize
                     error:(NSError * _Nullable * _Nullable)error;

/// Writes a resolution-independent SVG of the themed screen and its strokes.
+ (BOOL)writeSVGForDrawing:(TSDrawing * _Nullable)drawing
                     theme:(TSTheme *)theme
                     toURL:(NSURL *)url
                     error:(NSError * _Nullable * _Nullable)error;

/// Writes a vector PDF page. The page aspect follows the drawing.
+ (BOOL)writePDFForDrawing:(TSDrawing * _Nullable)drawing
                     theme:(TSTheme *)theme
                     toURL:(NSURL *)url
                  pageSize:(NSSize)pageSize
                     error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
