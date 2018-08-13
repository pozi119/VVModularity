//
//  VVModularity.m
//  Pods
//
//  Created by Jinbo Li on 2018/7/5.
//

#import "VVModularity.h"

static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;

@interface VVModularityPrivate : NSObject
@property (nonatomic, strong) NSMutableDictionary *modules;
@property (nonatomic, strong) NSMutableDictionary *tasks;
@property (nonatomic, strong) NSMutableDictionary *taskTimes;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSPredicate *hostPredicate;

@end

@implementation VVModularityPrivate
+ (instancetype)innerPrivate{
    static VVModularityPrivate *_innerPrivate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _innerPrivate = [[VVModularityPrivate alloc] init];
        [_innerPrivate startCheckTimeout];
    });
    return _innerPrivate;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _modules = [NSMutableDictionary dictionaryWithCapacity:0];
        _tasks = [NSMutableDictionary dictionaryWithCapacity:0];
        _taskTimes = [NSMutableDictionary dictionaryWithCapacity:0];
        _queue = dispatch_queue_create("com.valo.modularity", NULL);
        dispatch_queue_set_specific(_queue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        NSString *pattern = @"(([a-zA-Z0-9\\.\\-]+\\.([a-zA-Z]{2,4}))|((25[0-5]|2[0-4]\\d|((1\\d{2})|([1-9]?\\d)))\\.){3}(25[0-5]|2[0-4]\\d|((1\\d{2})|([1-9]?\\d))))";
        _hostPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    }
    return self;
}

