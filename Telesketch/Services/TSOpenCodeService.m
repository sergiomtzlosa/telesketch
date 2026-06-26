#import "TSOpenCodeService.h"
#import <signal.h>
#import <unistd.h>

NSNotificationName const TSOpenCodeServiceStatusDidChangeNotification = @"TSOpenCodeServiceStatusDidChangeNotification";
NSNotificationName const TSOpenCodeServiceModelsDidChangeNotification = @"TSOpenCodeServiceModelsDidChangeNotification";
NSErrorDomain const TSOpenCodeErrorDomain = @"com.sid.telesketch.opencode";

static NSString *const TSPreferredModelKey = @"TSOpenCodePreferredModel";
static NSString *const TSBinaryPathKey = @"TSOpenCodeBinaryPath";
static NSString *const TSExternalURLKey = @"TSOpenCodeExternalServerURL";
static NSString *const TSExternalPasswordKey = @"TSOpenCodeExternalServerPassword";

static NSString *TSNormalizedServerURLString(NSString *value) {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return @"";
    if ([trimmed rangeOfString:@"://"].location == NSNotFound) {
        trimmed = [@"http://" stringByAppendingString:trimmed];
    }
    while ([trimmed hasSuffix:@"/"]) {
        trimmed = [trimmed substringToIndex:trimmed.length - 1];
    }
    return trimmed;
}

@interface TSOpenCodeModel ()
@property (nonatomic, copy, readwrite) NSString *providerID;
@property (nonatomic, copy, readwrite) NSString *modelID;
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, copy, readwrite) NSString *providerName;
@property (nonatomic, readwrite) BOOL freeModel;
@property (nonatomic, readwrite) BOOL localModel;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *variants;
@end

@implementation TSOpenCodeModel

- (NSString *)displayName {
    if (self.providerName.length > 0 && self.name.length > 0) {
        return [NSString stringWithFormat:@"%@ · %@", self.providerName, self.name];
    }
    return self.name.length > 0 ? self.name : self.identifier;
}

- (NSString *)compactDisplayName {
    NSMutableString *name = [NSMutableString stringWithString:self.displayName];
    if (self.localModel) {
        [name appendString:@"  ·  Local"];
    } else if (self.freeModel) {
        [name appendString:@"  ·  Free"];
    }
    return name;
}

- (NSString *)persistentIdentifier {
    return [NSString stringWithFormat:@"%@/%@", self.providerID, self.identifier];
}

@end

@interface TSOpenCodeService ()
@property (nonatomic, readwrite) TSOpenCodeStatus status;
@property (nonatomic, copy, readwrite, nullable) NSString *serverURLString;
@property (nonatomic, copy, readwrite, nullable) NSString *serverPassword;
@property (nonatomic, copy, readwrite) NSString *serverUsername;
@property (nonatomic, copy, readwrite, nullable) NSString *lastError;
@property (nonatomic, copy, readwrite) NSArray<TSOpenCodeModel *> *models;
@property (nonatomic, strong, readwrite, nullable) TSOpenCodeModel *preferredModel;
@property (nonatomic, strong) NSTask *serverTask;
@property (nonatomic, strong) NSPipe *stdoutPipe;
@property (nonatomic, strong) NSPipe *stderrPipe;
@property (nonatomic, strong) NSURLSession *URLSession;
@property (nonatomic, strong) NSMutableArray<void (^)(NSError * _Nullable)> *startCompletions;
@property (nonatomic, strong) NSMutableArray<void (^)(NSError * _Nullable)> *modelCompletions;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *currentGenerationTask;
@property (nonatomic, assign) BOOL stopping;
@property (nonatomic, assign) BOOL probing;
@property (nonatomic, assign) NSInteger probeAttempts;
@property (nonatomic, strong) NSMutableString *lineBuffer;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, copy) NSString *logPath;
- (instancetype)initPrivate;
@end

@implementation TSOpenCodeService

