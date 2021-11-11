//
//  SoftDecoder.h
//  直播
//
//  Created by Hock on 2020/5/13.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SoftDecoder : NSObject

// 上一次解码的图片作为 UIImage
@property (nonatomic, readonly) UIImage *currentImage;

// 源视频的宽高 */
@property (nonatomic, readonly) int sourceWidth, sourceHeight;

// 设置输出image的宽高
@property (nonatomic) int outputWidth, outputHeight;

// 视频当前的时间
@property (nonatomic, readonly) double currentTime;


- (instancetype)initDecoderWithURL:(NSString *)url;

//从视频流中读取下一帧，可能会出现找不到的情况，因为视频传输完成了
-(BOOL)stepFrame;


@end

NS_ASSUME_NONNULL_END
