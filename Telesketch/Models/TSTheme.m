#import "TSTheme.h"

@interface TSTheme ()
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *displayName;
@property (nonatomic, copy, readwrite) NSString *screenTopHex;
@property (nonatomic, copy, readwrite) NSString *screenBottomHex;
@property (nonatomic, copy, readwrite) NSString *inkHex;
@property (nonatomic, copy, readwrite) NSString *vermilionHex;
@property (nonatomic, copy, readwrite) NSString *tealHex;
@property (nonatomic, copy, readwrite) NSString *ochreHex;
@property (nonatomic, copy, readwrite) NSString *blueHex;
@property (nonatomic, copy, readwrite) NSString *bezelHex;
@property (nonatomic, readwrite) BOOL darkScreen;
- (instancetype)initPrivate;
@end

@implementation TSTheme

+ (NSArray<TSTheme *> *)allThemes {
    static NSArray<TSTheme *> *themes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        themes = @[[self themeWithIdentifier:@"classic"],
                   [self themeWithIdentifier:@"midnight"],
                   [self themeWithIdentifier:@"blueprint"]];
    });
    return themes;
}

+ (TSTheme *)defaultTheme {
    return [self themeWithIdentifier:@"classic"];
}

+ (instancetype)themeWithIdentifier:(NSString *)identifier {
    static NSMutableDictionary<NSString *, TSTheme *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMutableDictionary dictionary];

        TSTheme *classic = [[TSTheme alloc] initPrivate];
        classic.identifier = @"classic";
        classic.displayName = @"Classic";
        classic.screenTopHex = @"#E8E3D6";
        classic.screenBottomHex = @"#CFC9BA";
        classic.inkHex = @"#2B2E2C";
        classic.vermilionHex = @"#C75B45";
        classic.tealHex = @"#397C77";
        classic.ochreHex = @"#B8863B";
        classic.blueHex = @"#3E5C8A";
        classic.bezelHex = @"#1E1F1D";
        classic.darkScreen = NO;
        cache[classic.identifier] = classic;

        TSTheme *midnight = [[TSTheme alloc] initPrivate];
        midnight.identifier = @"midnight";
        midnight.displayName = @"Midnight";
        midnight.screenTopHex = @"#293330";
        midnight.screenBottomHex = @"#151B18";
        midnight.inkHex = @"#EFE9DA";
        midnight.vermilionHex = @"#D36552";
        midnight.tealHex = @"#5FA59D";
        midnight.ochreHex = @"#D2A353";
        midnight.blueHex = @"#7D9BC9";
        midnight.bezelHex = @"#0C100E";
        midnight.darkScreen = YES;
        cache[midnight.identifier] = midnight;

        TSTheme *blueprint = [[TSTheme alloc] initPrivate];
        blueprint.identifier = @"blueprint";
        blueprint.displayName = @"Blueprint";
        blueprint.screenTopHex = @"#1B2C48";
        blueprint.screenBottomHex = @"#0E192B";
        blueprint.inkHex = @"#E8F0FF";
        blueprint.vermilionHex = @"#E28A6A";
        blueprint.tealHex = @"#6FC3C0";
        blueprint.ochreHex = @"#E0C070";
        blueprint.blueHex = @"#9CC0FF";
        blueprint.bezelHex = @"#08111F";
        blueprint.darkScreen = YES;
        cache[blueprint.identifier] = blueprint;
    });

    TSTheme *theme = cache[identifier ?: @""];
    return theme ?: cache[@"classic"];
}

- (instancetype)initPrivate {
    self = [super init];
    return self;
}

- (NSString *)colorHexForRole:(TSColorRole)role {
    switch (role) {
        case TSColorRoleInk: return self.inkHex;
        case TSColorRoleVermilion: return self.vermilionHex;
        case TSColorRoleTeal: return self.tealHex;
        case TSColorRoleOchre: return self.ochreHex;
        case TSColorRoleBlue: return self.blueHex;
        case TSColorRoleCustom: return self.inkHex;
    }
    return self.inkHex;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)paletteDescription {
    return @[
        @{@"name": @"ink", @"hex": self.inkHex},
        @{@"name": @"vermilion", @"hex": self.vermilionHex},
        @{@"name": @"teal", @"hex": self.tealHex},
        @{@"name": @"ochre", @"hex": self.ochreHex},
        @{@"name": @"blue", @"hex": self.blueHex}
    ];
}

@end
