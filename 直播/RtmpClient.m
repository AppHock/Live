//
//  RtmpClient.m
//  直播
//
//  Created by Hock on 2020/5/2.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "RtmpClient.h"

#define RTMP_HEAD_SIZE (sizeof(RTMPPacket) + RTMP_MAX_HEADER_SIZE)

#define SAVC(x) static const AVal av_##x = AVC(#x)

static const AVal av_setDataFrame = AVC("@setDataFrame");
SAVC(onMeteData);
SAVC(duration);
SAVC(width);
SAVC(height);
SAVC(videoCodecId);
SAVC(videoDataRate);
SAVC(frameRate);
SAVC(audioCodecId);
SAVC(audioDataRate);
SAVC(audioSampleRate);
SAVC(audioSampleSize);
SAVC(audioChannels);
SAVC(stereo);
SAVC(endoder);
//SAVC(av_stereo);
SAVC(fileSize);
SAVC(avc1);
SAVC(mp4a);

static const AVal av_SDKVersion = AVC("@meidaios 1.0.0");

@interface RtmpClient ()
{
    NSFileHandle *fileHandle;
    
    NSFileHandle *audioFileHandle;
}
@property (nonatomic, copy) NSString *rtmpUrl;
@property (nonatomic) dispatch_queue_t rtmpQueue;

@end


@implementation RtmpClient

- (dispatch_queue_t)rtmpQueue {
    if (!_rtmpQueue) {
        _rtmpQueue = dispatch_queue_create("rtmpQueue", NULL);
    }
    return _rtmpQueue;
}

- (instancetype)init
{
    self = [super init];
    if (self) {

//        NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"xiao peng_11.H264"];
//        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
//        [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
//        fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
        
//        NSString *v_file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"liu de hua.aac"];
//       [[NSFileManager defaultManager] removeItemAtPath:v_file error:nil];
//       [[NSFileManager defaultManager] createFileAtPath:v_file contents:nil attributes:nil];
//        audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:v_file];
    }
    return self;
}

+ (instancetype)getInstance {
    static RtmpClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RtmpClient alloc] init];
    });
    return instance;
}

- (RTMP *)getCurrentRtmp {
    return rtmp;
}

//- (double)start_time {
//    if (!_start_time) {
//        _start_time = [[NSDate date] timeIntervalSince1970] * 1000.0f;
//    }
//    return _start_time;
//}

- (BOOL)startRtmpConnect:(NSString *)url {
    if (!url.length) {
        return NO;
    }
    self.rtmpUrl = url;
    if (rtmp) {
        [self closeRtmpConnect];
    }
    
    rtmp = RTMP_Alloc();
    RTMP_Init(rtmp);
    rtmp->Link.timeout = 5;
    
    int ret = RTMP_SetupURL(rtmp, (char *)[_rtmpUrl cStringUsingEncoding:NSASCIIStringEncoding]);
    if (ret < 0) {
        NSLog(@"stopRtmpConnect fail");
        RTMP_Free(rtmp);
        return NO;
    }
    
    // 设置可写，即发布流，必须在连接前调用
    if (self.type == RTMP_SEND) {
        RTMP_EnableWrite(rtmp);
    }
    
    // 建立TCP连接，3次握手
    if (RTMP_Connect(rtmp, NULL) < 0) {
        NSLog(@"stopRtmpConnect fail");
        RTMP_Free(rtmp);
        return NO;
    }
    
    // 建立流连接
    if (RTMP_ConnectStream(rtmp, 0) == false) {
        NSLog(@"RTMP_ConnectStream fail");
        [self closeRtmpConnect];
        return NO;
        
    }
    
//    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
//    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
//    fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
//
//    _file_ptr = fopen((char *)[file cStringUsingEncoding:NSASCIIStringEncoding], "wb+");
    
    if (self.type == RTMP_SEND) {
        [self sendMetaData];
    } else if (self.type == RTMP_RECV) {
        [self GetH264AndAAC];
//        [self writeFile];
    }
    return YES;
}


