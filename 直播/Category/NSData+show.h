//
//  NSData+show.h
//  直播
//
//  Created by Hock on 2020/5/6.
//  Copyright © 2020 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (show)

- (void)showBytes:(int32_t)length;

+ (NSData *)getADTSWithPacketLength:(NSUInteger)packetLength;

@end

NS_ASSUME_NONNULL_END
