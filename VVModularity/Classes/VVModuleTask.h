//
//  VVModuleTask.h
//  VVModularity
//
//  Created by Jinbo Li on 2018/7/25.
//

#import <Foundation/Foundation.h>

@interface VVModuleTask : NSObject
@property (nonatomic, assign, readonly) NSUInteger taskId;  ///< 任务id
@property (nonatomic, copy  ) NSString *target;   ///< 目标模块名
@property (nonatomic, copy  ) NSString *action;   ///< 操作
@property (nonatomic, assign) NSUInteger timeout; ///< 任务超时时间(秒),默认为30秒
@property (nullable, nonatomic, strong) id parameters;        ///< 传递参数
@property (nullable, nonatomic, copy  ) NSString *source;     ///< 源模块名,可不传入
@property (nullable, nonatomic, strong) NSProgress *progress; ///< 进度
@property (nullable, nonatomic, copy  ) void (^success)(id __nullable responseObject); ///< 成功后的操作
@property (nullable, nonatomic, copy  ) void (^failure)(NSError *error);               ///< 失败后的操作

+ (instancetype)taskWithModule:(NSString *)module action:(NSString *)action;

@end
