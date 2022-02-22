//
//  UIButton+Live.m
//  直播
//
//  Created by Hock on 2021/11/14.
//  Copyright © 2021 Hock. All rights reserved.
//

#import "UIButton+Live.h"

@implementation UIButton (Live)

+ (instancetype)creatTestButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(100, 100, 100, 40);
    return button;
}

@end
