//
//  PXRectangleToolPropertiesView.h
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sat Mar 13 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "PXToolPropertiesView.h"


@interface PXRectangleToolPropertiesView : PXToolPropertiesView
{
	IBOutlet id fillColor;
	IBOutlet id fillCheckbox;
	IBOutlet id fillStyle;
	IBOutlet id borderWidth;
}

- fillColor;
- (BOOL)shouldFill;
- (BOOL)shouldUseMainColorForFill;
- (int)borderWidth;

@end
