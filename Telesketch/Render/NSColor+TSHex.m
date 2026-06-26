#import "NSColor+TSHex.h"

@implementation NSColor (TSHex)

+ (NSColor *)ts_colorWithHex:(NSString *)hex {
    return [self ts_colorWithHex:hex alpha:1.0];
}

+ (NSColor *)ts_colorWithHex:(NSString *)hex alpha:(CGFloat)alpha {
    if (![hex isKindOfClass:[NSString class]]) {
        return [NSColor colorWithCalibratedWhite:0.2 alpha:alpha];
    }
    NSString *clean = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([clean hasPrefix:@"#"]) {
        clean = [clean substringFromIndex:1];
    }
    if (clean.length == 3) {
        clean = [NSString stringWithFormat:@"%c%c%c%c%c%c",
                 [clean characterAtIndex:0], [clean characterAtIndex:0],
                 [clean characterAtIndex:1], [clean characterAtIndex:1],
                 [clean characterAtIndex:2], [clean characterAtIndex:2]];
    }
    if (clean.length != 6) {
        return [NSColor colorWithCalibratedWhite:0.2 alpha:alpha];
    }
    unsigned int rgba = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    if (![scanner scanHexInt:&rgba]) {
        return [NSColor colorWithCalibratedWhite:0.2 alpha:alpha];
    }
    CGFloat red = ((rgba >> 16) & 0xFF) / 255.0;
    CGFloat green = ((rgba >> 8) & 0xFF) / 255.0;
    CGFloat blue = (rgba & 0xFF) / 255.0;
    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
}

- (NSString *)ts_hexString {
    NSColor *rgb = [self colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] ?: self;
    if (!rgb) return @"#000000";
    CGFloat red = 0, green = 0, blue = 0, alpha = 1;
    [rgb getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (int)llround(red * 255.0), (int)llround(green * 255.0), (int)llround(blue * 255.0)];
}

@end