+ (TSOpenCodeService *)sharedService {
    static TSOpenCodeService *service;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[TSOpenCodeService alloc] initPrivate];
    });
    return service;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _status = TSOpenCodeStatusStopped;
        _serverUsername = @"opencode";
        _models = @[];
        _startCompletions = [NSMutableArray array];
        _modelCompletions = [NSMutableArray array];
        _lineBuffer = [NSMutableString string];
        _ioQueue = dispatch_queue_create("com.sid.telesketch.opencode.io", DISPATCH_QUEUE_SERIAL);
        _logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/Telesketch/opencode.log"];
        [self ensureLogDirectory];

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 190.0;
        config.timeoutIntervalForResource = 300.0;
        config.HTTPMaximumConnectionsPerHost = 4;
        _URLSession = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (void)ensureLogDirectory {
    NSString *directory = [self.logPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

- (void)appendLogLine:(NSString *)line {
    if (line.length == 0) return;
    NSString *safe = line;
    if ([line hasPrefix:@"server password "]) {
        safe = @"server password •••••••• (captured in memory)";
    }
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], safe];
    NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_async(self.ioQueue, ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.logPath]) {
            [[NSFileManager defaultManager] createFileAtPath:self.logPath contents:nil attributes:nil];
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:self.logPath];
        if (handle) {
            @try {
                [handle seekToEndOfFile];
                [handle writeData:data];
                [handle closeFile];
            } @catch (NSException *exception) {
                (void)exception;
            }
        }
    });
}

- (NSString *)binaryPathOverride {
    return [[NSUserDefaults standardUserDefaults] stringForKey:TSBinaryPathKey];
}

- (void)setBinaryPathOverride:(NSString *)binaryPathOverride {
    if (binaryPathOverride.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:binaryPathOverride forKey:TSBinaryPathKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TSBinaryPathKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)externalServerURLString {
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:TSExternalURLKey];
    NSString *normalized = TSNormalizedServerURLString(stored);
    return normalized.length > 0 ? normalized : nil;
}

- (void)setExternalServerURLString:(NSString *)externalServerURLString {
    NSString *normalized = TSNormalizedServerURLString(externalServerURLString);
    if (normalized.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:normalized forKey:TSExternalURLKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TSExternalURLKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)externalServerPassword {
    return [[NSUserDefaults standardUserDefaults] stringForKey:TSExternalPasswordKey] ?: @"";
}

- (void)setExternalServerPassword:(NSString *)externalServerPassword {
    if (externalServerPassword.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:externalServerPassword forKey:TSExternalPasswordKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TSExternalPasswordKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)usesExternalServer {
    return self.externalServerURLString.length > 0;
}

- (NSString *)discoveredBinaryPath {
    NSString *override = self.binaryPathOverride;
    if (override.length > 0 && [[NSFileManager defaultManager] isExecutableFileAtPath:override]) {
        return override;
    }
    NSString *home = NSHomeDirectory();
    NSArray<NSString *> *candidates = @[
        [home stringByAppendingPathComponent:@".opencode/bin/opencode"],
        @"/opt/homebrew/bin/opencode",
        @"/usr/local/bin/opencode",
        @"/usr/bin/opencode"
    ];
    for (NSString *path in candidates) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            return path;
        }
    }

    // Last resort: ask the login shell. This keeps GUI-launched apps working
    // when OpenCode lives somewhere unusual.
    NSTask *which = [NSTask new];
    which.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    which.arguments = @[@"-lc", @"command -v opencode"];
    NSPipe *pipe = [NSPipe pipe];
    which.standardOutput = pipe;
    which.standardError = [NSPipe pipe];
    NSError *error = nil;
    if ([which launchAndReturnError:&error]) {
        [which waitUntilExit];
        NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
        NSString *path = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (path.length > 0 && [[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            return path;
        }
    }
    return @"";
}

- (void)startWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) {
            [self.startCompletions addObject:[completion copy]];
        }
        if (self.status == TSOpenCodeStatusReady) {
            [self flushStartCompletionsWithError:nil];
            return;
        }
        if (self.status == TSOpenCodeStatusStarting) {
            return;
        }
        [self launchServer];
    });
}