#pragma mark --- private methods
- (void)writeFile {
    RTMP_SetBufferMS(rtmp, 3600*1000);
    int bufsize = 1024*1024*10;
    char *buf = (char *)malloc(bufsize);
    memset(buf, 0, bufsize);
    long countbufsize = 0;
    
    int nRead = 0;
    while ((nRead = RTMP_Read(rtmp, buf, bufsize))) {
        countbufsize += nRead;
        NSLog(@"Receive: nRead=%5dByte, Totol: %5.2fKb\n", nRead, countbufsize*10./1024);
//        [fileHandle writeData:[NSData dataWithBytes:buf length:nRead]];
    }
    
    if (buf) {
        free(buf);
    }
}

- (void)GetH264AndAAC {
    RTMPPacket packet = {0};
    // 第1-3个字节：FLV对应ascii码46、4c、56
    // 第4个字节  ：0x01:版本信息
    // 第5个字节  ：0x01（视频）、0x04（音频）、0x05（音视频）
    // 第6-9个字节：头部长度，一般=(3+1+1+4)9
//    static const char flvHeader[] = { 'F', 'L', 'V', 0x01,
//        0x00,                /* 0x04代表有音频, 0x01代表有视频 */
//        0x00, 0x00, 0x00, 0x09,
//        0x00, 0x00, 0x00, 0x00
//    };
    
    // 接收到的实际上是块(Chunk)，而不是消息(Message)，因为消息在网上传输的时候要分割成块.
    while (RTMP_IsConnected(rtmp) && RTMP_ReadPacket(rtmp, &packet)) {
        if (RTMPPacket_IsReady(&packet)) {
            if (!packet.m_nBodySize) {
                continue;
            }
            
            if (packet.m_packetType == RTMP_PACKET_TYPE_AUDIO ||
                packet.m_packetType == RTMP_PACKET_TYPE_VIDEO ||
                packet.m_packetType == RTMP_PACKET_TYPE_INFO) {
                [self handleMediaData:packet];
                RTMPPacket_Free(&packet);
                continue;
            }
            RTMP_ClientPacket(rtmp, &packet);
            RTMPPacket_Free(&packet);
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.recvDelegate && [self.recvDelegate respondsToSelector:@selector(didStopRtmpConnect)]) {
            [self.recvDelegate didStopRtmpConnect];
        }
        [self closeRtmpConnect];
         NSLog(@"结束录制");
    });
}

- (void)showAllUnit_8:(uint8_t *)buf length:(int)size {
    for (int i=0; i<size; i++) {
        NSLog(@"第%d个 0x%x", i, buf[i]);
    }
}

