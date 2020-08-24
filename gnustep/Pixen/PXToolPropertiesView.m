//
//  PXToolPropertiesView.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sat Mar 13 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXToolPropertiesView.h"


@implementation PXToolPropertiesView

- init
{
    self = [super init];
	[NSBundle loadNibNamed:[self nibName] owner:self];
	[self setFrame:[view frame]];
	[self addSubview:view];
    return self;
}

- nibName
{
	return @"PXBlankPropertiesView";
}

- (void)drawRect:(NSRect)rect {
    // Drawing code here.
}

- view
{
	return view;
}

@end
