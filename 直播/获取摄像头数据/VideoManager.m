//
//  VideoManager.m
//  直播
//
//  Created by Hock on 2020/4/27.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "VideoManager.h"


@interface VideoManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    dispatch_queue_t captureQueue;
}


@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) AVCaptureDeviceInput *currentVideoDeviceInput;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) AVCaptureConnection *videoConnection;


@end

@implementation VideoManager

+ (instancetype)sharedInstance {
    static  VideoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[VideoManager alloc] init];
    });
    return sharedInstance;
}

- (void)startRunning {
    if (!self.superview) {
        return;
    }
    
    if (!captureQueue) {
        captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    
    if (_captureSession && !_captureSession.running) {
        [_captureSession startRunning];
        return;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    if ([_captureSession canAddInput:videoDeviceInput]) {
        [_captureSession addInput:videoDeviceInput];
    }
    _currentVideoDeviceInput = videoDeviceInput;
    
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    if ([_captureSession canAddInput:audioDeviceInput]) {
        [_captureSession addInput:audioDeviceInput];
    }
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 设置视频输出格式为  yuv420
    [videoOutput setVideoSettings:@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
    [videoOutput setSampleBufferDelegate:self queue:captureQueue];
    if ([_captureSession canAddOutput:videoOutput]) {
        [_captureSession addOutput:videoOutput];
    }
    [videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    
//    [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:captureQueue];
    if ([_captureSession canAddOutput:audioOutput]) {
        [_captureSession addOutput:audioOutput];
    }
    
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    previewLayer.frame = [UIScreen mainScreen].bounds;
    [self.superview.layer addSublayer:previewLayer];
    
    _videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];

    [_captureSession startRunning];
}

- (void)changeCarema {
    if (!_captureSession || !_captureSession.running) {
        return;
    }
    AVCaptureDevicePosition curPosition = _currentVideoDeviceInput.device.position;
    
    AVCaptureDevicePosition newPosition = curPosition == AVCaptureDevicePositionFront ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    
    NSArray *devices = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:newPosition].devices;
    
    AVCaptureDevice *newVideoDevide;
    for (AVCaptureDevice *device in devices) {
        if (device.position == newPosition) {
            newVideoDevide = device;
        }
    }
    
    [_captureSession removeInput:_currentVideoDeviceInput];
    
    AVCaptureDeviceInput *newDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevide error:nil];
    if ([_captureSession canAddInput:newDeviceInput]) {
        [_captureSession addInput:newDeviceInput];
    }
    _currentVideoDeviceInput = newDeviceInput;
}
- (void)stopRunning {
    [_captureSession stopRunning];
    [_previewLayer removeFromSuperlayer];
}

#pragma mark --- AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    AVCaptureMediaType mediaType;
    if (_videoConnection == connection) {
        mediaType = AVCaptureMediaVideo;
    } else {
        mediaType = AVCaptureMediaAudio;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(outputSampleBuffer:mediaType:)]) {
        [self.delegate outputSampleBuffer:sampleBuffer mediaType:mediaType];
    }
    
}

@end
