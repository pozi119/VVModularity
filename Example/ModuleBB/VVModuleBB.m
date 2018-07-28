//
//  VVModuleBB.m
//  ModuleBB
//
//  Created by Jinbo Li on 2018/7/25.
//  Copyright © 2018年 pozi119. All rights reserved.
//

#import "VVModuleBB.h"

@implementation VVModuleBB

+ (void)performAction:(NSString *)action
           parameters:(nullable id)parameters
             progress:(nullable NSProgress *)progress
              success:(nullable void (^)(id __nullable responseObject))success
              failure:(nullable void (^)(NSError *error))failure{
    if([action isEqualToString:@"bb"]){
        NSLog(@"VVModuleBB: bb");
    }
}

@end
