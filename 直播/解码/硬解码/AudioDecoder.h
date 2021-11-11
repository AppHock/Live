//
//  AudioDecoder.h
//  直播
//
//  Created by Hock on 2020/5/3.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioDecoder : NSObject


- (void)sendAudioData:(NSData *)audioData;
- (BOOL)stopAudioDecode;

- (double)getCurrentTime;

- (int)start;

@end

NS_ASSUME_NONNULL_END
