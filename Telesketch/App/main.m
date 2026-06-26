#import <Cocoa/Cocoa.h>
#import "TSAppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        TSAppDelegate *delegate = [[TSAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