- (void)launchServer {
    if (self.status == TSOpenCodeStatusStarting) return;
    [self stopServerProcess];
    self.stopping = NO;
    self.lastError = nil;
    self.serverURLString = nil;
    self.serverPassword = nil;
    self.probing = NO;
    self.probeAttempts = 0;
    [self.lineBuffer setString:@""];
    self.status = TSOpenCodeStatusStarting;
    [self notifyStatus];

    if (self.usesExternalServer) {
        self.serverURLString = self.externalServerURLString;
        self.serverPassword = self.externalServerPassword;
        [self appendLogLine:[NSString stringWithFormat:@"Connecting to external OpenCode server at %@ (username %@, password %@)",
                             self.serverURLString,
                             self.serverUsername,
                             self.serverPassword.length > 0 ? @"configured" : @"not set"]];
        [self maybeProbe];
        return;
    }

    NSString *binary = [self discoveredBinaryPath];
    if (binary.length == 0) {
        [self failWithCode:TSOpenCodeErrorBinaryNotFound
                   message:@"OpenCode was not found. Install it from opencode.ai, then try again."];
        return;
    }

    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:binary];
    task.arguments = @[@"serve", @"--hostname", @"127.0.0.1", @"--port", @"0"];
    task.currentDirectoryURL = [NSURL fileURLWithPath:NSHomeDirectory()];
    NSMutableDictionary<NSString *, NSString *> *environment = [[NSProcessInfo processInfo].environment mutableCopy];
    environment[@"HOME"] = NSHomeDirectory();
    environment[@"PATH"] = [NSString stringWithFormat:@"%@/.opencode/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", NSHomeDirectory()];
    task.environment = environment;

    NSPipe *stdoutPipe = [NSPipe pipe];
    NSPipe *stderrPipe = [NSPipe pipe];
    task.standardOutput = stdoutPipe;
    task.standardError = stderrPipe;
    task.standardInput = [NSFileHandle fileHandleWithNullDevice];

    __weak typeof(self) weakSelf = self;
    task.terminationHandler = ^(NSTask *finishedTask) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf serverDidTerminateWithStatus:finishedTask.terminationStatus];
        });
    };

    self.stdoutPipe = stdoutPipe;
    self.stderrPipe = stderrPipe;
    self.serverTask = task;

    [stdoutPipe.fileHandleForReading setReadabilityHandler:^(NSFileHandle *handle) {
        NSData *data = [handle availableData];
        if (data.length == 0) return;
        dispatch_async(weakSelf.ioQueue, ^{
            [weakSelf consumeData:data isErrorOutput:NO];
        });
    }];
    [stderrPipe.fileHandleForReading setReadabilityHandler:^(NSFileHandle *handle) {
        NSData *data = [handle availableData];
        if (data.length == 0) return;
        dispatch_async(weakSelf.ioQueue, ^{
            [weakSelf consumeData:data isErrorOutput:YES];
        });
    }];

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        self.serverTask = nil;
        [self failWithCode:TSOpenCodeErrorStartFailed
                   message:[NSString stringWithFormat:@"Could not start OpenCode: %@", launchError.localizedDescription ?: @"unknown error"]];
        return;
    }

    [self appendLogLine:[NSString stringWithFormat:@"Launched %@ serve --hostname 127.0.0.1 --port 0 (pid %d)",
                         binary, task.processIdentifier]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(24.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.status == TSOpenCodeStatusStarting && weakSelf.serverTask == task) {
            [weakSelf failWithCode:TSOpenCodeErrorStartFailed
                           message:@"OpenCode did not become ready in time. Check the log or try again."];
        }
    });
}

- (void)consumeData:(NSData *)data isErrorOutput:(BOOL)isErrorOutput {
    if (data.length == 0) return;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) return;
    [self.lineBuffer appendString:text];
    if (self.lineBuffer.length > 1024 * 1024) {
        [self.lineBuffer deleteCharactersInRange:NSMakeRange(0, self.lineBuffer.length - 512 * 1024)];
    }
    while (YES) {
        NSRange newline = [self.lineBuffer rangeOfString:@"\n"];
        if (newline.location == NSNotFound) break;
        NSString *line = [self.lineBuffer substringToIndex:newline.location];
        [self.lineBuffer deleteCharactersInRange:NSMakeRange(0, newline.location + newline.length)];
        line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length == 0) continue;
        [self appendLogLine:line];
        if (!isErrorOutput) {
            [self parseServerLine:line];
        }
    }
}

- (void)parseServerLine:(NSString *)line {
    __weak typeof(self) weakSelf = self;
    if ([line hasPrefix:@"server listening on "]) {
        NSString *url = [[line substringFromIndex:@"server listening on ".length]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.serverURLString = url;
            [weakSelf maybeProbe];
        });
    } else if ([line hasPrefix:@"server password "]) {
        NSString *password = [[line substringFromIndex:@"server password ".length]
                              stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.serverPassword = password;
            [weakSelf maybeProbe];
        });
    }
}

