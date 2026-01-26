#import <Foundation/Foundation.h>
#import "TSStroke.h"

NS_ASSUME_NONNULL_BEGIN

/// Immutable drawing document model.
@interface TSDrawing : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, readonly) double aspect;
@property (nonatomic, copy, readonly) NSString *themeIdentifier;
@property (nonatomic, copy, readonly) NSArray<TSStroke *> *strokes;

+ (instancetype)emptyDrawingWithThemeIdentifier:(NSString *)themeIdentifier;

- (instancetype)initWithTitle:(NSString *)title
                        aspect:(double)aspect
             themeIdentifier:(NSString *)themeIdentifier
                      strokes:(NSArray<TSStroke *> *)strokes NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isEmpty;
- (NSUInteger)totalPointCount;

- (instancetype)drawingByAddingStroke:(TSStroke *)stroke;
- (instancetype)drawingByRemovingStroke:(TSStroke *)stroke;
- (instancetype)drawingByReplacingStrokes:(NSArray<TSStroke *> *)strokes;
- (instancetype)drawingWithTitle:(NSString *)title;
- (instancetype)drawingWithThemeIdentifier:(NSString *)themeIdentifier;

- (NSDictionary<NSString *, id> *)JSONObject;
- (nullable NSData *)JSONDataWithError:(NSError **)error;

+ (nullable instancetype)drawingWithJSONObject:(NSDictionary *)dictionary error:(NSError **)error;
+ (nullable instancetype)drawingWithJSONData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
