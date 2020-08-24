/* NSString+SenPathComparison.h created by stephanec on Mon 13-Dec-1999 */
/* Copyright (c) 1997, Sen:te Ltd.  All rights reserved. */

#import <Foundation/Foundation.h>

@interface NSString(SenPathComparison)

- (BOOL) senIsParentOf:(NSString *)aPath immediately:(BOOL)isImmediateParent;
+ (NSString *) longestCommonPathOfPaths:(NSArray *)somePaths;

@end
