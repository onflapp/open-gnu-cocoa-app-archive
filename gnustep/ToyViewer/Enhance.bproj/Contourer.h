//
//  Contourer.h
//  ToyViewer
//
//  Created on Tue Jun 04 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "Enhancer.h"

@interface Contourer : Enhancer
{
	float	bright;
	float	contrast;
}

+ (int)opcode;
+ (NSString *)oprString;

- (void)setupWith:(ToyView *)tv;
- (BOOL)isMono;
- (f_enhance)enhanceFunc;
- (t_weight)weightTabel:(int *)size;

- (id)waitingMessage;

- (void)setFactor:(float)fval andBright:(float)bval;
- (void)setContrast:(float)val;
- (void)prepareCommonValues:(int)num;

- (BOOL)makeNewPlane:(unsigned char **)newmap with:(commonInfo *)newinf;

@end
