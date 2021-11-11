//
//  VideoDecoder.m
//  直播
//
//  Created by Hock on 2020/5/3.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "VideoDecoder.h"
#import <QuartzCore/QuartzCore.h>

@interface VideoDecoder ()
{
    dispatch_queue_t mDecodeQueue;
    VTDecompressionSessionRef mDecodeSession;
    CMFormatDescriptionRef mFormatDescription;
    NSData *sps;
    long spsSize;
    NSData *pps;
    long ppsSize;
    
    uint8_t *mSPS;
    long mSPSSize;
    uint8_t *mPPS;
    long mPPSSize;
    
    // 输入
    NSInputStream *inputStream;
    uint8_t *inputBuffer;
    long inputSize;
    long inputMaxSize;
}

@property (nonatomic , strong) CADisplayLink *mDispalyLink;

@end

const uint8_t lyStartCode[4] = {0, 0, 0, 1};

@implementation VideoDecoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        mDecodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
            self.mDispalyLink.frameInterval = 2; // 默认是30FPS的帧率录制
        [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.mDispalyLink setPaused:YES];
    }
    return self;
}

//- (void)readPacket {
//    if (packetSize && packetBuffer) {
//        packetSize = 0;
//        free(packetBuffer);
//        packetBuffer = NULL;
//    }
//    if (inputSize < inputMaxSize && inputStream.hasBytesAvailable) {
//        inputSize += [inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
//    }
//    if (memcmp(inputBuffer, lyStartCode, 4) == 0) {
//        if (inputSize > 4) { // 除了开始码还有内容
//            uint8_t *pStart = inputBuffer + 4;
//            uint8_t *pEnd = inputBuffer + inputSize;
//            while (pStart != pEnd) { //这里使用一种简略的方式来获取这一帧的长度：通过查找下一个0x00000001来确定。
//                if(memcmp(pStart - 3, lyStartCode, 4) == 0) {
//                    packetSize = pStart - inputBuffer - 3;
//                    if (packetBuffer) {
//                        free(packetBuffer);
//                        packetBuffer = NULL;
//                    }
//                    packetBuffer = malloc(packetSize);
//                    memcpy(packetBuffer, inputBuffer, packetSize); //复制packet内容到新的缓冲区
//                    memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize); //把缓冲区前移
//                    inputSize -= packetSize;
//                    break;
//                }
//                else {
//                    ++pStart;
//                }
//            }
//        }
//    }
//}


//-(void)updateFrame {
//    if (inputStream){
//        dispatch_sync(mDecodeQueue, ^{
//            [self readPacket];
//            if(packetBuffer == NULL || packetSize == 0) {
//                [self onInputEnd];
//                return ;
//            }
//
//            // 在buffer的前面填入代表长度的int
//            CVPixelBufferRef pixelBuffer = NULL;
//            int nalType = packetBuffer[4] & 0x1F;
//            switch (nalType) {
//                case 0x05:
//                {
//                    uint32_t nalSize = (uint32_t)(packetSize - 4);
//                    uint32_t *pNalSize = (uint32_t *)packetBuffer;
//                    *pNalSize = CFSwapInt32HostToBig(nalSize);
//                    NSLog(@"Nal type is IDR frame");
//                    [self initVideoToolBox];
//                    pixelBuffer = [self decode];
//                }
//
//                    break;
//                case 0x07:
//                    NSLog(@"Nal type is SPS");
//                    mSPSSize = packetSize - 4;
//                    mSPS = malloc(mSPSSize);
//                    memcpy(mSPS, packetBuffer + 4, mSPSSize);
//                    break;
//                case 0x08:
//                    NSLog(@"Nal type is PPS");
//                    mPPSSize = packetSize - 4;
//                    mPPS = malloc(mPPSSize);
//                    memcpy(mPPS, packetBuffer + 4, mPPSSize);
//                    break;
//                default:
//                {
//                    uint32_t nalSize = (uint32_t)(packetSize - 4);
//                    uint32_t *pNalSize = (uint32_t *)packetBuffer;
//                    *pNalSize = CFSwapInt32HostToBig(nalSize);
//                    NSLog(@"Nal type is B/P frame");
//                    pixelBuffer = [self decode];
//                }
//                    break;
//            }
//
//            if(pixelBuffer) {
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.delegate didDecodePixelBuffer:pixelBuffer];
////                    [self.mOpenGLView displayPixelBuffer:pixelBuffer];
//                    CVPixelBufferRelease(pixelBuffer);
//                });
//            }
//            NSLog(@"Read Nalu size %ld", packetSize);
//        });
//    }
//}


#pragma mark --- public methods
- (void)startDecode {
    [self onInputStart];
    [self.mDispalyLink setPaused:NO];
}

- (void)sendSpsData:(NSData *)spsData ppsData:(NSData *)ppsData {

    sps = [NSData dataWithData:spsData];
    pps = [NSData dataWithData:ppsData];

    spsSize = spsData.length;
    ppsSize = ppsData.length;

//    NSData *sps_D = [[NSUserDefaults standardUserDefaults] objectForKey:@"KeySPS"];
//    NSData *pps_D = [[NSUserDefaults standardUserDefaults] objectForKey:@"KeyPPS"];
//
//    sps = [NSData dataWithData:sps_D];
//    pps = [NSData dataWithData:pps_D];
//
//    spsSize = sps_D.length;
//    ppsSize = pps_D.length;

//    spsSize = spsData.length;
//    sps = malloc(spsSize);
//    memcpy(sps, (uint8_t *)spsData.bytes, spsSize);
//
//    ppsSize = ppsData.length;
//    pps = malloc(ppsSize);
//    memcpy(pps, (uint8_t *)ppsData.bytes, ppsSize);
}

