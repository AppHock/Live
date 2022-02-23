//
//  ViewController.m
//  直播
//
//  Created by Hock on 2020/4/25.
//  Copyright © 2020 Hock. All rights reserved.
//

#import "ViewController.h"
#import "VideoManager.h"
#import "VideoEncoder.h"
#import "AudioEncoder.h"
#import "VideoDecoder.h"
#import "AudioDecoder.h"
#import "RtmpClient.h"
#import "LYOpenGLView.h"
#import "SoftDecoder.h"
#import <MBProgressHUD/MBProgressHUD.h>

#define liveUrl @"rtmp://169.254.206.178:1990/liveApp/abc"
//#define liveUrl @"http://ebook.tcloudfamily.com/questionvideo/e7ba2d09f79d467b894020a336f4d407_Ep.01_x264.mp4?OSSAccessKeyId=LTAI4Fva3tusCcgecVq1gPsQ&Expires=1594370845&Signature=nic2kEjz5jj8QLCCTgykLFy3Wb0%3D"


@interface ViewController () <VideoCaptureOutputDelegate, VideoHWH264EncoderDelegate, AudioHWACCEncoderDelegate, RtmpClientRecvDelegate, VideoDecodeDelegate>
{
    dispatch_queue_t encoderQueue;
    dispatch_queue_t decoderVideoQueue;
    dispatch_queue_t decoderAudioQueue;
    // 是否是直播状态
    BOOL isLiveStatus;
    
    CMFormatDescriptionRef formatDescription;
}
//@property (nonatomic, strong) LFLiveSession *session;

@property (nonatomic, strong) VideoEncoder *vEncoder;
@property (nonatomic, strong) AudioEncoder *aEncoder;

@property (nonatomic, strong) VideoDecoder *vDecoder;
@property (nonatomic, strong) AudioDecoder *aDecoder;

/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;
/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;

//@property (nonatomic , strong) OpenGLView *openGLView;

@property (nonatomic , strong) LYOpenGLView *openGLView;

@property (nonatomic , strong) SoftDecoder *softDecoder;

@property (nonatomic , strong) UIImageView *videoPlayer;

@property (nonatomic, strong) NSString *rtmpUrl;
@property (nonatomic, strong) UITextField *tf;
@property (nonatomic, strong) UILabel *IPLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.rtmpUrl = @"rtmp://169.254.206.178:1990/liveApp/abc";
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://www.baidu.com/?tn=baiduerr"];
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url];
        [dataTask resume];
    });
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *startLive = [UIButton buttonWithType:UIButtonTypeCustom];
    startLive.frame = CGRectMake(20, 100, 100, 50);
    [startLive setTitle:@"开始直播" forState:UIControlStateNormal];
    [startLive setTitle:@"关闭直播" forState:UIControlStateSelected];
    [startLive setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [startLive addTarget:self action:@selector(liveOnAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startLive];
    
    UIButton *watchLive = [UIButton buttonWithType:UIButtonTypeCustom];
    watchLive.frame = CGRectMake(20, 300, 100, 50);
    [watchLive setTitle:@"观看直播" forState:UIControlStateNormal];
    [watchLive setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [watchLive addTarget:self action:@selector(watchLive:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:watchLive];
    
    UIButton *changeCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    changeCamera.frame = CGRectMake(300, 30, 100, 50);
    [changeCamera setTitle:@"切换" forState:UIControlStateNormal];
    [changeCamera setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [changeCamera addTarget:self action:@selector(changeCameraAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:changeCamera];
    
    _vEncoder = [[VideoEncoder alloc] init];
    _vEncoder.saveFileName = @"cheng";
    _vEncoder.delegate = self;
    
    _aEncoder = [[AudioEncoder alloc] init];
    _aEncoder.saveFileName = @"peng";
    _aEncoder.delegate = self;
    
    _vDecoder = [[VideoDecoder alloc] init];
    _vDecoder.delegate = self;
    
    _aDecoder = [[AudioDecoder alloc] init];
        
    encoderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    decoderAudioQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    decoderVideoQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    [RtmpClient getInstance].recvDelegate = self;
    
    self.tf = [[UITextField alloc] initWithFrame:CGRectMake(50, 400, 200, 30)];
    [self.view addSubview:self.tf];
    self.tf.keyboardType = UIKeyboardTypeNumberPad;
    self.tf.borderStyle = UITextBorderStyleLine;
    self.tf.placeholder = @"请输入服务器IP地址";
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(280, 400, 50, 30)];
    [button setTitle:@"确定" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.blueColor forState:UIControlStateNormal];
    [button addTarget:self action:@selector(confirm) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    self.IPLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 450, self.view.frame.size.width, 30)];
    self.IPLabel.textColor = UIColor.redColor;
    self.IPLabel.textAlignment = NSTextAlignmentCenter;
}

- (void)confirm {
    [self.view endEditing:YES];
    self.rtmpUrl = [NSString stringWithFormat:@"rtmp://%@:1990/liveApp/abc", self.tf.text];
    self.tf.text = @"";
    self.IPLabel.text = [NSString stringWithFormat:@"当前IP地址【%@】", self.tf.text];
}

- (void)watchLive:(UIButton *)button {
//    if (1) {
//        _videoPlayer = [[UIImageView alloc] initWithFrame:CGRectMake(0, 30, self.view.frame.size.width, 400)];
//        _softDecoder = [[SoftDecoder alloc] initDecoderWithURL:self.rtmpUrl];
//        _softDecoder.outputWidth = _videoPlayer.frame.size.width/2;
//        _softDecoder.outputHeight = _videoPlayer.frame.size.height/2;
//                //使用一个定时器来不断播放视频帧
//        [self displayNextFrame];
//        return;
//    }
    
    [RtmpClient getInstance].type = RTMP_RECV;
    self.openGLView.hidden = NO;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"[NSThread isMainThread] = %d", [NSThread isMainThread]);
        if (![[RtmpClient getInstance] startRtmpConnect:self.rtmpUrl]) {
            NSLog(@"直播间连接失败");
        } else {
            NSLog(@"主播下线");
        }
    });
}

