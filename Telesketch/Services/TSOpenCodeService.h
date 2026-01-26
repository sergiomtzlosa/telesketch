#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const TSOpenCodeServiceStatusDidChangeNotification;
extern NSNotificationName const TSOpenCodeServiceModelsDidChangeNotification;
extern NSErrorDomain const TSOpenCodeErrorDomain;

typedef NS_ENUM(NSInteger, TSOpenCodeErrorCode) {
    TSOpenCodeErrorBinaryNotFound = 1,
    TSOpenCodeErrorStartFailed = 2,
    TSOpenCodeErrorAuthentication = 3,
    TSOpenCodeErrorRequestFailed = 4,
    TSOpenCodeErrorQuota = 5,
    TSOpenCodeErrorInvalidResponse = 6,
    TSOpenCodeErrorCancelled = 7
};

typedef NS_ENUM(NSInteger, TSOpenCodeStatus) {
    TSOpenCodeStatusStopped = 0,
    TSOpenCodeStatusStarting,
    TSOpenCodeStatusReady,
    TSOpenCodeStatusFailed
};

@interface TSOpenCodeModel : NSObject
@property (nonatomic, copy, readonly) NSString *providerID;
@property (nonatomic, copy, readonly) NSString *modelID;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *providerName;
@property (nonatomic, readonly) BOOL freeModel;
@property (nonatomic, readonly) BOOL localModel;
@property (nonatomic, copy, readonly) NSArray<NSString *> *variants;

- (NSString *)displayName;
- (NSString *)compactDisplayName;
- (NSString *)persistentIdentifier;
@end

/// Owns one private OpenCode server process. The URL and password are captured
/// from the server's stdout each time it starts.
@interface TSOpenCodeService : NSObject

@property (class, readonly) TSOpenCodeService *sharedService;

@property (nonatomic, readonly) TSOpenCodeStatus status;
@property (nonatomic, copy, readonly, nullable) NSString *serverURLString;
@property (nonatomic, copy, readonly, nullable) NSString *serverPassword;
@property (nonatomic, copy, readonly) NSString *serverUsername;
@property (nonatomic, copy, readonly, nullable) NSString *lastError;
@property (nonatomic, copy, readonly) NSArray<TSOpenCodeModel *> *models;
@property (nonatomic, strong, readonly, nullable) TSOpenCodeModel *preferredModel;
@property (nonatomic, copy, nullable) NSString *binaryPathOverride;

/// When set, Telesketch connects to this already-running server instead of
/// spawning its own helper. The password is optional for servers without auth.
@property (nonatomic, copy, nullable) NSString *externalServerURLString;
@property (nonatomic, copy, nullable) NSString *externalServerPassword;
@property (nonatomic, readonly) BOOL usesExternalServer;

- (void)startWithCompletion:(nullable void (^)(NSError * _Nullable error))completion;
- (void)stop;
/// Terminates the helper synchronously. Call only from the main thread during
/// application termination, when an asynchronous stop would never get to run.
- (void)shutdown;
- (void)restart;
- (void)refreshModelsWithCompletion:(nullable void (^)(NSError * _Nullable error))completion;
- (void)selectModel:(TSOpenCodeModel *)model;

- (void)generateTextForPrompt:(NSString *)prompt
                        model:(nullable TSOpenCodeModel *)model
                   completion:(void (^)(NSString * _Nullable text, NSError * _Nullable error))completion;
- (void)cancelCurrentGeneration;

/// Recognises both plain HTTP 429 responses and provider payloads that wrap a
/// 429 inside an HTTP 502 (`reason: rate_limit`, `status: 429`, or a
/// “free usage limit” message).
+ (BOOL)isRateLimitResponseStatus:(NSInteger)statusCode body:(nullable id)body;

- (NSString *)discoveredBinaryPath;
- (NSString *)connectionSummary;

@end

NS_ASSUME_NONNULL_END
