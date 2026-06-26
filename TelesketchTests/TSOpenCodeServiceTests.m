#import <XCTest/XCTest.h>
#import "TSOpenCodeService.h"

@interface TSOpenCodeServiceTests : XCTestCase
@property (nonatomic, strong) TSOpenCodeService *service;
@property (nonatomic, copy) NSString *savedURL;
@property (nonatomic, copy) NSString *savedPassword;
@end

@implementation TSOpenCodeServiceTests

- (void)setUp {
    [super setUp];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.savedURL = [defaults stringForKey:@"TSOpenCodeExternalServerURL"];
    self.savedPassword = [defaults stringForKey:@"TSOpenCodeExternalServerPassword"];
    self.service = [TSOpenCodeService sharedService];
}

- (void)tearDown {
    self.service.externalServerURLString = self.savedURL;
    self.service.externalServerPassword = self.savedPassword;
    [super tearDown];
}

- (void)testNormalizesAndPersistsExternalServerURL {
    self.service.externalServerURLString = @" 127.0.0.1:4096/ ";
    XCTAssertEqualObjects(self.service.externalServerURLString, @"http://127.0.0.1:4096");
    XCTAssertTrue(self.service.usesExternalServer);
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] stringForKey:@"TSOpenCodeExternalServerURL"],
                          @"http://127.0.0.1:4096");
}

- (void)testPersistsExternalServerPassword {
    self.service.externalServerPassword = @"s3cret-passphrase";
    XCTAssertEqualObjects(self.service.externalServerPassword, @"s3cret-passphrase");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] stringForKey:@"TSOpenCodeExternalServerPassword"],
                          @"s3cret-passphrase");
}

- (void)testClearingExternalServerDisablesExternalMode {
    self.service.externalServerURLString = @"http://127.0.0.1:4096";
    self.service.externalServerPassword = @"password";
    self.service.externalServerURLString = @"";
    self.service.externalServerPassword = @"";
    XCTAssertNil(self.service.externalServerURLString);
    XCTAssertFalse(self.service.usesExternalServer);
    XCTAssertEqualObjects(self.service.externalServerPassword, @"");
}

- (void)testDetectsWrappedProviderRateLimit {
    NSDictionary *body = @{
        @"_tag": @"ProviderRequestError",
        @"reason": @"rate_limit",
        @"message": @"Free usage limit reached.",
        @"status": @429
    };
    XCTAssertTrue([TSOpenCodeService isRateLimitResponseStatus:502 body:body]);
}

- (void)testDetectsPlainHTTPRateLimit {
    XCTAssertTrue([TSOpenCodeService isRateLimitResponseStatus:429 body:nil]);
}

- (void)testGenericServerErrorIsNotRateLimit {
    NSDictionary *body = @{@"message": @"Internal server error"};
    XCTAssertFalse([TSOpenCodeService isRateLimitResponseStatus:500 body:body]);
    XCTAssertFalse([TSOpenCodeService isRateLimitResponseStatus:200 body:body]);
}

@end