-(void)displayNextFrame
{
    NSLog(@"%@", [NSThread currentThread]);
    [self performSelector:@selector(displayNextFrame) withObject:nil afterDelay:1.0/24];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (![_softDecoder stepFrame]) {
        //        [_softDecoder closeAudio];
            
            return;
        }
    });
    
    _videoPlayer.image = _softDecoder.currentImage;
}

- (void)liveOnAction:(UIButton *)button {
    NSLog(@"点击了");
    if (![VideoManager sharedInstance].superview) {
        [VideoManager sharedInstance].superview = self.view;
        [VideoManager sharedInstance].delegate = self;
    }

    button.selected = !button.selected;
    if (button.selected) {
        if ([[RtmpClient getInstance] startRtmpConnect:self.rtmpUrl]) {
            isLiveStatus = YES;
            [_vEncoder startVideoToolBox];
            [[VideoManager sharedInstance] startRunning];
            self.relativeTimestamps = 0;
        }
    } else {
        isLiveStatus = NO;
        [[VideoManager sharedInstance] stopRunning];
        [_vEncoder endVideoToolBox];
        [_aEncoder endAudioToolBox];
    }
}

- (void)changeCameraAction {
    [[RtmpClient getInstance] exitLive];
//    [self.session stopLive];
//    [[VideoManager sharedInstance] changeCarema];
}

#pragma mark --- VideoCaptureOutputDelegate
- (void)outputSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(AVCaptureMediaType)type {
    if (type == AVCaptureMediaVideo) {
//        dispatch_sync(encoderQueue, ^{
            [_vEncoder encode:sampleBuffer];
//        });
        
    } else if (type == AVCaptureMediaAudio) {
//        dispatch_sync(encoderQueue, ^{
            [_aEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(NSData * _Nonnull encodedData, NSError * _Nonnull error) {
                
            }];
//        });
    }
}

#pragma mark --- VideoHWH264EncoderDelegate
- (void)videoEncoder:(VideoEncoder *)encoder sps:(NSData *)spsData pps:(NSData *)ppsData {
    if (isLiveStatus) {
        [[RtmpClient getInstance] sendVideoSps:spsData pps:ppsData];
    }
}

- (void)videoEncoder:(VideoEncoder *)encoder videoData:(NSData *)videoData isKeyFrame:(BOOL)isKeyFrame {
    if (isLiveStatus) {
        [[RtmpClient getInstance] sendVideoData:videoData isKeyFrame:isKeyFrame];
    }
}

#pragma mark --- AudioHWACCEncoderDelegate
- (void)audioEncoder:(AudioEncoder *)encoder audioHeader:(NSData *)headerData {
    if (isLiveStatus) {
        [[RtmpClient getInstance] sendAudioHeader:headerData];
    }
}

- (void)audioEncoder:(AudioEncoder *)encoder audioData:(NSData *)dataData {
    if (isLiveStatus) {
        [[RtmpClient getInstance] sendAudioData:dataData];
    }
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

#pragma mark --- RtmpClientRecvDelegate
- (void)didRtmpRecvSps:(NSData *)sps pps:(NSData *)pps {
    dispatch_async(decoderVideoQueue, ^{
        [_vDecoder sendSpsData:sps ppsData:pps];
    });
}

- (void)didRtmpRecvVideoData:(NSData *)videoData isKeyFrame:(BOOL)isKeyFrame {
    dispatch_async(decoderVideoQueue, ^{
        [_vDecoder sendVideoData:videoData isKeyFrame:isKeyFrame];
    });
}

- (void)didRtmpRecvAudioHeaderData:(NSData *)audioHeaderData {
    [_aDecoder start];
}

- (void)didRtmpRecvAudioData:(NSData *)audioData {    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_aDecoder sendAudioData:audioData];
    });
    dispatch_async(decoderAudioQueue, ^{
        
    });
}

- (void)didStopRtmpConnect {
    dispatch_async(decoderAudioQueue, ^{
        [_aDecoder stopAudioDecode];
    });
}

#pragma mark --- VideoDecodeDelegate
- (void)didDecodePixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self.openGLView displayPixelBuffer:pixelBuffer];
}

#pragma mark --- private methods

- (void)sendBuffer:(uint64_t)timestamp {
    
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (void)dismissVc {

}


#pragma mark --- setter and getter
- (LYOpenGLView *)openGLView {
    if (!_openGLView) {
        CGFloat width = self.view.frame.size.width;
        CGFloat height = width * 640 / 480;
        _openGLView = [[LYOpenGLView alloc] initWithFrame:CGRectMake(0, 100, width, height)];
        [self.view addSubview:_openGLView];
        [_openGLView setupGL];
    }
    return _openGLView;
}

@end
