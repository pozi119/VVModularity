//
//  VVViewController.m
//  VVModularity
//
//  Created by pozi119 on 07/05/2018.
//  Copyright (c) 2018 pozi119. All rights reserved.
//

#import "VVViewController.h"
#import "VVModuleAA.h"
#import "VVModuleBB.h"

@interface VVViewController ()

@end

@implementation VVViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [VVModularity setClass:VVModuleAA.class forModule:@"ma"];
    [VVModularity setClass:VVModuleAA.class forModule:@"mb"];
    [self test];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)test{
    __block NSInteger count = 0;
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        count ++;
        [self createTask];
        if(count > 5){
            [timer invalidate];
        }
    }];
}

- (void)createTask{
    VVModuleTask *task = [VVModuleTask taskWithTarget:@"ma" action:@"aa"];
    task.progress = [NSProgress progressWithTotalUnitCount:100];
    [task setSuccess:^(id responseObject) {
        NSLog(@"response: %@", responseObject);
    }];
    [VVModularity performModuleTask:task];
    [task.progress addObserver:self forKeyPath:@"completedUnitCount" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    NSLog(@"progress: %@",@([(NSProgress *)object fractionCompleted]));
}

@end