- (void)maybeProbe {
    if (self.status != TSOpenCodeStatusStarting) return;
    if (self.serverURLString.length == 0) return;
    if (!self.usesExternalServer && self.serverPassword.length == 0) return;
    if (self.probing) return;
    self.probing = YES;
    self.probeAttempts = 0;
    [self probeServer];
}

- (void)probeServer {
    if (self.status != TSOpenCodeStatusStarting) return;
    if (self.serverURLString.length == 0 || (!self.usesExternalServer && self.serverPassword.length == 0)) {
        [self failWithCode:TSOpenCodeErrorStartFailed
                   message:self.usesExternalServer
                           ? @"The external OpenCode server URL is missing."
                           : @"OpenCode started without publishing its URL or password."];
        return;
    }
    NSURL *url = [NSURL URLWithString:[self.serverURLString stringByAppendingString:@"/api/info"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 4.0;
    [request setValue:[self authorizationHeader] forHTTPHeaderField:@"Authorization"];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.URLSession dataTaskWithRequest:request
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TSOpenCodeService *strongSelf = weakSelf;
            if (!strongSelf) return;
            NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            if (statusCode == 200 && data.length > 0) {
                strongSelf.probing = NO;
                strongSelf.status = TSOpenCodeStatusReady;
                strongSelf.lastError = nil;
                [strongSelf appendLogLine:[NSString stringWithFormat:@"Server ready at %@", strongSelf.serverURLString]];
                [strongSelf notifyStatus];
                [strongSelf loadModelsWithCompletion:^(NSError *modelsError) {
                    [strongSelf flushStartCompletionsWithError:nil];
                    (void)modelsError;
                }];
                return;
            }
            if (statusCode == 401 || statusCode == 403) {
                strongSelf.probing = NO;
                NSString *message = strongSelf.usesExternalServer
                    ? @"The external OpenCode server rejected that password. Check the server password in Settings."
                    : @"OpenCode rejected the password captured from its helper process.";
                [strongSelf failWithCode:TSOpenCodeErrorAuthentication message:message];
                return;
            }
            strongSelf.probeAttempts++;
            if (strongSelf.probeAttempts >= 60) {
                strongSelf.probing = NO;
                [strongSelf failWithCode:TSOpenCodeErrorStartFailed
                                 message:@"OpenCode is running but its API did not become available."];
                return;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf probeServer];
            });
        });
    }];
    [task resume];
}

- (void)serverDidTerminateWithStatus:(int)terminationStatus {
    if (self.stopping) {
        return;
    }
    if (self.status == TSOpenCodeStatusStopped) {
        return;
    }
    [self failWithCode:TSOpenCodeErrorStartFailed
               message:[NSString stringWithFormat:@"OpenCode stopped unexpectedly (exit %d).", terminationStatus]];
}

- (void)failWithCode:(TSOpenCodeErrorCode)code message:(NSString *)message {
    if (self.stopping) return;
    self.status = TSOpenCodeStatusFailed;
    self.lastError = message;
    self.probing = NO;
    self.serverURLString = nil;
    self.serverPassword = nil;
    [self appendLogLine:[NSString stringWithFormat:@"FAILED: %@", message]];
    [self notifyStatus];

    NSError *error = [NSError errorWithDomain:TSOpenCodeErrorDomain
                                         code:code
                                     userInfo:@{NSLocalizedDescriptionKey: message ?: @"OpenCode failed."}];
    [self flushStartCompletionsWithError:error];

    [self stopServerProcess];
}

- (void)stopServerProcess {
    self.stopping = YES;
    if (self.serverTask && self.serverTask.isRunning) {
        [self.serverTask terminate];
        NSTask *task = self.serverTask;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (task.isRunning) {
                kill(task.processIdentifier, SIGKILL);
            }
        });
    }
    [self.stdoutPipe.fileHandleForReading setReadabilityHandler:nil];
    [self.stderrPipe.fileHandleForReading setReadabilityHandler:nil];
    self.serverTask = nil;
    self.stdoutPipe = nil;
    self.stderrPipe = nil;
}

