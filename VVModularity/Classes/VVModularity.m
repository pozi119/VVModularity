//
//  VVModularity.m
//  Pods
//
//  Created by Jinbo Li on 2018/7/5.
//

#import "VVModularity.h"

@implementation VVModularity

+ (NSMutableDictionary *)modules{
    static NSMutableDictionary *_modules;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _modules = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    return _modules;
}

+ (void)setClass:(Class)cls forModule:(NSString *)module{
    NSAssert((cls && [cls conformsToProtocol:@protocol(VVModule)]), @"模块必须遵循`@protocol(VVModule)`协议!");
    [VVModularity.modules setObject:cls forKey:module];
}

+ (void)removeClassForModule:(NSString *)module{
    [VVModularity.modules removeObjectForKey:module];
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
    // 获取目标Class
    Class cls = VVModularity.modules[task.target];
    if(!cls){
        cls = NSClassFromString([NSString stringWithFormat:@"VVModule_%@", task.target]);
        if(!cls) cls = NSClassFromString(task.target);
        if(!cls){
            NSError *error = [self errorWithType:VVModuleErrorModuleNotExists task:task];
            !task.failure ? : task.failure(error);
            return;
        }
        if(![cls conformsToProtocol:@protocol(VVModule)]){
            NSError *error = [self errorWithType:VVModuleErrorModuleInvalid task:task];
            !task.failure ? : task.failure(error);
            return;
        }
        VVModularity.modules[task.target] = cls;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSArray *supportedActions = [cls supportedActions];
    if(![supportedActions containsObject:task.action]){
        NSError *error = [self errorWithType:VVModuleErrorActionNotExists task:task];
        !task.failure ? : task.failure(error);
        return;
    }
    [cls performTask:task];
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
    userInfo[@"task"] = [task description];
    return [NSError errorWithDomain:@"com.valo.vvmodularity" code:type userInfo:userInfo];
}

@end
