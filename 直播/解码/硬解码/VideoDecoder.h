//
//  VideoDecoder.h
//  直播
//
//  Created by Hock on 2020/5/3.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VideoDecodeDelegate <NSObject>

- (void)didDecodePixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end


@interface VideoDecoder : NSObject

@property (nonatomic, weak) id <VideoDecodeDelegate> delegate;

- (void)startDecode;

- (void)sendSpsData:(NSData *)spsData ppsData:(NSData *)ppsData;

- (void)sendVideoData:(NSData *)videoData isKeyFrame:(BOOL)isKeyFrame;

@end

NS_ASSUME_NONNULL_END