- (void)stop {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cancelCurrentGeneration];
        [self stopServerProcess];
        self.status = TSOpenCodeStatusStopped;
        self.lastError = nil;
        self.serverURLString = nil;
        self.serverPassword = nil;
        self.models = @[];
        [self notifyStatus];
        [self notifyModels];
        [self flushStartCompletionsWithError:[NSError errorWithDomain:TSOpenCodeErrorDomain
                                                                 code:TSOpenCodeErrorCancelled
                                                             userInfo:@{NSLocalizedDescriptionKey: @"OpenCode was stopped."}]];
    });
}

- (void)shutdown {
    self.stopping = YES;
    [self cancelCurrentGeneration];

    NSTask *task = self.serverTask;
    if (task && task.isRunning) {
        [task terminate];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.5];
        while (task.isRunning && deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (task.isRunning) {
            kill(task.processIdentifier, SIGKILL);
            [task waitUntilExit];
        }
    }

    [self.stdoutPipe.fileHandleForReading setReadabilityHandler:nil];
    [self.stderrPipe.fileHandleForReading setReadabilityHandler:nil];
    self.serverTask = nil;
    self.stdoutPipe = nil;
    self.stderrPipe = nil;
    self.status = TSOpenCodeStatusStopped;
    self.lastError = nil;
    self.serverURLString = nil;
    self.serverPassword = nil;
    self.models = @[];
}

- (void)restart {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopServerProcess];
        self.status = TSOpenCodeStatusStopped;
        [self notifyStatus];
        [self launchServer];
    });
}

- (void)flushStartCompletionsWithError:(NSError *)error {
    NSArray *completions = [self.startCompletions copy];
    [self.startCompletions removeAllObjects];
    for (void (^completion)(NSError *) in completions) {
        completion(error);
    }
}

- (void)flushModelCompletionsWithError:(NSError *)error {
    NSArray *completions = [self.modelCompletions copy];
    [self.modelCompletions removeAllObjects];
    for (void (^completion)(NSError *) in completions) {
        completion(error);
    }
}

- (void)notifyStatus {
    [[NSNotificationCenter defaultCenter] postNotificationName:TSOpenCodeServiceStatusDidChangeNotification object:self];
}

- (void)notifyModels {
    [[NSNotificationCenter defaultCenter] postNotificationName:TSOpenCodeServiceModelsDidChangeNotification object:self];
}

- (NSString *)authorizationHeader {
    if (self.serverPassword.length == 0) return @"";
    NSString *credentials = [NSString stringWithFormat:@"%@:%@", self.serverUsername, self.serverPassword];
    NSData *data = [credentials dataUsingEncoding:NSUTF8StringEncoding];
    return [@"Basic " stringByAppendingString:[data base64EncodedStringWithOptions:0]];
}

- (void)loadModelsWithCompletion:(void (^)(NSError * _Nullable))completion {
    if (self.status != TSOpenCodeStatusReady) {
        if (completion) {
            completion([NSError errorWithDomain:TSOpenCodeErrorDomain
                                           code:TSOpenCodeErrorStartFailed
                                       userInfo:@{NSLocalizedDescriptionKey: @"OpenCode is not ready."}]);
        }
        return;
    }
    if (completion) {
        [self.modelCompletions addObject:[completion copy]];
    }
    __weak typeof(self) weakSelf = self;
    [self requestJSONWithMethod:@"GET" path:@"/api/model" body:nil timeout:20.0 completion:^(id  _Nullable object, NSError * _Nullable error) {
        TSOpenCodeService *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            [strongSelf flushModelCompletionsWithError:error];
            return;
        }
        NSArray *dataArray = nil;
        if ([object isKindOfClass:[NSDictionary class]]) {
            dataArray = object[@"data"];
        } else if ([object isKindOfClass:[NSArray class]]) {
            dataArray = object;
        }
        if (![dataArray isKindOfClass:[NSArray class]]) {
            NSError *parseError = [NSError errorWithDomain:TSOpenCodeErrorDomain
                                                      code:TSOpenCodeErrorInvalidResponse
                                                  userInfo:@{NSLocalizedDescriptionKey: @"OpenCode returned an unexpected model list."}];
            [strongSelf flushModelCompletionsWithError:parseError];
            return;
        }
        NSMutableArray<TSOpenCodeModel *> *models = [NSMutableArray array];
        for (NSDictionary *entry in dataArray) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            TSOpenCodeModel *model = [strongSelf modelFromDictionary:entry];
            if (model) {
                [models addObject:model];
            }
        }
        [models sortUsingComparator:^NSComparisonResult(TSOpenCodeModel *a, TSOpenCodeModel *b) {
            if (a.localModel != b.localModel) {
                return a.localModel ? NSOrderedAscending : NSOrderedDescending;
            }
            NSComparisonResult provider = [a.providerName compare:b.providerName];
            if (provider != NSOrderedSame) return provider;
            return [a.name compare:b.name];
        }];
        strongSelf.models = models;
        [strongSelf restorePreferredModelIfNeeded];
        [strongSelf notifyModels];
        [strongSelf flushModelCompletionsWithError:nil];
    }];
}

