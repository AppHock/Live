//
//  NSFileHandle+Live.m
//  直播
//
//  Created by Hock on 2021/11/14.
//  Copyright © 2021 Hock. All rights reserved.
//

#import "NSFileHandle+Live.h"

@implementation NSFileHandle (Live)

+ (instancetype)getFileHandleWithFilePath:(NSString *)filePath {
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:filePath];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    NSLog(@"文件路劲:%@", file);
    return fileHandle;
}

@end
