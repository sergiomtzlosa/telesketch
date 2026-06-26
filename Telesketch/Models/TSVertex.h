#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A single point on a stroke. Coordinates are normalised to the drawing canvas (0...1).
@interface TSVertex : NSObject <NSCopying>

@property (nonatomic, readonly) double x;
@property (nonatomic, readonly) double y;
@property (nonatomic, readonly) double pressure;

+ (instancetype)vertexWithX:(double)x y:(double)y pressure:(double)pressure;
- (instancetype)initWithX:(double)x y:(double)y pressure:(double)pressure NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSArray<NSNumber *> *)JSONArray;
+ (nullable instancetype)vertexWithJSONArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
