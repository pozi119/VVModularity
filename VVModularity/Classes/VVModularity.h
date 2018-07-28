//
//  VVModularity.h
//  Pods
//
//  Created by Jinbo Li on 2018/7/5.
//

#import <Foundation/Foundation.h>
#import "VVModuleTask.h"

typedef enum : NSUInteger {
    VVModuleErrorModuleNotExists = 1,
    VVModuleErrorModuleInvalid,
    VVModuleErrorActionNotExists,
    VVModuleErrorActionTimeout,
} VVModuleError;

@protocol VVModule <NSObject>

/**
 模块支持的actions

 @return action名称数组
 */
+ (NSArray<NSString *> *)supportedActions;

/**
 执行模块任务

 @param task 模块任务
 */
+ (void)performTask:(VVModuleTask *)task;

@end

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
 */
+ (void)openURL:(NSURL*)url completionHandler:(void (^ __nullable)(BOOL success))completion;

/**
 执行模块任务
 
 @param task 模块任务
 */
+ (void)performModuleTask:(VVModuleTask *)task;

/**
 执行模块任务

 @param module 目标模块名
 @param action 模块操作
 @param parameters 传递参数
 */
+ (void)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(nullable id)parameters;

/**
 执行模块任务

 @param module 目标模块名
 @param action 模块操作
 @param parameters 传递参数
 @param success 成功后的处理
 @param failure 失败后的处理
 */
+ (void)performTarget:(NSString *)module
               action:(NSString *)action
           parameters:(nullable id)parameters
              success:(nullable void (^)(id __nullable responseObject))success
              failure:(nullable void (^)(NSError *error))failure;

/**
 生成Error信息

 @param type 错误类型
 @param task 模块任务
 @return NSError错误信息
 */
+ (NSError *)errorWithType:(VVModuleError)type
                      task:(VVModuleTask *)task;

@end