- (nullable TSOpenCodeModel *)modelFromDictionary:(NSDictionary *)entry {
    NSString *identifier = [entry[@"id"] isKindOfClass:[NSString class]] ? entry[@"id"] : nil;
    NSString *providerID = [entry[@"providerID"] isKindOfClass:[NSString class]] ? entry[@"providerID"] : nil;
    if (identifier.length == 0 || providerID.length == 0) {
        return nil;
    }
    NSString *type = [entry[@"type"] isKindOfClass:[NSString class]] ? entry[@"type"] : @"chat";
    if (![type isEqualToString:@"chat"]) {
        return nil;
    }
    NSNumber *enabled = [entry[@"enabled"] isKindOfClass:[NSNumber class]] ? entry[@"enabled"] : nil;
    if (enabled && !enabled.boolValue) {
        return nil;
    }
    NSString *status = [entry[@"status"] isKindOfClass:[NSString class]] ? entry[@"status"] : nil;
    if (status && ![status isEqualToString:@"active"]) {
        return nil;
    }

    TSOpenCodeModel *model = [TSOpenCodeModel new];
    model.identifier = identifier;
    model.modelID = [entry[@"modelID"] isKindOfClass:[NSString class]] ? entry[@"modelID"] : identifier;
    model.providerID = providerID;
    model.name = [entry[@"name"] isKindOfClass:[NSString class]] ? entry[@"name"] : identifier;
    model.providerName = [self providerDisplayNameForID:providerID];

    BOOL freeModel = NO;
    NSArray *costs = [entry[@"cost"] isKindOfClass:[NSArray class]] ? entry[@"cost"] : @[];
    if (costs.count > 0) {
        freeModel = YES;
        for (NSDictionary *cost in costs) {
            if (![cost isKindOfClass:[NSDictionary class]]) { freeModel = NO; break; }
            double input = [cost[@"input"] doubleValue];
            double output = [cost[@"output"] doubleValue];
            if (input > 0.000001 || output > 0.000001) {
                freeModel = NO;
                break;
            }
        }
    }
    model.freeModel = freeModel;
    NSString *baseURL = nil;
    if ([entry[@"settings"] isKindOfClass:[NSDictionary class]]) {
        baseURL = [entry[@"settings"][@"baseURL"] isKindOfClass:[NSString class]] ? entry[@"settings"][@"baseURL"] : nil;
    }
    model.localModel = [providerID isEqualToString:@"ollama"] ||
                       [providerID isEqualToString:@"llamacpp"] ||
                       [providerID containsString:@"local"] ||
                       [baseURL containsString:@"127.0.0.1"] ||
                       [baseURL containsString:@"localhost"];

    NSMutableArray<NSString *> *variants = [NSMutableArray array];
    NSArray *rawVariants = [entry[@"variants"] isKindOfClass:[NSArray class]] ? entry[@"variants"] : @[];
    for (NSDictionary *variant in rawVariants) {
        if ([variant isKindOfClass:[NSDictionary class]] && [variant[@"id"] isKindOfClass:[NSString class]]) {
            [variants addObject:variant[@"id"]];
        }
    }
    model.variants = variants;
    return model;
}

- (NSString *)providerDisplayNameForID:(NSString *)providerID {
    NSDictionary *names = @{
        @"opencode": @"OpenCode",
        @"anthropic": @"Anthropic",
        @"openai": @"OpenAI",
        @"google": @"Google",
        @"ollama": @"Ollama (Local)",
        @"llamacpp": @"llama.cpp (Local)",
        @"groq": @"Groq",
        @"mistral": @"Mistral",
        @"xai": @"xAI",
        @"deepseek": @"DeepSeek"
    };
    NSString *name = names[providerID];
    if (name) return name;
    return providerID.length > 0 ? providerID.capitalizedString : @"Model";
}

