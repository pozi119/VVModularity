//
//  VVModuleBB.m
//  ModuleBB
//
//  Created by Jinbo Li on 2018/7/25.
//  Copyright © 2018年 pozi119. All rights reserved.
//

#import "VVModuleBB.h"

@implementation VVModuleBB

+ (NSArray<NSString *> *)supportedActions{
    return @[@"bb"];
}

+ (void)performTask:(VVModuleTask *)task{
    if([task.action isEqualToString:@"bb"]){
        NSLog(@"VVModuleBB: bb");
    }
}

@end
