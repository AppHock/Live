//
//  AudioDecoder.m
//  直播
//
//  Created by Hock on 2020/5/3.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "AudioDecoder.h"
#import <AudioToolbox/AudioToolbox.h>
#include <pthread.h>

#define PRINTERROR(LABEL)    printf("%s err %4.4s %d\n", LABEL, (char *)&status, status)


const uint32_t CONST_BUFFER_COUNT = 3;
const uint32_t CONST_BUFFER_SIZE = 0x10000;

const unsigned int kNumAQBufs = 3;            // audio queue buffers 数量
const size_t kAQBufSize = 2 * 1024;        // buffer 的大小 单位是字节
const size_t kAQMaxPacketDescs = 512;        // ASPD的最大数量


struct MyData {
    AudioFileStreamID               audioFileStream;    // the audio file stream parser
    
    AudioQueueRef                   audioQueue;         // the audio queue
    AudioQueueBufferRef             audioQueueBuffer[kNumAQBufs];   // audio queue buffers audio
    
    AudioStreamPacketDescription    packetDescs[kAQMaxPacketDescs]; // packet descriptions for enqueuing
    
    unsigned int                    fillBufferIndex;    // the index of the audioQueueBuffer that is being filled
    size_t                          bytesFilled;        // how many bytes have been filled
    size_t                          packetsFilled;      // how many packets have been filled
    
    BOOL                            inuse[kNumAQBufs];  // flags to indicate that a buffer is still in use
    BOOL                            started;            // flag  to indicate that the queue has been started
    BOOL                            failed;             // flag  to indicate an error occurred
    
    pthread_mutex_t                 mutex;              // a mutex to protect the inuse flags
    pthread_cond_t                  cond;               // a condition varable for handling the inuse flags
    pthread_cond_t                  done;               // a condition varable for handling the inuse flags
};
typedef struct MyData MyData;