- (void)restorePreferredModelIfNeeded {
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:TSPreferredModelKey];
    TSOpenCodeModel *match = nil;
    if (stored.length > 0) {
        for (TSOpenCodeModel *model in self.models) {
            if ([[model persistentIdentifier] isEqualToString:stored]) {
                match = model;
                break;
            }
        }
    }
    if (!match) {
        for (TSOpenCodeModel *model in self.models) {
            if (model.localModel) { match = model; break; }
        }
    }
    if (!match) {
        for (TSOpenCodeModel *model in self.models) {
            if (model.freeModel) { match = model; break; }
        }
    }
    if (!match) {
        match = self.models.firstObject;
    }
    if (match) {
        self.preferredModel = match;
        [[NSUserDefaults standardUserDefaults] setObject:[match persistentIdentifier] forKey:TSPreferredModelKey];
    }
}

- (void)selectModel:(TSOpenCodeModel *)model {
    if (!model) return;
    self.preferredModel = model;
    [[NSUserDefaults standardUserDefaults] setObject:[model persistentIdentifier] forKey:TSPreferredModelKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self notifyModels];
}

- (void)refreshModelsWithCompletion:(void (^)(NSError * _Nullable))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.status == TSOpenCodeStatusReady) {
            [self loadModelsWithCompletion:completion];
            return;
        }
        [self startWithCompletion:^(NSError *error) {
            if (error) {
                if (completion) completion(error);
            } else {
                [self loadModelsWithCompletion:completion];
            }
        }];
    });
}

- (void)generateTextForPrompt:(NSString *)prompt
                        model:(nullable TSOpenCodeModel *)model
                   completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cancelCurrentGeneration];
        [self startWithCompletion:^(NSError *startError) {
            if (startError) {
                completion(nil, startError);
                return;
            }
            TSOpenCodeModel *selected = model ?: self.preferredModel ?: self.models.firstObject;
            if (!selected) {
                completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                                     code:TSOpenCodeErrorRequestFailed
                                                 userInfo:@{NSLocalizedDescriptionKey: @"No OpenCode models are available."}]);
                return;
            }
            NSDictionary *body = @{
                @"prompt": prompt ?: @"",
                @"model": @{@"id": selected.identifier, @"providerID": selected.providerID}
            };
            __weak typeof(self) weakSelf = self;
            [self requestJSONWithMethod:@"POST"
                                   path:@"/api/experimental/generate/text"
                                   body:body
                                timeout:185.0
                             completion:^(id  _Nullable object, NSError * _Nullable error) {
                TSOpenCodeService *strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.currentGenerationTask = nil;
                if (error) {
                    completion(nil, error);
                    return;
                }
                NSString *text = nil;
                if ([object isKindOfClass:[NSDictionary class]]) {
                    id data = object[@"data"];
                    if ([data isKindOfClass:[NSDictionary class]]) {
                        text = [data[@"text"] isKindOfClass:[NSString class]] ? data[@"text"] : nil;
                    }
                }
                if (text.length == 0) {
                    completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                                         code:TSOpenCodeErrorInvalidResponse
                                                     userInfo:@{NSLocalizedDescriptionKey: @"OpenCode returned an empty generation."}]);
                    return;
                }
                completion(text, nil);
            }];
        }];
    });
}

- (void)cancelCurrentGeneration {
    if (self.currentGenerationTask) {
        [self.currentGenerationTask cancel];
        self.currentGenerationTask = nil;
    }
}

