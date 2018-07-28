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
    NSAssert((clazz && [clazz conformsToProtocol:@protocol(VVModule)]), @"模块必须遵循`@protocol(VVModule)`协议!");
    [[VVModularityPrivate innerPrivate].modules setObject:clazz forKey:module];
}

+ (void)removeClassForModule:(NSString *)module{
    [[VVModularityPrivate innerPrivate].modules removeObjectForKey:module];
}

+ (void)openURL:(NSURL *)url completionHandler:(void (^)(BOOL))completion{
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
        return;
    }
    
    /** 2. 获取Module */
    NSString *module = components.host;
    
    /** 3. 获取Action */
    NSString *action = [components.path stringByReplacingOccurrencesOfString:@"/" withString:@""];

    /** 4. 获取Parameters */
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) {
        [parameters addEntriesFromDictionary:@{item.name: item.value}];
    }
    
    /** 5. 处理模块请求 */
    [self performTarget:module action:action parameters:parameters success:^(id responseObject) {
        !completion ? : completion(YES);
    } failure:^(NSError *error) {
        !completion ? : completion(NO);
    }];
}

+ (void)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(id)parameters{
    [self performTarget:module
                 action:action
             parameters:parameters
                success:nil
                failure:nil];
}

+ (void)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(id)parameters
              success:(nullable void (^)(id _Nullable))success
              failure:(nullable void (^)(NSError *))failure{
    VVModuleTask *task = [VVModuleTask taskWithTarget:module action:action];
    task.parameters = parameters;
    task.success = success;
    task.failure = failure;
    [self performModuleTask:task];
}

+ (void)performModuleTask:(VVModuleTask *)task{
    VVModuleTask *taskcopy = [task copy];
    // 获取目标Class
    Class cls = [VVModularityPrivate innerPrivate].modules[taskcopy.target];
    if(!cls){
        cls = NSClassFromString([NSString stringWithFormat:@"VVModule_%@", taskcopy.target]);
        if(!cls) cls = NSClassFromString(taskcopy.target);
        if(!cls){
            NSError *error = [self errorWithType:VVModuleErrorModuleNotExists task:taskcopy];
            !taskcopy.failure ? : taskcopy.failure(error);
            return;
        }
        if(![cls conformsToProtocol:@protocol(VVModule)]){
            NSError *error = [self errorWithType:VVModuleErrorModuleInvalid task:taskcopy];
            !taskcopy.failure ? : taskcopy.failure(error);
            return;
        }
        [VVModularityPrivate innerPrivate].modules[taskcopy.target] = cls;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSArray *supportedActions = [cls supportedActions];
    if(![supportedActions containsObject:taskcopy.action]){
        NSError *error = [self errorWithType:VVModuleErrorActionNotExists task:taskcopy];
        !taskcopy.failure ? : taskcopy.failure(error);
        return;
    }
    {
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
        [[VVModularityPrivate innerPrivate] addTask:taskcopy];
        [cls performTask:taskcopy];
    }
#pragma clang diagnostic pop
}

+ (NSError *)errorWithType:(VVModuleError)type task:(VVModuleTask *)task{
    NSString *errorDescription = @"其他错误!";
    switch (type) {
        case VVModuleErrorModuleNotExists:
            errorDescription = @"模块不存在!";
            break;
            
        case VVModuleErrorModuleInvalid:
            errorDescription = @"模块必须遵循`@protocol(VVModule)`协议!";
            break;
            
        case VVModuleErrorActionNotExists:
            errorDescription = @"模块不支持此操作!";
            break;

        case VVModuleErrorActionTimeout:
            errorDescription = @"模块操作超时!";
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
