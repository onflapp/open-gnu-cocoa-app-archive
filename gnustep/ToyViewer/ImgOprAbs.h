//
//  ImgOprAbs.h
//  ToyViewer
//
//  Created by ogihara on Thu Nov 15 2001.
//  Copyright (c) 2001 Takeshi Ogihara. All rights reserved.
//

#import  <Foundation/NSObject.h>
#import  "common.h"

#define  ck_EPS		1
#define  ck_CMYK	2
#define  ck_MONO	4


@interface ImgOprAbs : NSObject

/* Virtual */
+ (int)opcode;
+ (NSString *)oprString;

+ (BOOL)check:(int)check info:(const commonInfo *)cinf filename:(NSString *)fn;

@end
