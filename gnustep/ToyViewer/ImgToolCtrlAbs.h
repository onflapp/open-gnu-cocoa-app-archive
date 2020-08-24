//
//  ImgToolCtrlAbs.h
//  ToyViewer
//
//  Created by OGIHARA Takeshi on Sun May 12 2002.
//  Copyright (c) 2002 OGIHARA Takeshi. All rights reserved.
//

#import <Foundation/NSObject.h>

@interface ImgToolCtrlAbs : NSObject
{
	id	panel;
}

- (void)setup:(id)sender;
- (id)controllerView;

@end
