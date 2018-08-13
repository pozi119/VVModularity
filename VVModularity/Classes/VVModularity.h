//
//  VVModularity.h
//  Pods
//
//  Created by Jinbo Li on 2018/7/5.
//

#import <Foundation/Foundation.h>
#import "VVModuleTask.h"

#define kVVModuleSubPath @"_vvmodule_subpath" ///< 传入URL时,除module和action外的子路径,由模块自行处理

typedef enum : NSUInteger {
    VVModuleErrorModuleNotExists = 1,
    VVModuleErrorModuleInvalid,
    VVModuleErrorActionNotExists,
    VVModuleErrorActionTimeout,
} VVModuleError;

/**
 模块需实现的协议
 @note `+performTask:`和`+performAction:parameters:progress:success:failure:`二者必实现其一
 */
@protocol VVModule <NSObject>

@optional

/**
 支持的Action

 @return action名称数组
 */
+ (nullable NSArray<NSString *> *)supportedActions;

/**
 执行模块任务

 @param task 模块任务
 @note `+performTask:`和`+performAction:parameters:progress:success:failure:`二者必实现其一
 */
+ (void)performTask:(VVModuleTask *)task;

/**
 模块执行Action

 @param action action名
 @param parameters 参数
 @param progress 进度
 @param success 成功后的操作
 @param failure 失败后的操作
 @note `+performTask:`和`+performAction:parameters:progress:success:failure:`二者必实现其一
 */
+ (void)performAction:(NSString *)action
           parameters:(nullable id)parameters
             progress:(nullable NSProgress *)progress
              success:(nullable void (^)(id __nullable responseObject))success
              failure:(nullable void (^)(NSError *error))failure;

/**
 取消执行某个Action

 @param action 要取消执行的Action
 @note 取消执行Action的方式:1.实现本方法 2.若使用`+performTask:`,可设置`task.cancel()`;
 
 若未实现取消操作,则在超时之后会继续执行,但不会返回执行结果
 */
+ (void)cancelAction:(NSString *)action;

@end

/**
 模块化中间件,使用类似http请求的方式进行异步交互
 */
@interface VVModularity : NSObject

- (instancetype)init NS_UNAVAILABLE; //禁用`-init`方法
+ (instancetype)new NS_UNAVAILABLE;  //禁用`+new`方法

/**
 将类和模块名进行映射

 @param cls Objective-C类/类名
 @param module 模块名
 */
+ (void)setClass:(id)cls forModule:(NSString *)module;

/**
 删除类和模块名的映射关系

 @param module 模块名
 */
+ (void)removeClassForModule:(NSString *)module;

/**
 处理URL

 @param url url
 @param completion 完成后的操作
 @return 是否传递到模块
 @note URL应遵循以下格式:
 
 `app://module/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
 
 `app://www.xxx.com/module/action/sub1path/sub2path?key1=val1&key2=val2 ...`,
 
 `app://192.168.11.2/module/action/sub1path/sub2path?key1=val1&key2=val2 ...`
 */
+ (BOOL)openURL:(NSURL*)url completionHandler:(void (^ __nullable)(BOOL success))completion;

/**
 执行模块任务
 
 @param task 模块任务
 @return 是否传递到模块
 */
+ (BOOL)performModuleTask:(VVModuleTask *)task;

/**
 执行模块任务

 @param module 目标模块名
 @param action 模块操作
 @param parameters 传递参数
 @return 是否传递到模块
 */
+ (BOOL)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(nullable id)parameters;

/**
 执行模块任务

 @param module 目标模块名
 @param action 模块操作
 @param parameters 传递参数
 @param success 成功后的处理
 @param failure 失败后的处理
 @return 是否传递到模块
 */
+ (BOOL)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(nullable id)parameters
              success:(nullable void (^)(id __nullable responseObject))success
              failure:(nullable void (^)(NSError *error))failure;

/**
 执行模块任务,同步方式

 @param module 目标模块名
 @param action 模块操作
 @param parameters 传递参数
 @return 成功则返回执行结果(可为nil),失败则返回Error信息
 */
+ (nullable id)syncPerformTarget:(NSString *)module
                          action:(NSString *)action
                      parameters:(nullable id)parameters;

/**
 生成Error信息

 @param type 错误类型
 @param task 模块任务
 @return NSError错误信息
 */
+ (NSError *)errorWithType:(VVModuleError)type
                      task:(VVModuleTask *)task;

@end
