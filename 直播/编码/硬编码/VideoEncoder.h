//
//  VideoEncoder.h
//  直播
//
//  Created by Hock on 2020/4/27.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class VideoEncoder;
@protocol VideoHWH264EncoderDelegate <NSObject>

- (void)videoEncoder:(VideoEncoder *)encoder sps:(NSData *)spsData pps:(NSData *)ppsData;

- (void)videoEncoder:(VideoEncoder *)encoder videoData:(NSData *)videoData isKeyFrame:(BOOL)isKeyFrame
;

@end

@interface VideoEncoder : NSObject

@property (nonatomic, copy) NSString *saveFileName;

@property (nonatomic, weak) id <VideoHWH264EncoderDelegate> delegate;

- (void)startVideoToolBox;
- (void)endVideoToolBox;

- (void)encode:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
