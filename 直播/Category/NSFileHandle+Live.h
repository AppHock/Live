//
//  NSFileHandle+Live.h
//  直播
//
//  Created by Hock on 2021/11/14.
//  Copyright © 2021 Hock. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSFileHandle (Live)

+ (instancetype)getFileHandleWithFilePath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
