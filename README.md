# VVModularity

[![CI Status](https://img.shields.io/travis/pozi119/VVModularity.svg?style=flat)](https://travis-ci.org/pozi119/VVModularity)
[![Version](https://img.shields.io/cocoapods/v/VVModularity.svg?style=flat)](https://cocoapods.org/pods/VVModularity)
[![License](https://img.shields.io/cocoapods/l/VVModularity.svg?style=flat)](https://cocoapods.org/pods/VVModularity)
[![Platform](https://img.shields.io/cocoapods/p/VVModularity.svg?style=flat)](https://cocoapods.org/pods/VVModularity)

## 功能

* [x] 模块化中间件
* [x] 解耦,模块无需包含本中间件头文件
* [x] URL支持
* [x] 异步操作,可设置超时,默认30s超时

## 安装

VVModularity支持[CocoaPods](https://cocoapods.org). 请在 Podfile中加入:

```ruby
pod 'VVModularity'
```

## 用法
### 模块
`+performTask:`和`+performAction:parameters:progress:success:failure:`**二者实现其一**; 其中`+performTask:`需要包含`VVModularity.h`.

`+cancelAction:` performTask方式可以在操作中定义task.cancel()达到同样目的; **可选实现**; 若不实现, 则当Action超时时,不会取消模块的操作,但是最后也不会处理操作结果.

`+supportedActions` **可选实现**; 若实现,则会先检查action是否被模块支持.

示例:
```objc
+ (void)performAction:(NSString *)action
           parameters:(nullable id)parameters
             progress:(nullable NSProgress *)progress
              success:(nullable void (^)(id __nullable responseObject))success
              failure:(nullable void (^)(NSError *error))failure{
    if([action isEqualToString:@"aa"]){
        NSInteger total = 10;
        __block NSUInteger i = 0;
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            i ++;
            if (progress) {
                progress.completedUnitCount =  i * progress.totalUnitCount / total;
            }
            NSLog(@"VVModuleAA-->: %@", @(i));
            if(i >= total){
                !success ? : success(progress);
                [timer invalidate];
            }
        }];
    }
}
```

### 调用模块
需包含`VVModularity.h`头文件
```objc
    VVModuleTask *task = [VVModuleTask taskWithTarget:@"ma" action:@"aa"];
    task.progress = [NSProgress progressWithTotalUnitCount:100];
    [task setSuccess:^(id responseObject) {
        NSLog(@"response: %@", responseObject);
    }];
    [VVModularity performModuleTask:task];
    
    //操作成功或失败无需处理
    [VVModularity performTarget:@"VVModuleBB" action:@"bb" parameters:nil]
```
URL方式,请在AppDelegate中加入相应代码:
```objc
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url{
    return [VVModularity openURL:url completionHandler:nil];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication annotation:(id)annotation{
    return [VVModularity openURL:url completionHandler:nil];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options{
    return [VVModularity openURL:url completionHandler:nil];
}
```

## 作者

pozi119, pozi119@163.com

## 协议

VVModularity 被许可在 MIT 协议下使用。查阅 LICENSE 文件来获得更多信息。
