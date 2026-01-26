#import <Foundation/Foundation.h>
#import "TSStroke.h"

NS_ASSUME_NONNULL_BEGIN

/// Screen and chrome palette for the Telesketch device.
@interface TSTheme : NSObject

@property (class, readonly) NSArray<TSTheme *> *allThemes;
@property (class, readonly) TSTheme *defaultTheme;

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *screenTopHex;
@property (nonatomic, copy, readonly) NSString *screenBottomHex;
@property (nonatomic, copy, readonly) NSString *inkHex;
@property (nonatomic, copy, readonly) NSString *vermilionHex;
@property (nonatomic, copy, readonly) NSString *tealHex;
@property (nonatomic, copy, readonly) NSString *ochreHex;
@property (nonatomic, copy, readonly) NSString *blueHex;
@property (nonatomic, copy, readonly) NSString *bezelHex;
@property (nonatomic, readonly) BOOL darkScreen;

+ (instancetype)themeWithIdentifier:(NSString *)identifier;
- (NSString *)colorHexForRole:(TSColorRole)role;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)paletteDescription;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