- (void)handleMediaData:(RTMPPacket)packet {
    uint8_t nalu_header[4] = {0x00, 0x00, 0x00, 0x01};
    if (packet.m_packetType == RTMP_PACKET_TYPE_VIDEO && RTMP_ClientPacket(rtmp, &packet)) {
        BOOL keyFrame = 0x17 == packet.m_body[0];
        BOOL sequence = 0x00 == packet.m_body[1];

        static BOOL isSendSpsAndPps = NO;
        // SPS、PPS sequence
        NSData *spsData, *ppsData;

        if (!isSendSpsAndPps && keyFrame && sequence) { //!isSendSpsAndPps  &&
            uint32_t offset = 10;
            uint32_t sps_num = packet.m_body[offset++] & 0x1f;
            if (sps_num > 23) {
                NSLog(@"www");
            }
            for (int i=0; i<sps_num; i++) {
                uint8_t ch0 = packet.m_body[offset] & 0xff;
                uint8_t ch1 = packet.m_body[offset + 1] & 0xff ;
                uint32_t sps_len = ((ch0 << 8) | ch1);
                offset += 2;

                NSMutableData *appData = [NSMutableData dataWithBytes:nalu_header length:4];
                [appData appendData:[NSData dataWithBytes:packet.m_body + offset length:sps_len]];
//                [fileHandle writeData:appData];

                spsData = [NSData dataWithBytes:packet.m_body + offset length:sps_len];
                NSLog(@"这是sps数据");
//                [self showAllUnit_8:[spsData bytes] length:spsData.length];
//                spsData = [NSData dataWithData:appData];

                offset += sps_len;
            }

            uint32_t pps_num = packet.m_body[offset++] & 0x1f;
            for (int i=0; i<pps_num; i++) {
                uint8_t ch0 = packet.m_body[offset] & 0xff;
                uint8_t ch1 = packet.m_body[offset + 1] & 0xff;
                uint32_t pps_len = ((ch0 << 8) | ch1);
                offset += 2;


                NSMutableData *appData = [NSMutableData dataWithBytes:nalu_header length:4];
                [appData appendData:[NSData dataWithBytes:packet.m_body + offset length:pps_len]];
//                [fileHandle writeData:appData];

                ppsData = [NSData dataWithBytes:packet.m_body + offset length:pps_len];
//                ppsData = [NSData dataWithData:appData];
                NSLog(@"这是pps数据");
//                [self showAllUnit_8:[ppsData bytes] length:ppsData.length];

                offset += pps_len;
            }
            if (self.recvDelegate && [self.recvDelegate respondsToSelector:@selector(didRtmpRecvSps:pps:)]) {
                isSendSpsAndPps = YES;
                [self.recvDelegate didRtmpRecvSps:spsData pps:ppsData];
            }
        } else {
            if (!isSendSpsAndPps || sequence) {
                return;
            }
            if (keyFrame) {
                if (packet.m_nBodySize < 1000) {
                    NSLog(@"遇到了一个奇怪的I帧，数据量很小");
//                    return;
                    [self showAllUnit_8:packet.m_body length:packet.m_nBodySize];
                }
            }

            uint32_t offset = 5;
            uint8_t ch0 = packet.m_body[offset] & 0xff;
            uint8_t ch1 = packet.m_body[offset + 1] & 0xff;
            uint8_t ch2 = packet.m_body[offset + 2] & 0xff;
            uint8_t ch3 = packet.m_body[offset + 3] & 0xff;
            uint32_t data_len = ((ch0 << 24) | (ch1 << 16) | (ch2 << 8) | ch3);
            offset += 4;

            NSMutableData *appData = [NSMutableData dataWithBytes:nalu_header length:4];
            [appData appendData:[NSData dataWithBytes:packet.m_body + offset length:data_len]];
//            [fileHandle writeData:appData];

            NSData *videoData = [NSData dataWithBytes:packet.m_body + offset length:data_len];

            // 添加0001头 可能需要把小端转大端
//            NSMutableData *mD = [NSMutableData dataWithBytes:nalu_header length:4];
//            [mD appendData:videoData];

            offset += data_len;
            if (self.recvDelegate && [self.recvDelegate respondsToSelector:@selector(didRtmpRecvVideoData:isKeyFrame:)]) {
                [self.recvDelegate didRtmpRecvVideoData:appData isKeyFrame:keyFrame];
            }
        }
    } else if (packet.m_packetType == RTMP_PACKET_TYPE_AUDIO) {
        BOOL sequence = 0x00 == packet.m_body[1];
//        [self showAllUnit_8:packet.m_body length:10];
        static uint32_t format, samplateRate, sampleDepth, typeChannel, object_type = 0, sample_frequency_index = 0, channels = 0;
        static uint32_t frame_length_flag, depend_on_core_coder, extension_flag;
        if (sequence) {
            format = (packet.m_body[0] & 0xf0) >> 4;
            samplateRate = (packet.m_body[0] & 0x0c) >> 2;
            sampleDepth  = (packet.m_body[0] & 0x02) >> 1;
            typeChannel         = packet.m_body[0] & 0x01;
            
//                    sequence = packet.m_body[1];
            if (format == 10) {
                uint8_t ch0 = packet.m_body[2];
                uint8_t ch1 = packet.m_body[3];
                uint16_t config = ((ch0 << 8) | ch1);
                object_type = (config & 0xF800) >> 11;
                sample_frequency_index = (config & 0x0780) >> 7;
                channels = (config & 0x078) >> 3;
                frame_length_flag = (config & 0x04) >> 2;
                depend_on_core_coder = (config & 0x02) >> 1;
                extension_flag = config & 0x01;
            } else if (format == 11) {
                typeChannel = 0;
                sampleDepth = 1;
                samplateRate = 4;
            }
            if (self.recvDelegate && [self.recvDelegate respondsToSelector:@selector(didRtmpRecvAudioHeaderData:)]) {
                [self.recvDelegate didRtmpRecvAudioHeaderData:[NSData dataWithBytes:packet.m_body length:packet.m_nBodySize]];
            }
        } else {
//            a.(data[0] & 0xf0) >> 4 : 音频编码类型
//            b.(data[0] & 0x0c) >> 2 : 音频采样率(0:5.5kHz,1:11KHz,2:22 kHz,3:44 kHz)
//            c.(data[0] & 0x02) >> 1 : 音频采样精度(0:8bits,1:16bits)
//            d.data[0] & 0x01        : //是否立体声(0:sndMono,1:sndStereo)
            
            // ADTS (7 bytes) + AAC data
//            [audioFileHandle writeData:[self getADTSWithPacketLength:packet.m_nBodySize-2]];
//            [audioFileHandle writeData:[NSData dataWithBytes:packet.m_body + 2 length:packet.m_nBodySize-2]];
            
            NSMutableData *mD = [NSMutableData data];
            [mD appendData:[self getADTSWithPacketLength:packet.m_nBodySize-2]];
            [mD appendData:[NSData dataWithBytes:packet.m_body + 2 length:packet.m_nBodySize-2]];
            
            if (self.recvDelegate && [self.recvDelegate respondsToSelector:@selector(didRtmpRecvAudioData:)]) {
                [self.recvDelegate didRtmpRecvAudioData:mD];
            }
            
//            [fileHandle writeData:[NSData dataWithBytes:adts length:7]];
//            [fileHandle writeData:[NSData dataWithBytes:packet.m_body + 2 length:packet.m_nBodySize-2]];
        }
    } else if (packet.m_packetType == RTMP_PACKET_TYPE_INFO) {
        
    }
}