@implementation AudioDecoder
{
    AudioFileID audioFileID;
    AudioStreamBasicDescription audioStreamBasicDescrption;
    AudioStreamPacketDescription *audioStreamPacketDescription;
    
    AudioQueueRef audioQueue;
    AudioQueueBufferRef audioBuffers[CONST_BUFFER_COUNT];
    
    SInt64 readedPacket;
    u_int32_t packetNums;
    
    MyData *myData;
    uint32_t audioMaxBufSize;
    uint32_t currentBufSize;
    char *audioBuf;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

#pragma mark --- public methods
- (int)start {
   
    return 0;
}

- (void)sendAudioData:(NSData *)audioData {
    if (!myData) {
        myData = calloc(1, sizeof(MyData));
            
        audioMaxBufSize = 1000;
        currentBufSize = 0;
        audioBuf = malloc(audioMaxBufSize*sizeof(char));
        
        pthread_mutex_init(&myData->mutex, NULL);
        pthread_cond_init(&myData->cond, NULL);
        pthread_cond_init(&myData->done, NULL);
        
        /**
         第一个参数，一般为AudioFileStream的实例
         第二个参数，是歌曲信息解析的回调，一般传入一个回调函数
         第三个参数，是分离帧的回调，每解析出来一部分帧就会进行回调，也是传入一个回调函数
         第四个参数，是文件类型的提示，这个参数在文件信息不完整的时候尤其有用，可以给AudioFileStream一些提示去解析我们的音频文件
        */
        OSStatus status = AudioFileStreamOpen(myData, MyPropertyListenerProc, MyPacketsProc, kAudioFileAAC_ADTSType, &myData->audioFileStream);
        if (status) {
            PRINTERROR("AudioFileStreamOpen");
            return ;
        }
    }
    // 201 - 106
    if (currentBufSize + audioData.length >= audioMaxBufSize) {
        NSData *tempData = [audioData subdataWithRange:NSMakeRange(0, audioMaxBufSize-currentBufSize)];
        
        memcpy(audioBuf+currentBufSize, tempData.bytes, tempData.length);
        currentBufSize += tempData.length;
        
        OSStatus status = noErr;
        status = AudioFileStreamParseBytes(myData->audioFileStream, audioMaxBufSize, audioBuf, 0);
        if (status) { PRINTERROR("AudioFileStreamParseBytes"); }
        currentBufSize = 0;
        memset(audioBuf, 0, audioMaxBufSize);
        if (tempData.length != audioData.length) {
            NSData *restDada = [audioData subdataWithRange:NSMakeRange(tempData.length, audioData.length-tempData.length)];
            memcpy(audioBuf, restDada.bytes, restDada.length);
            currentBufSize += restDada.length;
        }
    } else {
        // 如果不超过最大buf，则继续拷贝数据
        memcpy(audioBuf+currentBufSize, audioData.bytes, audioData.length);
        currentBufSize += audioData.length;
    }
}

- (BOOL)stopAudioDecode {
    // enqueue last buffer
    MyEnqueueBuffer(myData);
    
    OSStatus status = noErr;
    printf("flushing\n");
    status = AudioQueueFlush(myData->audioQueue);
    if (status) { PRINTERROR("AudioQueueFlush"); return 1; }
    
    printf("stopping\n");
    status = AudioQueueStop(myData->audioQueue, false);
    if (status) { PRINTERROR("AudioQueueStop"); return 1; }
    
    printf("waiting until finished playing..\n");
    printf("start->lock\n");
    pthread_mutex_lock(&myData->mutex);
    pthread_cond_wait(&myData->done, &myData->mutex);
    printf("start->unlock\n");
    pthread_mutex_unlock(&myData->mutex);
    
    
    printf("done\n");
    
    // cleanup
    status = AudioFileStreamClose(myData->audioFileStream);
    status = AudioQueueDispose(myData->audioQueue, false);
    free(myData);
    free(audioBuf);
    
    currentBufSize = 0;
    return YES;
}

#pragma mark --- private methods
void MyPropertyListenerProc(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags) {
    MyData *myData = (MyData *)inClientData;
    OSStatus status = noErr;
    printf("found property '%c%c%c%d'\n",   (char)(inPropertyID>>24) & 255,
                                            (char)(inPropertyID>>16) & 255,
                                            (char)(inPropertyID>>8) & 255,
                                            (char)(inPropertyID & 255));
    
    switch (inPropertyID) {
        case kAudioFileStreamProperty_ReadyToProducePackets:
        {
            AudioStreamBasicDescription audioStreamBD;
            UInt32 audioStreamBDSize = sizeof(audioStreamBD);
            status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &audioStreamBDSize, &audioStreamBD);
            if (status) { PRINTERROR("get kAudioFileStreamProperty_DataFormat"); myData->failed = true; break; }
            
            status = AudioQueueNewOutput(&audioStreamBD, MyAudioQueueOutputCallback, myData, NULL, NULL, 0, &myData->audioQueue);
            if (status) { PRINTERROR("AudioQueueNewOutput"); myData->failed = true; break; }
            // allocate audio queue buffers
            for (unsigned int i = 0; i < kNumAQBufs; ++i) {
                status = AudioQueueAllocateBuffer(myData->audioQueue, kAQBufSize, &myData->audioQueueBuffer[i]);
                if (status) { PRINTERROR("AudioQueueAllocateBuffer"); myData->failed = true; break; }
            }
            
            // get the cookie size
            UInt32 cookieSize;
            Boolean writable;
            status = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
            if (status) { PRINTERROR("info kAudioFileStreamProperty_MagicCookieData"); break; }
            printf("cookieSize %d\n", (unsigned int)cookieSize);
            
            // get the cookie data
            void* cookieData = calloc(1, cookieSize);
            status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
            if (status) { PRINTERROR("get kAudioFileStreamProperty_MagicCookieData"); free(cookieData); break; }
            
            // set the cookie on the queue.
            status = AudioQueueSetProperty(myData->audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
            free(cookieData);
            if (status) { PRINTERROR("set kAudioQueueProperty_MagicCookie"); break; }
            
            // listen for kAudioQueueProperty_IsRunning
            status = AudioQueueAddPropertyListener(myData->audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueueIsRunningCallback, myData);
            if (status) { PRINTERROR("AudioQueueAddPropertyListener"); myData->failed = true; break; }
            
            break;

        }
            break;
            
        default:
            break;
    }
}

void MyPacketsProc(void                         *inClientData,
                   UInt32                       inNumberBytes,
                   UInt32                       inNumberPackets,
                   const void                   *inInputData,
                   AudioStreamPacketDescription *inPacketDescription) {
    // this is called by audio file stream when it finds packets of audio
    MyData* myData = (MyData*)inClientData;
    printf("got data.  bytes: %d  packets: %d\n", (unsigned int)inNumberBytes, (unsigned int)inNumberPackets);
    
    // the following code assumes we're streaming VBR data. for CBR data, you'd need another code branch here.
    
    for (int i = 0; i < inNumberPackets; ++i) {
        SInt64 packetOffset = inPacketDescription[i].mStartOffset;
        SInt64 packetSize   = inPacketDescription[i].mDataByteSize;
        
        // if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
        size_t bufSpaceRemaining = kAQBufSize - myData->bytesFilled;
        if (bufSpaceRemaining < packetSize) {
            MyEnqueueBuffer(myData);
            WaitForFreeBuffer(myData);
        }
        
        // copy data to the audio queue buffer
        AudioQueueBufferRef fillBuf = myData->audioQueueBuffer[myData->fillBufferIndex];
        memcpy((char*)fillBuf->mAudioData + myData->bytesFilled, (const char*)inInputData + packetOffset, packetSize);
        // fill out packet description
        myData->packetDescs[myData->packetsFilled] = inPacketDescription[i];
        myData->packetDescs[myData->packetsFilled].mStartOffset = myData->bytesFilled;
        // keep track of bytes filled and packets filled
        myData->bytesFilled += packetSize;
        myData->packetsFilled += 1;
        
        // if that was the last free packet description, then enqueue the buffer.
        size_t packetsDescsRemaining = kAQMaxPacketDescs - myData->packetsFilled;
        if (packetsDescsRemaining == 0) {
            MyEnqueueBuffer(myData);
            WaitForFreeBuffer(myData);
        }
    }
    
}

OSStatus StartQueueIfNeeded(MyData* myData)
{
    OSStatus status = noErr;
    if (!myData->started) {        // start the queue if it has not been started already
        status = AudioQueueStart(myData->audioQueue, NULL);
        if (status) { PRINTERROR("AudioQueueStart"); myData->failed = true; return status; }
        myData->started = true;
        printf("started\n");
    }
    return status;
}

OSStatus MyEnqueueBuffer(MyData *myData) {
    OSStatus status = noErr;
       myData->inuse[myData->fillBufferIndex] = true;        // set in use flag
       
       // enqueue buffer
       AudioQueueBufferRef fillBuf = myData->audioQueueBuffer[myData->fillBufferIndex];
       fillBuf->mAudioDataByteSize = (UInt32)myData->bytesFilled;
       status = AudioQueueEnqueueBuffer(myData->audioQueue, fillBuf, (UInt32)myData->packetsFilled, myData->packetDescs);
       if (status) { PRINTERROR("AudioQueueEnqueueBuffer"); myData->failed = true; return status; }
       
       StartQueueIfNeeded(myData);
       
    return status;
}

void MyAudioQueueOutputCallback(void                *inClientData,
                                AudioQueueRef       inAQ,
                                AudioQueueBufferRef inBuffer) {
    MyData *myData = (MyData *)inClientData;
    unsigned int bufIndex = MyFindQueueBuffer(myData, inBuffer);
    if (bufIndex != -1) {
        printf("MyAudioQueueOutputCallback -> lock\n");
        pthread_mutex_lock(&myData->mutex);
        myData->inuse[bufIndex] = false;
        pthread_cond_signal(&myData->cond);
        printf("MyAudioQueueOutputCallback->unlock\n");
        pthread_mutex_unlock(&myData->mutex);
    }
}

void WaitForFreeBuffer(MyData* myData)
{
    // go to next buffer
    if (++myData->fillBufferIndex >= kNumAQBufs) myData->fillBufferIndex = 0;
    myData->bytesFilled = 0;        // reset bytes filled
    myData->packetsFilled = 0;        // reset packets filled
    
    // wait until next buffer is not in use
    printf("WaitForFreeBuffer->lock\n");
    pthread_mutex_lock(&myData->mutex);
    while (myData->inuse[myData->fillBufferIndex]) {
        printf("... WAITING ...\n");
        pthread_cond_wait(&myData->cond, &myData->mutex);
    }
    pthread_mutex_unlock(&myData->mutex);
    printf("WaitForFreeBuffer->unlock\n");
}


int MyFindQueueBuffer(MyData *myData, AudioQueueBufferRef inBuffer) {
    for (unsigned int i=0; i<kNumAQBufs; ++i) {
        if (inBuffer == myData->audioQueueBuffer[i]) {
            return i;
        }
    }
    return -1;
}

void MyAudioQueueIsRunningCallback(        void*                    inClientData,
                                   AudioQueueRef            inAQ,
                                   AudioQueuePropertyID    inID)
{
    MyData* myData = (MyData*)inClientData;
    
    UInt32 running;
    UInt32 size;
    OSStatus status = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &running, &size);
    if (status) { PRINTERROR("get kAudioQueueProperty_IsRunning"); return; }
    if (!running) {
        printf("MyAudioQueueIsRunningCallback->lock\n");
        pthread_mutex_lock(&myData->mutex);
        pthread_cond_signal(&myData->done);
        printf("MyAudioQueueIsRunningCallback->unlock\n");
        pthread_mutex_unlock(&myData->mutex);
    }
}


