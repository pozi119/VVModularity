//
//  VVModuleAA.m
//  ModuleAA
//
//  Created by Jinbo Li on 2018/7/25.
//  Copyright © 2018年 pozi119. All rights reserved.
//

#import "VVModuleAA.h"

@implementation VVModuleAA

+ (NSArray<NSString *> *)supportedActions{
    return @[@"aa"];
}

+ (void)performTask:(VVModuleTask *)task{
    if([task.action isEqualToString:@"aa"]){
        NSInteger total = 10;
        __block NSUInteger i = 0;
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            i ++;
            if (task.progress) {
                task.progress.completedUnitCount =  i * task.progress.totalUnitCount / total;
            }
            if(i >= total){
                !task.success ? : task.success(task.progress);
                [timer invalidate];
            }
        }];
        [task setCancel:^{
            [timer invalidate];
        }];
    }
}

@end
