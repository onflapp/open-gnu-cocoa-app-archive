//
//  InspectorCtrl.m
//  ToyViewer
//
//  Created by ogihara on Thu Nov 22 2001.
//  Copyright (c) 2001 Takeshi Ogihara. All rights reserved.
//

#import "InspectorCtrl.h"
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSNibLoading.h>
#import "NSStringAppended.h"
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "TVController.h"
#import "ToyWin.h"
#import "ToyView.h"
#import "common.h"
#import "strfunc.h"

#define  InsPanelName	@"InspectorPanel"
static InspectorCtrl *insCtrl = nil;

@implementation InspectorCtrl

+ (void)activateInspector
{
	if (insCtrl == nil) {
		insCtrl = [[self alloc] init];
		[insCtrl loadNib];
	}
	[insCtrl activate: self];
}

- (void)loadNib
{
	[NSBundle loadNibNamed:@"Inspector" owner:self];
	// [panel setDelegate: self];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(didGetNotification:)
		name:NSWindowDidBecomeMainNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(didGetNotification:)
		name:NotifyAllWindowDidClosed object:nil];
	(void)[panel setFrameUsingName: InsPanelName];
	[self toggleEditable:nil];
}

- (void)didGetNotification:(NSNotification *)notify
{
	[self performSelector:@selector(activate:) withObject:self
				afterDelay: 300 / 1000.0];
	/* Don't call directly activate:, because TVController does not
	  have right information about the key window */
}

/* Local Method */
- (void)showInfoAndComment
{
	int	i;
	commonInfo *cinf;
	const char *p;
	char commmsg[MAX_COMMENT];
	cinf = [[commWin toyView] commonInfo];
	sprintf(commmsg, "%s: ",
		[[[commWin filename] lastPathComponent] cString]);

	p = cinf->memo;
	for ( i = 0; p[i] && p[i] != ':'; i++) ;
	strncat(commmsg, p, i);
	[infoText setStringValue:[NSString stringWithCString:commmsg]];
	if (p[i] == ':') {
	  while (p[++i] == ' ');
	  [commentText setStringValue: [NSString stringWithCString:&p[i]]];
	}
	else
	  [commentText setStringValue:@""];
}

- (void)activate:(id)sender
{
	/* No need to care about code used: cString & stringWithCString: */
	ToyWin *w;

	if ((w = [theController keyWindow]) == nil) {
		[infoText setStringValue:@""];
		[commentText setStringValue:@""];
		[panel makeKeyAndOrderFront:self];
		[editSW setState:NO];
		[self toggleEditable:nil];
		commWin = nil;
		return;
	} 
	if (w == commWin)
	  return;
	commWin = w;
	NSLog(@"commonWin == w");
	[self toggleEditable:nil];
	[self showInfoAndComment];
	[panel makeKeyAndOrderFront:self]; 
}

- (void)toggleEditable:(id)sender
{
	BOOL flag = NO;
	NSLog(@"- (void)toggleEditable:(id)sender");
	if (sender == nil)
		[editSW setState:NO];
	else if ([sender state])
		flag = YES;
	[buttons setEnabled: flag];
	[commentText setEditable: flag];
	[commentText setBezeled: flag];
	[commentText setDrawsBackground: flag];
	if (flag) {
		[panel makeFirstResponder:commentText];
		[commentText selectText:self];
	}else
		[panel makeFirstResponder:infoText];
}

- (void)writeComment:(id)sender
{
	if (commWin == nil || ![theController checkWindow: commWin]) {
		NSBeep();
		return;
	}
	NSLog(@"writeComment");
	if ([sender selectedTag] == 0) { /* OK */
		commonInfo *cinf;
		int i, last;
		char *p;
		const char *q;
		id tv;

		cinf = [(tv = [commWin toyView]) commonInfo];
		last = 0;
		for (p = cinf->memo, i = 0; p[i] && p[i] != ':'; i++)
			if (p[i] != ' ') last = i;
		/* Coding of "cString" is SJIS currently */
		if ((q =[[commentText stringValue] cString]) != NULL && *q) {
			strcpy(&p[last + 1], " : ");
			comm_cat(p, q);
		}else
			p[last + 1] = 0;
		[tv setCommString: [NSString stringWithCString:cinf->memo]];
	}else {
		[self showInfoAndComment];
	}
	[self toggleEditable:nil];
}

/* Window's Delegate */
- (BOOL)windowShouldClose:(id)sender
{
	[panel saveFrameUsingName: InsPanelName];
	[panel setDelegate: nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self release];
	commWin = nil;
	insCtrl = nil;
	return YES;
}

@end