- (void)customAudioConfig {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"aac"];
    // 打开音频文件
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID);
    
    if (status != noErr) {
        NSLog(@"打开文件失败");
        return;
    }
    
    uint32_t size = sizeof(AudioStreamBasicDescription);
    // 获得音频文件属性
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioStreamBasicDescrption);
    NSAssert(status == noErr, @"error");
    
    status = AudioQueueNewOutput(&audioStreamBasicDescrption, bufferReady, (__bridge void * _Nullable)(self), NULL, NULL, 0, &audioQueue);
    
    if (audioStreamBasicDescrption.mBytesPerPacket == 0 || audioStreamBasicDescrption.mFramesPerPacket == 0) {
        uint32_t maxSize;
        size = sizeof(maxSize);
        
        AudioFileGetProperty(audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &maxSize);
        
        if (maxSize > CONST_BUFFER_SIZE) {
            maxSize = CONST_BUFFER_SIZE;
        }
        
        packetNums = CONST_BUFFER_SIZE / maxSize;
        audioStreamPacketDescription = malloc(sizeof(AudioStreamPacketDescription) * packetNums);
    } else {
        packetNums = CONST_BUFFER_SIZE / audioStreamBasicDescrption.mBytesPerPacket;
    }
}

void bufferReady(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef buffer){
    NSLog(@"refresh buffer");
    AudioDecoder *player = (__bridge AudioDecoder *)inUserData;
    if (!player) {
        NSLog(@"player nil");
        return ;
    }
    if ([player fillBuffer:buffer]) {
        NSLog(@"play end");
    }
    
}

