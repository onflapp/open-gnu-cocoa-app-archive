//
//  PXPencilToolPropertiesView.h
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Mar 17 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXToolPropertiesView.h"

@class PXPattern;

@interface PXPencilToolPropertiesView : PXToolPropertiesView {
    IBOutlet NSTextField *lineThickness;
    IBOutlet NSButton *modifyButton;
    IBOutlet NSButton *clearButton;
	
	BOOL waitingForPatternEditing;
	PXPattern *drawingPattern;
}

- (NSSize)patternSize;
- (int)lineThickness;
- (NSArray *)drawingPoints;

- (IBAction)modifyPattern:sender;
- (IBAction)clearPattern:sender;

@end
