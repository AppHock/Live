//
//  aac2pcm.m
//  直播
//
//  Created by Hock on 2021/11/14.
//  Copyright © 2021 Hock. All rights reserved.
//

#import "aac2pcm.h"
#import "NSFileHandle+Live.h"
#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#import <libavutil/avutil.h>
#import <libavdevice/avdevice.h>

@implementation aac2pcm

- (void)recordAudio {
    NSLog(@"%s", av_version_info());
    avdevice_register_all();
    AVFormatContext *pFormatCtx = avformat_alloc_context();
    AVDictionary* options1 = NULL;
    av_dict_set(&options1,"list_devices","true",0);
    AVInputFormat *iformat1 = av_find_input_format("avfoundation");
    printf("==AVFoundation Device Info===\n");
    avformat_open_input(&pFormatCtx,"",iformat1,&options1);
    printf("=============================\n");
    if(avformat_open_input(&pFormatCtx,"0",iformat1,NULL)!=0){
        printf("Couldn't open input stream.\n");
        return ;
    }
    
//    // 注册设备
//    av_register_all();
//    avcodec_register_all();
//    avdevice_register_all();
//
//    // 获取输入设备
    AVInputFormat *fmt = av_find_input_format("avfoundation");
    if (!fmt) {
        NSLog(@"获取输入设备失败");
//        return;
    }
    
    AVFormatContext *inputContext = avformat_alloc_context();
    AVDictionary* options = NULL;
    av_dict_set(&options, "video_size","960x54", 0);
    av_dict_set(&options, "r","30", 0);
    AVInputFormat *iformat = av_find_input_format("avfoundation");
    int ret = avformat_open_input(&inputContext,"0:0", iformat,&options);

    
    // 格式上下文，通过格式上下文操作设备
    AVFormatContext *ctx = NULL;
    // 打开设备
    ret = avformat_open_input(&ctx, ":0", fmt, NULL);
    if (ret < 0) {
        NSLog(@"打开设备失败");
        return;
    }
    
    
    // 文件路径
    NSFileHandle *fileHandle = [NSFileHandle getFileHandleWithFilePath:@""];
    if (!fileHandle) {
        NSLog(@"打开文件失败");
        // 关闭设备
        avformat_close_input(&ctx);
        return;
    }
    
    // 采集数据包大小
    int count = 50;
    
    // 数据包
    AVPacket *pkt = av_packet_alloc();
    while (count-- > 0) {
        ret = av_read_frame(ctx, pkt);
        if (ret == 0) {
            // 将数据写入文件中
            NSData *data = [NSData dataWithBytes:pkt->data length:pkt->size];
            [fileHandle writeData:data];
            
            // 释放packet内部资源
            av_packet_unref(pkt);
        } else if (ret == AVERROR(EAGAIN)) {
            // 资源临时不可用
            continue;
        } else {
            char errbuf[1024];
            av_strerror(ret, errbuf, sizeof(errbuf));
            NSLog(@"文件读取失败");
            break;
        }
    }
    NSLog(@"成功录制pcm文件");
    
    // 关闭文件
    [fileHandle closeFile];
    
    // 释放packet资源
    av_packet_free(&pkt);
    
    // 关闭设备
    avformat_close_input(&ctx);
}

- (void)start {
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(recordAudio) object:nil];
    [thread start];
}

@end
