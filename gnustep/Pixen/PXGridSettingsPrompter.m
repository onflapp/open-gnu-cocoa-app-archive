//
//  PXGridSettingsPrompter.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Thu Mar 18 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXGridSettingsPrompter.h"


@implementation PXGridSettingsPrompter

- initWithSize:(NSSize)aSize color:aColor shouldDraw:(BOOL)newShouldDraw;
{
    [super initWithWindowNibName:@"PXGridSettingsPrompter"];
	unitSize = aSize;
	color = aColor;
	shouldDraw = newShouldDraw;
	return self;
}

- (void)setDelegate:newDelegate
{
    delegate = newDelegate;
}

- (void)prompt
{
	[self showWindow:self];
	[[sizeForm cellAtIndex:0] setIntValue:unitSize.width];
	[[sizeForm cellAtIndex:1] setIntValue:unitSize.height];
	[colorWell setColor:color];
	[shouldDrawCheckBox setState:(shouldDraw) ? NSOnState : NSOffState];
	[self update:self];
}

- (IBAction)update:sender
{
	if ([shouldDrawCheckBox state] == NSOnState) {
		[sizeForm setEnabled:YES];
		[colorWell setEnabled:YES];
		[sizeLabel setEnabled:YES];
		[colorLabel setEnabled:YES];
	} else {
		[sizeForm setEnabled:NO];
		[colorWell setEnabled:NO];
		[sizeLabel setEnabled:NO];
		[colorLabel setEnabled:NO];
	}
    [delegate gridSettingsPrompter:self updatedWithSize:NSMakeSize([[sizeForm cellAtIndex:0] intValue], [[sizeForm cellAtIndex:1] intValue]) color:[colorWell color] shouldDraw:([shouldDrawCheckBox state] == NSOnState) ? YES : NO];
}

- (IBAction)useAsDefaults:sender
{
	id defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:([shouldDrawCheckBox state] == NSOnState) forKey:@"PXGridShouldDraw"];
	[defaults setFloat:[[sizeForm cellAtIndex:0] intValue] forKey:@"PXGridUnitWidth"];
	[defaults setFloat:[[sizeForm cellAtIndex:1] intValue] forKey:@"PXGridUnitHeight"];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:[colorWell color]] forKey:@"PXGridColorData"];
	[self update:self];
}

@end
