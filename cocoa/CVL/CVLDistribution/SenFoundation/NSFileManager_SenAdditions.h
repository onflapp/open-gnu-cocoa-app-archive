//
//  NSFileManager_SenAdditions.h
//  CVL
//
//  Created by William Swats on Thu Oct 23 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSFileManager (SenAdditions)


- (BOOL) senFileExistsAtPath:(NSString *)aPath isDirectory:(BOOL *)isADirectory;
- (BOOL) senDirectoryExistsAtPath:(NSString *)aPath;
- (BOOL) senFileExistsAtPath:(NSString *)aPath;
- (BOOL) senLinkExistsAtPath:(NSString *)aPath;
- (BOOL) senFileOrLinkExistsAtPath:(NSString *)aPath;
- (BOOL) createAllDirectoriesAtPath:(NSString *)path attributes:(NSDictionary *)attributes;


@end
