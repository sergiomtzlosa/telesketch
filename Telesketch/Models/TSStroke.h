#import <Foundation/Foundation.h>
#import "TSVertex.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const TSDrawingDidChangeNotification;
extern NSErrorDomain const TSSketchErrorDomain;

typedef NS_ENUM(NSInteger, TSSketchErrorCode) {
    TSSketchErrorInvalidJSON = 1,
    TSSketchErrorInvalidShape = 2,
    TSSketchErrorEmptyDrawing = 3,
    TSSketchErrorTooLarge = 4,
    TSSketchErrorUnsupportedVersion = 5
};

/// Semantic ink roles let a drawing adapt gracefully when the screen theme changes.
typedef NS_ENUM(NSInteger, TSColorRole) {
    TSColorRoleInk = 0,
    TSColorRoleVermilion,
    TSColorRoleTeal,
    TSColorRoleOchre,
    TSColorRoleBlue,
    TSColorRoleCustom
};

FOUNDATION_EXPORT NSString *TSColorRoleToString(TSColorRole role);
FOUNDATION_EXPORT TSColorRole TSColorRoleFromString(NSString *string);

/// An immutable continuous polyline stroke.
@interface TSStroke : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<TSVertex *> *vertices;
@property (nonatomic, readonly) double width;
@property (nonatomic, readonly) TSColorRole role;
@property (nonatomic, copy, readonly) NSString *colorHex;
@property (nonatomic, copy, readonly) NSString *tool;

+ (instancetype)strokeWithVertices:(NSArray<TSVertex *> *)vertices
                             width:(double)width
                              role:(TSColorRole)role
                          colorHex:(nullable NSString *)colorHex
                              tool:(NSString *)tool;

- (instancetype)initWithVertices:(NSArray<TSVertex *> *)vertices
                           width:(double)width
                            role:(TSColorRole)role
                        colorHex:(nullable NSString *)colorHex
                            tool:(NSString *)tool NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSDictionary<NSString *, id> *)JSONObject;
+ (nullable instancetype)strokeWithJSONObject:(NSDictionary *)dictionary error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
