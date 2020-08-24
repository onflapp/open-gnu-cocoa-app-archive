//
//  PrintInfoCtrl.m
//  ToyViewer
//
//  Created by OGIHARA Takeshi on Tue Feb 05 2002.
//  Copyright (c) 2001 OGIHARA Takeshi. All rights reserved.
//

#import "PrintInfoCtrl.h"
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSBundle.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPrintInfo.h>
#import <AppKit/NSPageLayout.h>

#define  printerDPI	@"printerDPI"
#define  DefaultDPI	75
#define  pageMARGIN	@"pageMARGIN"
#define  DefaultMargin	24
#define  pageOrient	@"pageOrientation"

@implementation PrintInfoCtrl

- (id)init
{
	NSUserDefaults *usrdef;
	NSString *ostr, *w;
	NSPrintingOrientation orient;

	[super init];
	usrdef = [NSUserDefaults standardUserDefaults];
	dpi = [usrdef integerForKey: printerDPI];
	if (dpi <= 0)
		dpi = DefaultDPI;
	w = [usrdef stringForKey: pageMARGIN];
	if (w == nil)
		margin = DefaultMargin;
	else
		margin = [w intValue];
	ostr = [usrdef stringForKey: pageOrient];
	orient = (ostr && [ostr characterAtIndex:0] == 'P')
		? NSPortraitOrientation : NSLandscapeOrientation;

	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setOrientation: orient];
	[printInfo setLeftMargin: margin];
	[printInfo setRightMargin: margin];
	[printInfo setTopMargin: margin];
	[printInfo setBottomMargin: margin];
	return self;
}

- (void)runPageLayout:(id)sender
{
	int val;
	NSUserDefaults *usrdef;
	NSPrintingOrientation orient;

	pageLayout = [NSPageLayout pageLayout];
	if ([pageLayout accessoryView] == nil) {
		[NSBundle loadNibNamed:@"PageInfo.nib" owner:self];
		[pageLayout setAccessoryView:[boxview contentView]];
	}
	[dpiText setIntValue: dpi];
	[dpiSlider setIntValue: dpi];
	[marginText setIntValue: margin];

	if ([pageLayout runModalWithPrintInfo: printInfo] != NSOKButton)
		return;

	usrdef = [NSUserDefaults standardUserDefaults];
	val = [dpiText intValue];
	if (dpi != val) {
		dpi = val;
		[usrdef setInteger:dpi forKey:printerDPI];
	}
	val = [marginText intValue];
	if (margin != val && val >= 0 && val < 1000) {
		margin = val;
		[printInfo setLeftMargin: margin];
		[printInfo setRightMargin: margin];
		[printInfo setTopMargin: margin];
		[printInfo setBottomMargin: margin];
		[usrdef setInteger:margin forKey:pageMARGIN];
	}
	orient = [printInfo orientation];
	[usrdef setObject:
	(orient == NSPortraitOrientation) ? @"Portrait" : @"Landscape"
	forKey:pageOrient];
}

- (void)changeSlider:(id)sender
{
	[dpiText setIntValue: ([sender intValue] / 25) * 25];
}

- (void)changeMargin:(id)sender
{
	// Currently do nothing
}

- (int)dpiOfPrinter { return dpi; }

@end
