//
//  AudioEncoder.h
//  直播
//
//  Created by Hock on 2020/4/27.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class AudioEncoder;
@protocol AudioHWACCEncoderDelegate <NSObject>

- (void)audioEncoder:(AudioEncoder *)encoder audioHeader:(NSData *)headerData;
- (void)audioEncoder:(AudioEncoder *)encoder audioData:(NSData *)dataData;

@end

@interface AudioEncoder : NSObject

@property (nonatomic, copy) NSString *saveFileName;
@property (nonatomic, weak) id <AudioHWACCEncoderDelegate> delegate;

@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) dispatch_queue_t callbackQueue;

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(NSData *encodedData, NSError* error))completionBlock;

- (void)endAudioToolBox;

@end

NS_ASSUME_NONNULL_END
