//
//  VVModuleTask.m
//  VVModularity
//
//  Created by Jinbo Li on 2018/7/25.
//

#import "VVModuleTask.h"

@implementation VVModuleTask

+ (instancetype)taskWithTarget:(NSString *)target action:(NSString *)action{
    VVModuleTask *task = [[VVModuleTask alloc] init];
    task.target = target;
    task.action = action;
    return task;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _timeout = 30;
        _taskId = [self generateTaskId];
    }
    return self;
}

- (instancetype)initForCopy
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (NSUInteger)generateTaskId{
    static NSUInteger __taskId = 0;
    static dispatch_once_t onceToken;
    static dispatch_semaphore_t lock;
    dispatch_once(&onceToken, ^{
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    __taskId ++;
    dispatch_semaphore_signal(lock);
    return __taskId;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"taskId: %@, target: %@, source: %@, action: %@, timeout: %@, parameters: %@, progress: %@",@(_taskId),_target, _source, _action, @(_timeout), _parameters, _progress];
}

- (void)cancelTask{
    !_cancel ? : _cancel();
}

//MARK: - NSCopying
- (id)copyWithZone:(nullable NSZone *)zone{
    VVModuleTask *task = [[VVModuleTask alloc] initForCopy];
    task->_taskId = self.taskId;
    task.target = [self.target copy];
    task.action = [self.action copy];
    task.timeout = self.timeout;
    task.parameters = [self.parameters copy];
    task.source = [self.source copy];
    task.progress = self.progress;
    task.cancel  = [self.cancel copy];
    task.success = [self.success copy];
    task.failure = [self.failure copy];
    return task;
}

@end