- (void)sendVideoData:(NSData *)videoData isKeyFrame:(BOOL)isKeyFrame {
    
    static BOOL isGetKeyFrame = NO;
    if (!isKeyFrame && !isGetKeyFrame) {
        return;
    }
    isGetKeyFrame = YES;


    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 在buffer的前面填入代表长度的int
        CVPixelBufferRef pixelBuffer = NULL;
        if (isKeyFrame) {
            if (![self initVideoToolBox]) {
                NSLog(@"创建DeCompressionSession失败");
                return;
            };
        }
    
        uint32_t packetSize = (uint32_t)videoData.length;
        uint8_t *packetBuffer = malloc(packetSize);
        memset(packetBuffer, 0, packetSize);
        memcpy(packetBuffer, (uint8_t *)videoData.bytes, packetSize);
        
        uint32_t nalSize = (uint32_t)(packetSize-4); // 21102633
        uint32_t *pNalSize = (uint32_t *)packetBuffer; // 151052799
        *pNalSize = CFSwapInt32HostToBig(nalSize); // 687882753
    
        pixelBuffer = [self decodeWithPbuffer:packetBuffer pSize:packetSize];
        // 必须释放，否则严重内存泄漏
        free(packetBuffer);
        if (pixelBuffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.delegate && [self.delegate respondsToSelector:@selector(didDecodePixelBuffer:)]) {
                    [self.delegate didDecodePixelBuffer:pixelBuffer];
                }
                CVPixelBufferRelease(pixelBuffer);
            });
        }
    });
//    dispatch_async(mDecodeQueue, ^{
////        if (packetBuffer && packetSize) {
////            free(packetBuffer);
////            packetBuffer = NULL;
////            packetSize = 0;
////        }
//    });
}

- (void)showAllUnit_8:(uint8_t *)buf length:(int)size {
    for (int i=0; i<size; i++) {
        NSLog(@"第%d个 0x%x", i, buf[i]);
    }
}


#pragma mark --- private methods
- (CVPixelBufferRef)decodeWithPbuffer:(uint8_t *)packetBuffer pSize:(int32_t)packetSize {
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (mDecodeSession) {
        CMBlockBufferRef blockBuffer = NULL;
        
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                             (void *)packetBuffer,
                                                             packetSize,
                                                             kCFAllocatorNull,
                                                             NULL,
                                                             0,
                                                             packetSize,
                                                             0, &blockBuffer);
        if (status == kCMBlockBufferNoErr) {
            
            CMSampleBufferRef sampleBuffer = NULL;
            const size_t sampleSizeArray[] = {packetSize};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,
                                               mFormatDescription,
                                               1,
                                               0,
                                               NULL,
                                               1,
                                               sampleSizeArray,
                                               &sampleBuffer);
            if (status == kCMBlockBufferNoErr && sampleBuffer) {
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags  flagOut = 0;
                
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(mDecodeSession,
                                                                    sampleBuffer,
                                                                    flags,
                                                                    &outputPixelBuffer,
                                                                    &flagOut);
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"IOS8VT: Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
                } else if(decodeStatus != noErr) {
                    NSLog(@"IOS8VT: decode failed status=%d", decodeStatus);
                }
                CFRelease(sampleBuffer);
            }
            CFRelease(blockBuffer);
        }
    }
    return outputPixelBuffer;
}

- (void)onInputStart {
    inputStream = [[NSInputStream alloc] initWithFileAtPath:[[NSBundle mainBundle] pathForResource:@"abc" ofType:@"h264"]];
    [inputStream open];
    inputSize = 0;
    inputMaxSize = 640 * 480 * 3 * 4;
    inputBuffer = malloc(inputMaxSize);
}

- (void)onInputEnd {
    [inputStream close];
    inputStream = nil;
    if (inputBuffer) {
        free(inputBuffer);
        inputBuffer = NULL;
    }
}


void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

- (BOOL)initVideoToolBox {
    if (!mDecodeSession) {
        const uint8_t *parameterSetPointers[2] = {(const uint8_t *)[sps bytes], (const uint8_t *)[pps bytes]};
        const size_t parameterSetSizes[2] = {spsSize, ppsSize};
        
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              2,
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              4,
                                                                              &mFormatDescription);
        
        
        if (status == noErr) {
            CFDictionaryRef atts = NULL;
            const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
            //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
            //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
            uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
            atts = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
            
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = NULL;
            
            // Set the Decoder Parameters
            
            status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                  mFormatDescription,
                                                  NULL,
                                                  atts,
                                                  &callBackRecord,
                                                  &mDecodeSession);
            
            if (VTDecompressionSessionCanAcceptFormatDescription(mDecodeSession, mFormatDescription)) {
                NSLog(@"YES");
            }
            
            VTSessionSetProperty(mDecodeSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
            VTSessionSetProperty(mFormatDescription, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);

            CFRelease(atts);
            return YES;
        } else {
            NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
            return NO;
        }
    } else {
        return YES;
    }
}

- (void)EndVideoToolBox {
    if (mDecodeSession) {
        VTDecompressionSessionInvalidate(mDecodeSession);
        CFRelease(mDecodeSession);
        mDecodeSession = NULL;
    }
    
    if (mFormatDescription) {
        CFRelease(mFormatDescription);
        mFormatDescription = NULL;
    }
    spsSize = ppsSize = 0;
}

@end