- (NSData *)getADTSWithPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}


- (BOOL)closeRtmpConnect {
    [self closeFile];
    if (rtmp == NULL) {
        return YES;
    }
    if (rtmp) {
        RTMP_Close(rtmp);
        RTMP_Free(rtmp);
        rtmp = NULL;
        return YES;
    }
    return NO;
}

- (void)closeFile {
    if (audioFileHandle) {
        [audioFileHandle closeFile];
        audioFileHandle = NULL;
    }
    
    if (fileHandle) {
        [fileHandle closeFile];
        fileHandle = NULL;
    }
}

// 发送元数据
- (void)sendMetaData {
    RTMPPacket packet;
    
    char pbuf[2048], *pend = pbuf + sizeof(pbuf);
    
    //块流ID(通道)（2-63）
    packet.m_nChannel = 0x03;
    //块类型fmt(2bit)
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = RTMP_PACKET_TYPE_INFO;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = rtmp->m_stream_id;
    packet.m_hasAbsTimestamp = TRUE;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;
    
    char *enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
    enc = AMF_EncodeString(enc, pend, &av_onMeteData);
    
    *enc++ = AMF_OBJECT;
    
    enc = AMF_EncodeNamedNumber(enc, pend, &av_duration, 0.0);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_fileSize, 0.0);
    
    // videoSize
    enc = AMF_EncodeNamedNumber(enc, pend, &av_width, 480);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_height, 640);
    
    // video
    enc = AMF_EncodeNamedString(enc, pend, &av_videoCodecId, &av_avc1);
    // 480x640
    enc = AMF_EncodeNamedNumber(enc, pend, &av_videoDataRate, 480 * 640 / 1000.0f);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_frameRate, 10);
    
    // audio
    enc = AMF_EncodeNamedString(enc, pend, &av_audioCodecId, &av_mp4a);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audioDataRate, 96000);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audioSampleRate, 44100);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audioSampleSize, 16.0);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audioChannels, 1);
    enc = AMF_EncodeNamedBoolean(enc, pend, &av_stereo, NO);
    
    // SDK version
    enc = AMF_EncodeNamedString(enc, pend, &av_endoder, &av_SDKVersion);
    
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;
    
    _start_time = [[NSDate date] timeIntervalSince1970] * 1000.0f;
    
    packet.m_nBodySize = (uint32_t)(enc - packet.m_body);
    if (!RTMP_SendPacket(rtmp, &packet, false)) {
        return;
    }
}

