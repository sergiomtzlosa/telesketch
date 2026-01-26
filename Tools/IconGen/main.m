#import <Cocoa/Cocoa.h>
#import "TSIconRenderer.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSApp.activationPolicy = NSApplicationActivationPolicyProhibited;

        NSString *outputPath = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"Telesketch-1024.png";
        CGFloat size = argc > 2 ? (CGFloat)atof(argv[2]) : 1024.0;
        NSData *png = [TSIconRenderer PNGDataWithSize:size];
        if (!png) {
            fprintf(stderr, "Could not render the icon.\n");
            return 1;
        }
        NSError *error = nil;
        if (![png writeToFile:outputPath options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "Could not write %s: %s\n",
                    outputPath.UTF8String, error.localizedDescription.UTF8String);
            return 1;
        }
        printf("Wrote %s (%ld px)\n", outputPath.UTF8String, (long)lround(size));
    }
    return 0;
}
