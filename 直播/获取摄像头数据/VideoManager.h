//
//  VideoManager.h
//  直播
//
//  Created by Hock on 2020/4/27.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
    AVCaptureMediaVideo,
    AVCaptureMediaAudio,
    AVCaptureMediaAll
}AVCaptureMediaType;

@protocol VideoCaptureOutputDelegate <NSObject>

- (void)outputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(AVCaptureMediaType)type;

@end

@interface VideoManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong) UIView *superview;

@property (nonatomic, weak) id <VideoCaptureOutputDelegate> delegate;

- (void)startRunning;

- (void)stopRunning;

- (void)changeCarema;
@end

NS_ASSUME_NONNULL_END
