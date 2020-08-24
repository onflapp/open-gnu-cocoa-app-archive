//
//  PXScaleAlgorithm.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Thu Jun 10 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXScaleAlgorithm.h"
#import "PXCanvas.h"

@implementation PXScaleAlgorithm

+ algorithm
{
	return [[[self alloc] init] autorelease];
}

- (NSString *)name
{
	return [self nibName];
}

- (NSString *)nibName
{
	return nil;
}

- (NSString *)algorithmInfo
{
	return @"No information is available on this algorithm.";
}

- (BOOL)hasParameterView
{
	return NO;
}

- (NSView *)parameterView
{
	if ([self nibName] != nil) {
		if (![NSBundle loadNibNamed:[self nibName] owner:self]) {
			[[NSException exceptionWithName:@"PXScaleAlgorithmInvalidNibException" reason:[NSString stringWithFormat:@"-[%@ nibName] gave an invalid nib name (%@)", [[self class] description], [self nibName]] userInfo:[NSDictionary dictionary]] raise];
		}
	}
	if (parameterView == nil) {
		return [[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
	}
	return parameterView;
}

- (BOOL)canScaleCanvas:canvas toSize:(NSSize)size
{
	return NO;
}

- (void)scaleCanvas:canvas toSize:(NSSize)size
{
}

@end
