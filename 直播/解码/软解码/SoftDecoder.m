//
//  SoftDecoder.m
//  直播
//
//  Created by Hock on 2020/5/13.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "SoftDecoder.h"
#import "libavcodec/avcodec.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"

@interface SoftDecoder ()
{
    //统领全局的基本结构体。主要用于处理封装格式（FLV/MKV/RMVB等）
    AVFormatContext *formatContext;
    //描述编解码器上下文的数据结构，包含了众多编解码器需要的参数信息
    AVCodecContext *videoCodec_ctx;
    //存储非压缩的数据（视频对应RGB/YUV像素数据，音频对应PCM采样数据）
    AVFrame *pFrame;
    //媒体流信息
    AVStream *_audioStream;
    AVCodecContext *audioCodec_ctx;
    //存储压缩数据（视频对应H.264等码流数据，音频对应AAC/MP3等码流数据）
    AVPacket *packet;
    AVPicture picture;
    AVPacket *_packet, _currentPacket;
    
    int videoStreamIndex;
    int audioStreamIndex;
    
    struct SwsContext *img_convert_ctx;
    int sourceWidth, sourceHeight;
    int outputWidth, outputHeight;
//    UIImage *currentImage;
    double duration;
    double currentTime;
    NSLock *audioPacketQueueLock;
    int16_t *_audioBuffer;
    int audioPacketQueueSize;
    NSMutableArray *audioPacketQueue;
    NSUInteger _audioBufferSize;
    BOOL _inBuffer;
    BOOL primed;
}
@end

@implementation SoftDecoder

@synthesize outputWidth, outputHeight;

#pragma mark --设置输出视频的宽度
- (void)setOutputWidth:(int)newValue
{
    if (outputWidth != newValue) {
        outputWidth = newValue;
        [self setupScaler];
    }
}
#pragma mark --设置输出视频的高度
- (void)setOutputHeight:(int)newValue
{
    if (outputHeight != newValue) {
        outputHeight = newValue;
        [self setupScaler];
    }
}

#pragma mark -- 获取当前图片
- (UIImage *)currentImage
{
    //取出解码后的帧数据
    if (!pFrame->data[0]) return nil;
    //转换成RGB
    [self convertFrameToRGB];
    //根据指定宽高裁剪出图片并返回
    return [self imageFromAVPicture:picture width:outputWidth height:outputHeight];
}

- (double)duration
{
    return (double)formatContext->duration / AV_TIME_BASE;
}
//当前播放的时间
- (double)currentTime
{
    AVRational timeBase = formatContext->streams[videoStreamIndex]->time_base;
    return packet->pts * (double)timeBase.num / timeBase.den;
}
#pragma mark --获取视频源的宽高
- (int)sourceWidth
{
    return videoCodec_ctx->width;
}

- (int)sourceHeight
{
    return videoCodec_ctx->height;
}