- (void)play {
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0); // Sets a playback audio queue parameter value.
    AudioQueueStart(audioQueue, NULL); // Begins playing or recording audio.
}

- (bool)fillBuffer:(AudioQueueBufferRef)buffer {
    bool full = NO;
    uint32_t bytes = 0, packets = (uint32_t)packetNums;
    OSStatus status = AudioFileReadPackets(audioFileID, NO, &bytes, audioStreamPacketDescription, readedPacket, &packets, buffer->mAudioData); // Reads packets of audio data from an audio file.
    
    NSAssert(status == noErr, ([NSString stringWithFormat:@"error status %d", status]) );
    if (packets > 0) {
        buffer->mAudioDataByteSize = bytes;
        AudioQueueEnqueueBuffer(audioQueue, buffer, packets, audioStreamPacketDescription);
        readedPacket += packets;
    }
    else {
        AudioQueueStop(audioQueue, NO);
        full = YES;
    }
    
    return full;
}

- (double)getCurrentTime {
    Float64 timeInterval = 0.0;
    if (audioQueue) {
        AudioQueueTimelineRef timeLine;
        AudioTimeStamp timeStamp;
        OSStatus status = AudioQueueCreateTimeline(audioQueue, &timeLine); // Creates a timeline object for an audio queue.
        if(status == noErr)
        {
            AudioQueueGetCurrentTime(audioQueue, timeLine, &timeStamp, NULL); // Gets the current audio queue time.
            timeInterval = timeStamp.mSampleTime * 1000000 / audioStreamBasicDescrption.mSampleRate; // The number of sample frames per second of the data in the stream.
        }
    }
    return timeInterval;
}


@end
