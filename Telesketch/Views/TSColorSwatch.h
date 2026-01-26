#import <Cocoa/Cocoa.h>
#import "TSStroke.h"

NS_ASSUME_NONNULL_BEGIN

/// A round ink swatch. Selects a semantic colour role, or a literal colour.
@interface TSColorSwatch : NSButton

@property (nonatomic, assign) TSColorRole role;
@property (nonatomic, copy, nullable) NSString *colorHex;
@property (nonatomic, assign) CGFloat swatchDiameter;
@property (nonatomic, assign, getter=isChosen) BOOL chosen;

@end

NS_ASSUME_NONNULL_END