+ (BOOL)isRateLimitResponseStatus:(NSInteger)statusCode body:(nullable id)body {
    if (statusCode == 429) return YES;
    if (![body isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *dictionary = (NSDictionary *)body;
    NSNumber *providerStatus = [dictionary[@"status"] isKindOfClass:[NSNumber class]]
        ? dictionary[@"status"] : nil;
    if (providerStatus.integerValue == 429) return YES;
    NSString *reason = [dictionary[@"reason"] isKindOfClass:[NSString class]]
        ? dictionary[@"reason"] : nil;
    NSString *lowerReason = reason.lowercaseString;
    if ([lowerReason containsString:@"rate_limit"] || [lowerReason containsString:@"rate limit"]) {
        return YES;
    }
    NSString *message = [dictionary[@"message"] isKindOfClass:[NSString class]]
        ? dictionary[@"message"] : nil;
    NSString *lowerMessage = message.lowercaseString;
    return [lowerMessage containsString:@"rate limit"] || [lowerMessage containsString:@"usage limit"];
}

- (void)requestJSONWithMethod:(NSString *)method
                         path:(NSString *)path
                         body:(nullable id)body
                      timeout:(NSTimeInterval)timeout
                   completion:(void (^)(id _Nullable object, NSError * _Nullable error))completion {
    if (self.serverURLString.length == 0 ||
        (self.serverPassword.length == 0 && !self.usesExternalServer)) {
        completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                            code:TSOpenCodeErrorStartFailed
                                        userInfo:@{NSLocalizedDescriptionKey: @"OpenCode server URL and password are not available."}]);
        return;
    }
    NSURL *url = [NSURL URLWithString:[self.serverURLString stringByAppendingString:path]];
    if (!url) {
        completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                            code:TSOpenCodeErrorInvalidResponse
                                        userInfo:@{NSLocalizedDescriptionKey: @"The OpenCode server URL is invalid."}]);
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    request.timeoutInterval = timeout;
    NSString *authorization = [self authorizationHeader];
    if (authorization.length > 0) {
        [request setValue:authorization forHTTPHeaderField:@"Authorization"];
    }
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (body) {
        NSError *jsonError = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
        if (!data) {
            completion(nil, jsonError);
            return;
        }
        request.HTTPBody = data;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.URLSession dataTaskWithRequest:request
                                                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TSOpenCodeService *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
                    completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                                        code:TSOpenCodeErrorCancelled
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Generation cancelled."}]);
                } else {
                    completion(nil, error);
                }
                return;
            }
            NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            id object = nil;
            NSError *parseError = nil;
            if (data.length > 0) {
                object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            }
            if (statusCode >= 200 && statusCode < 300) {
                if (object) {
                    completion(object, nil);
                } else {
                    completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                                        code:TSOpenCodeErrorInvalidResponse
                                                    userInfo:@{NSLocalizedDescriptionKey: @"OpenCode returned an unreadable response."}]);
                }
                return;
            }

            NSString *message = @"OpenCode request failed.";
            if ([object isKindOfClass:[NSDictionary class]]) {
                NSString *serverMessage = [object[@"message"] isKindOfClass:[NSString class]] ? object[@"message"] : nil;
                NSString *reason = [object[@"reason"] isKindOfClass:[NSString class]] ? object[@"reason"] : nil;
                if (serverMessage.length > 0) message = serverMessage;
                if (reason.length > 0 && ![message containsString:reason]) {
                    message = [NSString stringWithFormat:@"%@ (%@)", message, reason];
                }
            }
            if (statusCode == 401 || statusCode == 403) {
                message = [NSString stringWithFormat:@"OpenCode authentication failed: %@", message];
            } else if ([self.class isRateLimitResponseStatus:statusCode body:object]) {
                message = [NSString stringWithFormat:@"OpenCode rate limit reached. %@", message];
            } else if (statusCode == 404) {
                message = [NSString stringWithFormat:@"That model isn't available: %@", message];
            } else if (statusCode >= 500) {
                message = [NSString stringWithFormat:@"The model provider is unavailable: %@", message];
            }

            TSOpenCodeErrorCode code = TSOpenCodeErrorRequestFailed;
            if (statusCode == 401 || statusCode == 403) code = TSOpenCodeErrorAuthentication;
            if ([self.class isRateLimitResponseStatus:statusCode body:object]) code = TSOpenCodeErrorQuota;
            completion(nil, [NSError errorWithDomain:TSOpenCodeErrorDomain
                                                code:code
                                            userInfo:@{NSLocalizedDescriptionKey: message,
                                                       @"statusCode": @(statusCode)}]);
        });
    }];
    if ([path isEqualToString:@"/api/experimental/generate/text"]) {
        self.currentGenerationTask = task;
    }
    [task resume];
}

- (NSString *)connectionSummary {
    if (self.status == TSOpenCodeStatusReady && self.serverURLString.length > 0) {
        NSURL *url = [NSURL URLWithString:self.serverURLString];
        return [NSString stringWithFormat:@"%@:%@", url.host ?: @"127.0.0.1", url.port ?: @(0)];
    }
    return @"Not connected";
}

@end