- (void)startCheckTimeout{
    dispatch_sync(_queue, ^{
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(checkTimeout:) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

- (void)checkTimeout:(NSTimer *)timer{
    NSMutableDictionary *temp = [_taskTimes mutableCopy];
    for (NSString *key in temp) {
        NSUInteger time = [temp[key] unsignedIntegerValue];
        VVModuleTask *task = _tasks[key];
        time ++;
        if (time > task.timeout) {
            !task.cancel ? : task.cancel();
            NSError *error = [VVModularity errorWithType:VVModuleErrorActionTimeout task:task];
            dispatch_async(dispatch_get_main_queue(), ^{
                !task.failure ? : task.failure(error);
                task.success = nil; // 即使task未设置cancel(),完成后也不会再次调用succuss();
                task.failure = nil; // 即使task未设置cancel(),失败后也不会再次调用failure();
            });
        }
        else{
            _taskTimes[key] = @(time);
        }
    }
}

- (void)addTask:(VVModuleTask *)task{
    NSString *key = @(task.taskId).stringValue;
    _tasks[key] = task;
    _taskTimes[key] = @(0);
}

- (void)removeTask:(VVModuleTask *)task{
    NSString *key = @(task.taskId).stringValue;
    [_tasks removeObjectForKey:key];
    [_taskTimes removeObjectForKey:key];
}

@end

@implementation VVModularity

+ (void)setClass:(id)cls forModule:(NSString *)module{
    Class clazz = [cls isKindOfClass:NSString.class] ? NSClassFromString(cls) : cls;
    BOOL confirmTask = [clazz respondsToSelector:@selector(performTask:)];
    BOOL confirmAction = [clazz respondsToSelector:@selector(performAction:parameters:progress:success:failure:)];
    NSAssert( clazz && (confirmTask || confirmAction), @"Module must responese `performTask:` or `performAction:parameters:progress:success:failure:`");
    [[VVModularityPrivate innerPrivate].modules setObject:clazz forKey:module];
}

+ (void)removeClassForModule:(NSString *)module{
    [[VVModularityPrivate innerPrivate].modules removeObjectForKey:module];
}

+ (BOOL)openURL:(NSURL *)url completionHandler:(void (^)(BOOL))completion{
    NSAssert(url, @"url is nil!");
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    /** 1.检查scheme是否匹配 */
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSMutableSet *schemes = [NSMutableSet setWithCapacity:0];
    for (NSDictionary *dic in urlTypes) {
        NSArray *tmpArray  = dic[@"CFBundleURLSchemes"];
        [schemes addObjectsFromArray:tmpArray];
    }
    [schemes addObjectsFromArray:@[@"http",@"https"]];
    BOOL match = NO;
    for (NSString *scheme in schemes) {
        if ([scheme.lowercaseString isEqualToString:components.scheme.lowercaseString]) {
            match = YES;
            break;
        }
    }
    if (!match) {
        !completion ? : completion(NO);
        return NO;
    }
    
    /** 2. 获取Module */
    /* 传入URL格式应该遵循以下规则
     `app://module/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
     `app://www.xxx.com/module/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
     `app://192.168.11.2/module/action/sub1path/sub2path?key1=val1&key2=val2 ...`
     */
    BOOL isHost = [[VVModularityPrivate innerPrivate].hostPredicate evaluateWithObject:components.host];
    NSArray *array = [components.path componentsSeparatedByString:@"/"]; //array[0] = @"";
    if((isHost && array.count < 3) || (!isHost && array.count < 2)) return NO;
    NSString *module = isHost ? array[1] : components.host;
    
    /** 3. 获取Action */
    // 若传入URL的path中包含有module名,则去后面一个作为action名
    NSString *action = isHost ? array[2]: array[1];
    
    /** 4. 获取Parameters */
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    NSString *tmpstr = isHost ? [NSString stringWithFormat:@"%@/%@",module,action] : action;
    NSRange range = [components.path rangeOfString:tmpstr];
    NSString *subpath = [components.path substringFromIndex:range.location + range.length];
    parameters[kVVModuleSubPath] = subpath;
    for (NSURLQueryItem *item in components.queryItems) {
        [parameters addEntriesFromDictionary:@{item.name: item.value}];
    }
    
    /** 5. 处理模块请求 */
    return [self performTarget:module action:action parameters:parameters success:^(id responseObject) {
        !completion ? : completion(YES);
    } failure:^(NSError *error) {
        !completion ? : completion(NO);
    }];
}

+ (BOOL)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(id)parameters{
    return [self performTarget:module
                        action:action
                    parameters:parameters
                       success:nil
                       failure:nil];
}

+ (BOOL)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(id)parameters
              success:(nullable void (^)(id _Nullable))success
              failure:(nullable void (^)(NSError *))failure{
    VVModuleTask *task = [VVModuleTask taskWithTarget:module action:action];
    task.parameters = parameters;
    task.success = success;
    task.failure = failure;
    return [self performModuleTask:task];
}

+ (id)syncPerformTarget:(NSString *)module
                 action:(NSString *)action
             parameters:(id)parameters{
    __block id result = nil;
    dispatch_semaphore_t lock = dispatch_semaphore_create(0);
    [self performTarget:module action:action parameters:parameters success:^(id  _Nullable responseObject) {
        result = responseObject;
        dispatch_semaphore_signal(lock);
    } failure:^(NSError *error) {
        result = error;
        dispatch_semaphore_signal(lock);
    }];
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    return result;
}

+ (BOOL)performModuleTask:(VVModuleTask *)task{
    VVModuleTask *taskcopy = [task copy];
    // 获取目标Class
    Class cls = [VVModularityPrivate innerPrivate].modules[taskcopy.target];
    BOOL confirmTask = [cls respondsToSelector:@selector(performTask:)];
    BOOL confirmAction = [cls respondsToSelector:@selector(performAction:parameters:progress:success:failure:)];
    if(!cls){
        cls = NSClassFromString([NSString stringWithFormat:@"VVModule_%@", taskcopy.target]);
        if(!cls) cls = NSClassFromString(taskcopy.target);
        if(!cls){
            NSError *error = [self errorWithType:VVModuleErrorModuleNotExists task:taskcopy];
            !taskcopy.failure ? : taskcopy.failure(error);
            return NO;
        }
        confirmTask = [cls respondsToSelector:@selector(performTask:)];
        confirmAction = [cls respondsToSelector:@selector(performAction:parameters:progress:success:failure:)];
        if(!(confirmTask || confirmAction)){
            NSError *error = [self errorWithType:VVModuleErrorModuleInvalid task:taskcopy];
            !taskcopy.failure ? : taskcopy.failure(error);
            return NO;
        }
        [VVModularityPrivate innerPrivate].modules[taskcopy.target] = cls;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if([cls respondsToSelector:@selector(supportedActions)]){
        NSArray *supportedActions = [cls supportedActions];
        if(![supportedActions containsObject:taskcopy.action]){
            NSError *error = [self errorWithType:VVModuleErrorActionNotExists task:taskcopy];
            !taskcopy.failure ? : taskcopy.failure(error);
            return NO;
        }
    }
    
    void(^origSuccess)(id __nullable responseObject) = [taskcopy.success copy];
    void(^origFailure)(NSError *error) = [taskcopy.failure copy];
    void(^success)(id __nullable responseObject) = ^(id __nullable responseObject) {
        !origSuccess ? : origSuccess(responseObject);
        [[VVModularityPrivate innerPrivate] removeTask:taskcopy];
        NSLog(@"response: %@",responseObject);
    };
    void(^failure)(NSError *error) = ^(NSError *error) {
        !origFailure ? : origFailure(error);
        [[VVModularityPrivate innerPrivate] removeTask:taskcopy];
        NSLog(@"error: %@",error);
    };
    taskcopy.timeout = 5;
    taskcopy.success = success;
    taskcopy.failure = failure;
    if([cls respondsToSelector:@selector(cancelAction:)]){
        __weak typeof(taskcopy) weakTask = taskcopy;
        taskcopy.cancel = ^{
            __strong typeof(weakTask) strongTask = weakTask;
            [cls cancelAction:strongTask.action];
        };
    }
    [[VVModularityPrivate innerPrivate] addTask:taskcopy];
    if(confirmTask){
        [cls performTask:taskcopy];
    }
    else{
        [cls performAction:taskcopy.action
                parameters:taskcopy.parameters
                  progress:taskcopy.progress
                   success:taskcopy.success
                   failure:taskcopy.failure];
    }
#pragma clang diagnostic pop
    return YES;
}

+ (NSError *)errorWithType:(VVModuleError)type task:(VVModuleTask *)task{
    NSString *errorDescription = @"Unknown error";
    switch (type) {
        case VVModuleErrorModuleNotExists:
            errorDescription = @"Module dose not exists";
            break;
            
        case VVModuleErrorModuleInvalid:
            errorDescription = @"Module must responese `performTask:` or `performAction:parameters:progress:success:failure:`";
            break;
            
        case VVModuleErrorActionNotExists:
            errorDescription = @"Action dose not exists";
            break;
            
        case VVModuleErrorActionTimeout:
            errorDescription = @"Action timeout";
            break;

        default:
            break;
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:0];
    userInfo[NSLocalizedDescriptionKey] = errorDescription;
    userInfo[@"targetClass"] = [VVModularityPrivate innerPrivate].modules[task.target];
    userInfo[@"task"] = [task description];
    return [NSError errorWithDomain:@"com.valo.vvmodularity" code:type userInfo:userInfo];
}

@end
