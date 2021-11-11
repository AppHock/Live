//
//  RtmpClient.h
//  直播
//
//  Created by Hock on 2020/5/2.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "rtmp.h"

@protocol RtmpClientRecvDelegate <NSObject>

- (void)didRtmpRecvSps:(NSData *_Nullable)sps pps:(NSData *_Nonnull)pps;

- (void)didRtmpRecvVideoData:(NSData *_Nullable)videoData isKeyFrame:(BOOL)isKeyFrame;

- (void)didRtmpRecvAudioHeaderData:(NSData *_Nullable)audioHeaderData;

- (void)didRtmpRecvAudioData:(NSData *_Nullable)audioData;

- (void)didStopRtmpConnect;

@end

NS_ASSUME_NONNULL_BEGIN

typedef enum: NSInteger {
    RTMP_SEND = 0,
    RTMP_RECV
} RTMPType;

@interface RtmpClient : NSObject
{
    RTMP *rtmp;
//    double start_time;
}

@property (nonatomic, assign) double start_time;
@property (nonatomic, assign) RTMPType type;

@property (nonatomic, weak) id <RtmpClientRecvDelegate> recvDelegate;

- (RTMP *)getCurrentRtmp;

// 初始化
+ (instancetype)getInstance;

// 建立连接
- (BOOL)startRtmpConnect:(NSString *)url;

// 退出直播
- (void)exitLive;

/**
 发送视频sps、pps数据
 */
- (void)sendVideoSps:(NSData *)spsData pps:(NSData *)ppsData;

/**
 发送视频帧数据
 */
- (void)sendVideoData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame;

/**
 发送音频头信息
 */
- (void)sendAudioHeader:(NSData *)data;

/**
 发送音频数据
 */
- (void)sendAudioData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