- (NSInteger)sendPacket:(unsigned int)nPacketType data:(unsigned char*)data size:(NSInteger)size nTimestamp:(uint64_t)nTimestamp {
    NSInteger rtmpLength = size;
    RTMPPacket rtmp_pack;
    RTMPPacket_Reset(&rtmp_pack);
    RTMPPacket_Alloc(&rtmp_pack, (uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body, data, size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    
    if (rtmp) {
        rtmp_pack.m_nInfoField2 = rtmp->m_stream_id;
    }
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size != 4) {
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;
    
    NSInteger ret = [self rtmpPacketSend:&rtmp_pack];
    RTMPPacket_Free(&rtmp_pack);
    return ret;
}

- (NSInteger)rtmpPacketSend:(RTMPPacket *)packet {
    if (RTMP_IsConnected(rtmp)) {
        int success = RTMP_SendPacket(rtmp, packet, 0);
        return success;
    }
    return -1;
}

#pragma mark --- public methods
- (void)sendVideoSps:(NSData *)spsData pps:(NSData *)ppsData {
    unsigned char* sps = (unsigned char*)spsData.bytes;
    unsigned char* pps = (unsigned char*)ppsData.bytes;
    
    long sps_len = spsData.length;
    long pps_len = ppsData.length;
    
    dispatch_async(self.rtmpQueue, ^{
        if (rtmp != NULL) {
            unsigned char *body = NULL;
            NSInteger iIndex = 0;
            NSInteger rtmpLength = 1024;
            
            body = (unsigned char*)malloc(rtmpLength);
            memset(body, 0, rtmpLength);
            
            /***
             VideoTagHeader: 编码格式为AVC时，该header长度为5
             表示帧类型和CodecID,各占4个bit加一起是1个Byte
             1: 表示帧类型，当前是I帧(for AVC, A seekable frame)
             7: AVC  元数据当做I帧发送
             ***/
            body[iIndex++] = 0x17;
            
            // AVCPacketType: 0 = AVC sequence header,长度为1
            body[iIndex++] = 0x00;
            
            // CompositionTime: 0  ,长度为3
            body[iIndex++] = 0x00;
            body[iIndex++] = 0x00;
            body[iIndex++] = 0x00;
            
            /*** AVCDecoderConfigurationRecord:包含着H.264解码相关比较重要的sps,pps信息，在给AVC解码器送数据流之前一定要把sps和pps信息先发送，否则解码器不能正常work，而且在
            解码器stop之后再次start之前，如seek，快进快退状态切换等都需要重新发送一遍sps和pps信息。AVCDecoderConfigurationRecord在FLV文件中一般情况也是出现1次，也就是第一个
            video tag.
            ***/
            
            // 版本 = 1
            body[iIndex++] = 0x01;
            
            // AVCProfileIndication,1个字节长度:
            body[iIndex++] = sps[1];
            
            // profile_compatibility,1个字节长度
            body[iIndex++] = sps[2];
            
            // AVCLevelIndication , 1个字节长度
            body[iIndex++] = sps[3];
            body[iIndex++] = 0xff;
            
            // sps
            // 它的后5位表示SPS数目， 0xe1 = 1110 0001 后五位为 00001 = 1，表示只有1个SPS
            body[iIndex++] = 0xe1;
            
            // 表示SPS长度：2个字节 ，其存储的就是sps_len (策略：sps长度右移8位&0xff,然后sps长度&0xff)
            body[iIndex++] = (sps_len >> 8) & 0xff;
            body[iIndex++] = sps_len & 0xff;
            
            memcpy(&body[iIndex], sps, sps_len);
            iIndex += sps_len;
            
            // pps
            // 表示pps的数目，当前表示只有1个pps
            body[iIndex++] = 0x01;
            body[iIndex++] = (pps_len >> 8) & 0xff;
            // 和sps同理，表示pps的长度：占2个字节 ...
            body[iIndex++] = (pps_len) & 0xff;
            memcpy(&body[iIndex], pps, pps_len);
            iIndex += pps_len;
            
            [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
            free(body);
        }
    });
}

- (void)sendVideoData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
    dispatch_async(self.rtmpQueue, ^{
        if (rtmp) {
            /*start_time为开始直播时的时间戳*/
            uint32_t timeOffSet = [[NSDate date] timeIntervalSince1970] * 1000 - self.start_time;
            
            NSInteger i = 0;
            NSInteger rtmpLength = data.length + 9;
            unsigned char *body = (unsigned char*)malloc(rtmpLength);
            memset(body, 0, rtmpLength);
            
            if (isKeyFrame) {
                // 1:Iframe  7:AVC
                body[i++] = 0x17;
            } else {
                // 2:Pframe  7:AVC
                body[i++] = 0x27;
            }
            
            body[i++] = 0x01;
            body[i++] = 0x00;
            body[i++] = 0x00;
            body[i++] = 0x00;
            
            body[i++] = (data.length >> 24) & 0xff;
            body[i++] = (data.length >> 16) & 0xff;
            body[i++] = (data.length >>  8) & 0xff;
            
            body[i++] = (data.length) & 0xff;
            
//            [self showAllUnit_8:body length:9];
//            uint8_t ch0 = body[5] & 0xff;
//            uint8_t ch1 = body[6] & 0xff;
//            uint8_t ch2 = body[7] & 0xff;
//            uint8_t ch3 = body[8] & 0xff;
//            uint32_t data_len = ((ch0 << 24) | (ch1 << 16) | (ch2 << 8) | ch3);
//            NSLog(@"data_len ?=%d data.length", data_len == data.length);
            
            memcpy(&body[i], data.bytes, data.length);
            [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:timeOffSet];
            free(body);
        }
    });
}

- (void)sendAudioHeader:(NSData *)data {
    NSInteger audioLength = data.length;
    dispatch_async(self.rtmpQueue, ^{
        /*spec data长度,一般是2*/
        NSInteger rtmpLength = audioLength + 2;
        unsigned char *body = (unsigned char*)malloc(rtmpLength);
        memset(body, 0, rtmpLength);
        
        /**
         AE 00 + AAC RAW data
         4bit表示音频格式， 10表示AAC，所以用A来表示。  A: 表示发送的是AAC ； SountRate占2bit,此处是44100用3表示，转化为二进制位 11 ； SoundSize占1个bit,0表示8位，1表示16位，此处是16位用1表示，二进制表示为 1； SoundType占1个bit,0表示单声道，1表示立体声，此处是单声道用0表示，二进制表示为 0； 1110 = E
         AE to 二进制 A:1010(ACC) E:1110
         */
        body[0] = 0xAE;
        // 0x00:指该数据只是audio的配置信息
        // 0x01:指该数据是audio的音频数据
        body[1] = 0x00;
        /*spec_buf是AAC sequence header数据*/
        memcpy(&body[2], data.bytes, audioLength);
        [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
        free(body);
    });
}

- (void)sendAudioData:(NSData *)data {
    NSInteger audioLength = data.length;
    dispatch_async(self.rtmpQueue, ^{
        uint32_t timeOffSet = [[NSDate date] timeIntervalSince1970] * 1000 - self.start_time;
        /*spec data长度,一般是2*/
        NSInteger rtmpLength = audioLength+2;
        unsigned char *body = (unsigned char*)malloc(rtmpLength);
        memset(body, 0, rtmpLength);
        
        /**
         AE 01 + AAC RAW data
         在发送的音频数据头前面添加了body[0]、body[1]，则不需要调用sendAudioHeader
         */
        body[0] = 0xAE;
        body[1] = 0x01;
        
        
        memcpy(&body[2], data.bytes, audioLength);
        [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:timeOffSet];
        free(body);
    });
}


// 退出直播
- (void)exitLive {
    [self closeRtmpConnect];
}

@end
