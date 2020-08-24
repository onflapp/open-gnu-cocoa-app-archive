//
//  ImgToolCtrlAbs.m
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import "ImgToolCtrlAbs.h"
#import <AppKit/NSPanel.h>

@implementation ImgToolCtrlAbs

- (void)setup:(id)sender { /* Virtual */}

- (id)controllerView {
	return [panel contentView];
}

@end
