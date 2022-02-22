//
//  A_PViewController.m
//  直播
//
//  Created by Hock on 2021/11/14.
//  Copyright © 2021 Hock. All rights reserved.
//

#import "A_PViewController.h"
#import "UIButton+Live.h"
#import "aac2pcm.h"
#import <AVFoundation/AVFoundation.h>

@interface A_PViewController ()
@property (nonatomic, strong) aac2pcm *a_p;
@end

@implementation A_PViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    UIButton *button = [UIButton creatTestButton];
    [self.view addSubview:button];
    [button setTitle:@"开始录制" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [button addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
}

- (void)click {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        [[[aac2pcm alloc] init] start];
    }];
}

@end
