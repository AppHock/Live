//
//  VideoEncoder.m
//  直播
//
//  Created by Hock on 2020/4/27.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "VideoEncoder.h"

@interface VideoEncoder ()
{
    int frameID;
    dispatch_queue_t mEncodeQueue;
    VTCompressionSessionRef EncodingSession;
    CMFormatDescriptionRef  format;
    NSFileHandle *fileHandle;
}
@end

@implementation VideoEncoder


- (void)setSaveFileName:(NSString *)saveFileName {
    mEncodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    saveFileName = [saveFileName stringByAppendingString:@".h264"];
    _saveFileName = saveFileName;
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:saveFileName];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
}

- (void)startVideoToolBox
{
    dispatch_sync(mEncodeQueue, ^{
        frameID = 0;
        int width = 480, height = 640;
        OSStatus status = VTCompressionSessionCreate(NULL,
                                                     width,
                                                     height,
                                                     kCMVideoCodecType_H264,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     didCompressH264,
                                                     (__bridge void *)(self),
                                                     &EncodingSession);
        if (status != 0) {
            NSLog(@"H264: Unable to create a H264 session");
            return ;
        }
        
        // 设置实时编码输出（避免延迟）
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        // GOP：设置关键帧（IDR）间隔
        int frameInterval = 20;
        CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        
        // 设置期望帧率
        int fps = 20;
        CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        // 设置码率，单位bps（码率 = 图片像素宽 * 图片像素高 * 像素大小 * 一个字节为8位 * 帧率）
        int bitRate = width * height * 3 * 8 * fps;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bitRate);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        
        // 设置码率上线，单位Bps
        int bitRateLimit = width * height * 3 * fps * 1.5;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bitRateLimit);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        // 开始编码
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
    });
}

- (void)endVideoToolBox
{
    if (EncodingSession != NULL) {
        VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(EncodingSession);
        CFRelease(EncodingSession);
        EncodingSession = NULL;
    }
    
    [fileHandle closeFile];
    fileHandle = NULL;
}

- (void)encode:(CMSampleBufferRef )sampleBuffer
{
//    dispatch_sync(mEncodeQueue, ^{
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        // 帧时间，如果不设置会导致时间轴过长
        CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000);
        VTEncodeInfoFlags flags;
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL,
                                                              NULL,
                                                              &flags);
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);

            VTCompressionSessionInvalidate(EncodingSession);
            CFRelease(EncodingSession);
            EncodingSession = NULL;
            return;
        }
//    });
}


void didCompressH264(void *outputCallbackRefcon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    if (status != 0) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    VideoEncoder *encoder = (__bridge VideoEncoder*)outputCallbackRefcon;
    
    bool keyFrame = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps 和 pps数据
    
    if (keyFrame) {
        NSLog(@"this is I Frame");
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetsize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetsize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                NSData *sps_D = [[NSUserDefaults standardUserDefaults] objectForKey:@"KeySPS"];
                NSData *pps_D = [[NSUserDefaults standardUserDefaults] objectForKey:@"KeyPPS"];
                
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetsize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
                if (!sps_D.length || !pps_D.length) {
                    [[NSUserDefaults standardUserDefaults] setObject:sps forKey:@"KeySPS"];
                    [[NSUserDefaults standardUserDefaults] setObject:pps forKey:@"KeyPPS"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                
                if (sps_D.length && pps_D.length) {
                    sps = [NSData dataWithData:sps_D];
                    pps = [NSData dataWithData:pps_D];
                }
                
                // 如果sps和pps只发送一次，会造成后进入直播间的人收不到sps和pps，需要后台保存，主动发送给客户端
                static BOOL isSendSPS_PPS = YES; // 默认是NO
                if (encoder) {
                    // rtmp直播推流，只需要发送一次即可，若要保存文件则每个I帧前需要保存sps和pps信息
                    if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(videoEncoder:sps:pps:)]) {
                        isSendSPS_PPS = YES;
                        [encoder.delegate videoEncoder:encoder sps:sps pps:pps];
                    }
                    [encoder gotSpsPps:sps pps:pps];
                }
            }
        }
    }
    
    // CMBlockBufferRef = 编码之后的数据格式
    CMBlockBufferRef dataBuffet = CMSampleBufferGetDataBuffer(sampleBuffer);
    // totalLength为当前编码帧的总长度
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffet, 0, &length, &totalLength, &dataPointer);
    
    
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        /*
         硬编码后得到的nalu数据前四个字节不是0001的startCode，而是大端模式的长度length，在保存成H264文件的时候才需要在每个NALU数据和最后一个NALU数组尾插入0001的startCode代码
         iOS属于小端模式，需要把大端数据转为小端，获取到nalu数据的真实长度
         */
        static const int AVCCHeaderLength = 4;
        
        // 循环获取nalu数据
        
        NSMutableData *audioMuData = [NSMutableData data];
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            NSMutableData *mD = [NSMutableData dataWithBytes:dataPointer+bufferOffset length:AVCCHeaderLength];
            uint32_t NALUnitLength = 0;
            // 一帧数据可能会分隔成多个nalu数据包，读取当前nalu数据的真实长度
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            // mD网络传输，需保留大端模式前4个字节
//            NSMutableData *mD = [NSMutableData dataWithBytes:dataPointer+bufferOffset length:AVCCHeaderLength];
            
            
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
//            [data showBytes:data.length];
            // 保存h264文件
//            [encoder gotEncodeData:mD isKeyFrame:keyFrame];
            
            [mD appendData:data];
            if (keyFrame && data.length < 100) {
                // 通过测试，I帧被分隔为两个NALU数据，前部分NALU数据应该是SPS、PPS等相关信息此时可以不处理，第二个NALU数据才是视频数据需要发送
            } else {
                if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(videoEncoder:videoData:isKeyFrame:)]) {
                    [encoder.delegate videoEncoder:encoder videoData:data isKeyFrame:keyFrame];
                }
            }
#warning 目前遇到奇怪的问题，会遇到一个很小的I帧。
            /**
             
             1、不发送NALU头，只发送纯视频数据，可以成功播放。
             2、发送NALU头+视频数据，播放失败。
             3、当I帧被分解为两个NALU数据包时，前面的NALU丢弃，接收端也可以正常播放
             4、通过测试，I帧被分隔为两个NALU数据，前部分NALU数据应该是SPS、PPS等相关信息此时可以不处理，第二个NALU数据才是视频数据需要发送
             */
            
//            const char bytes[] = "\x00\x00\x00\x01";
//            size_t length = sizeof(bytes) - 1;
//            NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
//            NSMutableData *mD = [NSMutableData dataWithData:byteHeader];
//            [mD appendData:data];
            
//            [audioMuData appendData:data];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
        
    }
    
}

- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps {
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:byteHeader];
    [fileHandle writeData:pps];
}

- (void)gotEncodeData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
    if (fileHandle != NULL) {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = sizeof(bytes) - 1;
        NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:byteHeader];
        [fileHandle writeData:data];
    }
}




@end
