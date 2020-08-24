//
//  PXPencilToolPropertiesView.m
//  Pixen-XCode
//
//  Created by Ian Henderson on Wed Mar 17 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXPencilToolPropertiesView.h"
#import "PXDocument.h"
#import "PXPattern.h"

@implementation PXPencilToolPropertiesView

- nibName
{
    return @"PXPencilToolPropertiesView";
}

- (int)lineThickness
{
    return [lineThickness intValue];
}

- (void)patternUpdated:(NSNotification *)aNotification
{
	waitingForPatternEditing = NO;
	[drawingPattern release];
	drawingPattern = [[[aNotification object] canvas] retain];
	[lineThickness setEnabled:NO];
	[clearButton setEnabled:YES];
	[modifyButton setTitle:NSLocalizedString(@"MODIFY_PATTERN", @"Modify Pattern…")];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSSize)patternSize
{
	if (drawingPattern != nil) {
		return [drawingPattern size];
	}
	return NSZeroSize;
}

- (NSArray *)drawingPoints
{
	return [drawingPattern pointsInPattern];
}

- (IBAction)clearPattern:sender
{
	[drawingPattern release];
	drawingPattern = nil;
	[lineThickness setEnabled:YES];
	[clearButton setEnabled:NO];
	[modifyButton setTitle:NSLocalizedString(@"SET_PATTERN", @"Set Pattern…")];
}

- (IBAction)modifyPattern:sender
{
	if (waitingForPatternEditing == YES) {
		return;
	}
	PXDocument *document = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Pixen Image"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(patternUpdated:) name:PXDocumentClosed object:document];
	[document setCanSave:NO];
	if (drawingPattern == nil) {
		drawingPattern = [[PXPattern alloc] init];
		[drawingPattern setSize:NSMakeSize([self lineThickness], [self lineThickness])];
		int x, y;
		for (x=0; x<[self lineThickness]; x++) {
			for (y=0; y<[self lineThickness]; y++) {
				[drawingPattern addPoint:NSMakePoint(x, y)];
			}
		}
	}
	[document setValue:[drawingPattern copy] forKey:@"canvas"];
	[document makeWindowControllers];
	[[[[document windowControllers] objectAtIndex:0] window] setContentSize:NSMakeSize(300, 200)];
	[[[document windowControllers] objectAtIndex:0] zoomToFit:self];
	[[NSDocumentController sharedDocumentController] addDocument:document];
	[self clearPattern:nil];
}

- (void)awakeFromNib
{
	[self clearPattern:nil];
}

- (void)dealloc
{
	[drawingPattern release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

@end
