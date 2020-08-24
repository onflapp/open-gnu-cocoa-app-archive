//
//  Blurrer.h
//  ToyViewer
//
//  Created on Sat Jun 08 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "Enhancer.h"

@interface Blurrer : Enhancer {
	int	radius;
	char	*tablep;
}

+ (int)opcode;
+ (NSString *)oprString;
- (id)waitingMessage;

- (id)init;
- (void)dealloc;
- (void)setFactor:(float)value;
- (BOOL)isLinearFilter;
- (f_enhance)enhanceFunc;
- (f_nonlinear)nonlinearFunc;
- (t_weight)weightTabel:(int *)size;
- (void)prepareCommonValues:(int)num;

@end