- (instancetype)initDecoderWithURL:(NSString *)url {
    // 初始化 avformatcontext上下文
    formatContext = NULL;
    // 注册所有编解码
    avcodec_register_all();
    // 初始化libavformat并注册所有复用器、解复用器和协议
    av_register_all();
    // 初始化网络
    avformat_network_init();
    
    // 设置RTMP选项
    AVDictionary *opts = 0;
    av_dict_set(&opts, "rtmp_transport", "tcp", 0);
    // 打开路径
    if (avformat_open_input(&formatContext, [url UTF8String], NULL, &opts) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto goError;
    }
    // 获取流信息
    if (avformat_find_stream_info(formatContext, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
    }
    
    // 获取音视频流index
    videoStreamIndex = -1;
    audioStreamIndex = -1;
    for (int i=0; i<formatContext->nb_streams; i++) {
        if (formatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoStreamIndex = i;
        }
        
        if (formatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStreamIndex = i;
        }
    }
    
    int frameIndex = 0;
    for (int i=0; i<2; i++) {
        AVCodecContext *codec_ctx;
        frameIndex = i==0 ? videoStreamIndex : audioStreamIndex;
        // 获得编解码上下文
        AVCodecParameters *codecParameters = formatContext->streams[frameIndex]->codecpar;
        // 获得编码格式
        AVCodec *pCodec = avcodec_find_decoder(codecParameters->codec_id);
        
        codec_ctx = avcodec_alloc_context3(pCodec);
        // 将AVCodecParameters解码器相关的信息，复制到AVCodecContext
        avcodec_parameters_to_context(codec_ctx, codecParameters);
        av_codec_set_pkt_timebase(codec_ctx, formatContext->streams[frameIndex]->time_base);
        // 打开音视频解码器
        if (avcodec_open2(codec_ctx, pCodec, NULL) < 0) {
            if (frameIndex == videoStreamIndex) {
                av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
            } else {
                NSLog(@"Could not open audio codec.");
            }
            return nil;
        }
        if (frameIndex == audioStreamIndex) {
            audioCodec_ctx = codec_ctx;
        } else {
            videoCodec_ctx = codec_ctx;
        }
    }
    // 初始化AVFrame（解码之后的原始数据视频YUV、RGB，音频PCM）
    pFrame = av_frame_alloc();
    
    outputWidth = videoCodec_ctx->width;
    self.outputHeight = videoCodec_ctx->height;
    return self;

goError:
    return nil;
}

#pragma mark -- 从视频流中读取下一帧
- (BOOL)stepFrame {
    packet = av_packet_alloc();
    int frameFinished = 0;
    while (!frameFinished) {
        int status = av_read_frame(formatContext, packet);
        if(status != 0) {
            break;
        }
        
        // 此时需要注意，avcodec_send_packet是一个异步函数。可能执行多次av_read_frame操作之后，才会开始回调avcodec_send_packet函数
        if (packet->stream_index == videoStreamIndex) {
            int sta = avcodec_send_packet(videoCodec_ctx, packet);
            // 发送之后，直接重置packet
            av_packet_unref(packet);
            if (sta != 0) {
                continue;
            }
            
            while (avcodec_receive_frame(videoCodec_ctx, pFrame) == 0) {
                NSLog(@"avcodec_receive_frame sucess pts = %lld !",pFrame->pts);
            }
        }
    }
    
    return frameFinished != 0;
}

#pragma mark -- 将YUV转换成RGB
- (void)convertFrameToRGB
{   //yuv420p to rgb24
    sws_scale(img_convert_ctx,
              (const uint8_t *const *)pFrame->data,
              pFrame->linesize,
              0,
              videoCodec_ctx->height,
              picture.data,
              picture.linesize);
}

#pragma mark -- 设置计数器
- (void)setupScaler
{
    // 释放旧图片和计数器
    avpicture_free(&picture);
    sws_freeContext(img_convert_ctx);
    
    // 创建一个AVPicture
    avpicture_alloc(&picture, AV_PIX_FMT_RGB24, outputWidth, outputHeight);
    
    // 设置计数器
    static int sws_flags =  SWS_FAST_BILINEAR;
    img_convert_ctx = sws_getContext(videoCodec_ctx->width,
                                     videoCodec_ctx->height,
                                     videoCodec_ctx->pix_fmt,
                                     outputWidth,
                                     outputHeight,
                                     AV_PIX_FMT_RGB24,
                                     sws_flags, NULL, NULL, NULL);
    
}

- (UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height
{
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       pict.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

- (void)dealloc
{
    // Free scaler
    sws_freeContext(img_convert_ctx);
    
    // Free RGB picture
    avpicture_free(&picture);
    
    // Free the packet that was allocated by av_read_frame
    av_free_packet(&packet);
    
    // Free the YUV frame
    av_free(pFrame);
    
    // Close the codec
    if (videoCodec_ctx) avcodec_close(videoCodec_ctx);
    
    // Close the video file
    if (formatContext) avformat_close_input(&formatContext);
    
//    [_audioController _stopAudio];
//    _audioController = nil;
    
    audioPacketQueue = nil;
    
    audioPacketQueueLock = nil;
}

@end

