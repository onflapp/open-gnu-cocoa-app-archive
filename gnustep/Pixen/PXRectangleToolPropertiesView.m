//
//  PXRectangleToolPropertiesView.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sat Mar 13 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXRectangleToolPropertiesView.h"


@implementation PXRectangleToolPropertiesView

- nibName
{
	return @"PXRectangleToolPropertiesView";
}

- (BOOL)shouldFill
{
	return [fillCheckbox state] == NSOnState ? YES : NO;
}

- fillColor
{
	return [fillColor color];
}

- (BOOL)shouldUseMainColorForFill
{
	return ([fillStyle selectedRow] == 0) ? YES : NO;
}

- (int)borderWidth
{
	return [borderWidth intValue];
}

@end
