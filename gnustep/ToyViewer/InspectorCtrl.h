//
//  InspectorCtrl.h
//  ToyViewer
//
//  Created by ogihara on Thu Nov 22 2001.
//  Copyright (c) 2001 Takeshi Ogihara. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ToyWin;


@interface InspectorCtrl : NSObject
{
	id	panel;
	id	commentText;
	id	infoText;
	id	buttons;
	id	editSW;
	ToyWin	*commWin;
}

+ (void)activateInspector;
- (void)loadNib;
- (void)didGetNotification:(NSNotification *)notify;
- (void)activate:(id)sender;
- (void)toggleEditable:(id)sender;
- (void)writeComment:(id)sender;

/* delegate methods */
- (BOOL)windowShouldClose:(id)sender;

@end
