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

@end
