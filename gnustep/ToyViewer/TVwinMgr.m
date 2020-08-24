#import  "TVController.h"
#import  <Foundation/NSArray.h>
#import  <Foundation/NSEnumerator.h>
#import  <Foundation/NSURL.h>
#import  <Foundation/NSUserDefaults.h>
#import  <Foundation/NSNotification.h>
#import  <AppKit/NSApplication.h>
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMenuItem.h>
#import  <AppKit/NSWorkspace.h>
#import  <stdio.h>
#import  <stdlib.h>
#import  <string.h>
#import  <objc/zone.h>
//#import  <libc.h>
#import  <mach/mach_init.h>
#import  "PrefControl.h"
#import  "BundleLoader.h"
#import  "ToyWin.h"
#import  "ToyView.h"
#import  "ToyWindow.h"
#import  "ImageOpCtr.h"
#import  "ImageSave.bproj/ImageSave.h"
#import  "InspectorCtrl.h"
#import  "PrintInfoCtrl.h"
#import  "common.h"
#import  "strfunc.h"

#define	 MAXWindows	80

NSString *NotifyAllWindowDidClosed = @"NotifyAllWindowDidClosed";


@implementation TVController (WindowManager)

static int showp = 0;
static NSMutableArray *winline = nil;
static NSTimer *teNum;

- (BOOL)hasWindow { return (winline && [winline count] > 0); }

/* Local Method */
- (void)noWindow
{
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NotifyAllWindowDidClosed object:nil];
}

- (void)newWindow:(ToyWin *)win
{
	if (winline == nil)
		winline = [[NSMutableArray alloc] initWithCapacity:1];
	[winline addObject: win];
}

- (BOOL)checkAndDeleteWindow:(ToyWin *)win
{
	unsigned int idx, num;

	if (winline == nil || win == nil)
		return NO;
	if ((num = [winline count]) == 0)
		return NO;
	for (idx = 0; idx < num; idx++)
		if ([winline objectAtIndex: idx] == win)
			break;
	if (idx >= num)
		return NO;
	[winline removeObjectAtIndex: idx];
	if ([winline count] == 0)
		[self noWindow];
	return YES;
}

- (BOOL)checkWindow:(ToyWin *)win
{
	NSEnumerator *enu;
	ToyWin *obj;

	if (winline == nil || win == nil)
		return NO;
	// return [winline containsObject:win];
	// Don't use containsObject:, because win may have been released.
	enu = [winline objectEnumerator];
	while ((obj = (ToyWin *)[enu nextObject]) != nil)
		if (obj == win)
			return YES;
	return NO;
}

- (void)deleteAllWindow:(id)sender
{
	ToyWin *obj;
	int	i, n;

	if (winline == nil || (n = [winline count]) == 0)
		return;
	for (i = n-1; i >= 0; i--) {
		obj = (ToyWin *)[winline objectAtIndex:i];
		if (![obj keepOpen]) {
			[[obj window] performClose:sender];
			// [winline removeObjectAtIndex: i]; (*)
		}
	}
	// if ([winline count] == 0) ... (*)
	// (*) these actions are done in method checkAndDeleteWindow:
}

/* Local Method */
- (void)wakeup
{
	if (showp >= [winline count]) {
		[teNum invalidate];
		[teNum release];
		teNum = nil;
		showp = 0;
	}else {
		ToyWindow *tw = (ToyWindow *)[[winline objectAtIndex:showp++] window];
		[tw orderFront:self];
		if ([ToyWindow inFrontMode])
			[tw setZoom: YES];
	}
}

- (void)showAllWindow:(id)sender
{
	if (winline == nil || [winline count] <= 0)
		return;
	if (showp > 0) {
		showp = [winline count] + 1;
		[self wakeup];	/* stop */
	}else {
		float intv = [[PrefControl sharedPref] allWinDisplayInterval] / 1000.0;
		showp = 0;
		[self wakeup];	/* 1st call */
		teNum = [NSTimer scheduledTimerWithTimeInterval:intv
				target:self selector:@selector(wakeup)
				userInfo:nil repeats:YES];
                [teNum retain];
	} 
}

/* Local Method */
- (int)keyWindowIndex
{
	int idx;

	if (winline == nil || (idx = [winline count]) <= 0)
		return -1;

	for (idx--; idx >= 0; idx--)
		if ([[[winline objectAtIndex: idx] window] isMainWindow])
			return idx;
	return ([winline count] - 1);
}

- (id)keyWindow
{
	int i = [self keyWindowIndex];
	return (i >= 0) ? [winline objectAtIndex: i] : nil;
}

- (void)showNextWindow:(id)sender
{
	int i = [self keyWindowIndex];
	if (i < 0)
		return;
	if ([sender tag]) { /* Previous */
		if (--i < 0) i = [winline count] - 1;
	}else { /* Next */
		if (++i >= [winline count]) i = 0;
	}
	[[[winline objectAtIndex: i] window] makeKeyAndOrderFront:sender];
}

- (void)activateInspector:(id)sender
{
	[InspectorCtrl activateInspector];
}

- (void)activatePreferences:(id)sender
{
	[[PrefControl sharedPref] makeKeyAndOrderFront: sender]; 
}

- (id)keyParentWindow:(int)op
{
	ToyWin *tw, *win;

	if ((tw = [self keyWindow]) == nil)
		return nil;
	if (op != NoOperation && op != FromPasteBoard && [tw madeby] == op) {
		win = [tw parent];
		if (win && [self checkWindow: win])
			return win;
	}
	return tw;
}

- (id)winOpened:(NSString *)newfile makeKey:(BOOL)flag
{
	NSEnumerator *enu;
	ToyWin *obj;

	if (winline == nil || [winline count] == 0)
		return nil;
	enu = [winline objectEnumerator];
	while ((obj = (ToyWin *)[enu nextObject]) != nil) {
		if ([newfile isEqualToString:[obj filename]]) {
			if (flag)
				[[obj window] makeKeyAndOrderFront:self];
			return obj;
		}
	}
	return nil;
}

/* NSMenuActionResponder Protocol */
- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
	SEL act;

	act = [aMenuItem action];
	if (act == @selector(saveAs:) || act == @selector(deleteAllWindow:)
		|| act == @selector(showAllWindow:)
		|| act == @selector(showNextWindow:)
		|| act == @selector(attachIcon:)
		|| act == @selector(print:)
		|| act == @selector(toggleFrontMode:))
		return (winline && [winline count] > 0);
	return YES;
}


/****** Print *****************************/

- (void)print:(id)sender
{
	id	tw;

	if ((tw = [self keyWindow]) == nil) {
		NSBeep();
		return;
	}
	[ToyWindow setZoomedWindow: nil];  // Cancel Zoom Mode
	if (prtInfo == nil)
		prtInfo = [[PrintInfoCtrl alloc] init];
	[tw printWithDPI:[prtInfo dpiOfPrinter]];
}

- (void)runPageLayout:(id)sender
{
	[ToyWindow setZoomedWindow: nil];  // Cancel Zoom Mode
	if (prtInfo == nil)
		prtInfo = [[PrintInfoCtrl alloc] init];
	[prtInfo runPageLayout:sender];
}

/****** SaveAs... *************************/

/* Local Method */
- (id)imageSaveWith:(id)win
{
	return [[[[BundleLoader loadClass:b_ImageSave] alloc]
			initWithWin:win] autorelease];
}

- (void)saveAs:(id)sender
{
	ToyWin	*tw;
	id	imgsv;

	if ((tw = (ToyWin *)[self keyWindow]) == nil) {
		NSBeep();
		return;
	}
	imgsv = [self imageSaveWith: tw];
	[imgsv setRecentList: recentlist];

	switch ([sender tag]) {
	case 0: [imgsv saveAsTiff];
		break;
	case 1: [imgsv saveAsEPS];
		break;
	case 2: [imgsv saveAsType:Type_bmp];
		break;
	case 3:
		[imgsv setOpCtr: imageOpCtr];
		[imgsv saveAsGif];
		break;
	case 4: [imgsv saveAsJPG];
		break;
	case 5: [imgsv saveAsType:Type_jbg];
		break;
	case 6: [imgsv saveAsType:Type_ppm];
		break;
	case 7: [imgsv saveAsXBM];
		break;
	case 8: 
		[imgsv setOpCtr: imageOpCtr];
		[imgsv saveAsPng];
		break;
	case 9: [imgsv saveAsPDF];
		break;
	case 10: [imgsv saveAsJ2K];
		break;
	}
}

- (void)attachIcon:(id)sender
{
	ToyWin	*tw;

	if ((tw = (ToyWin *)[self keyWindow]) == nil) {
		NSBeep();
		return;
	}
	[[self imageSaveWith: tw] attachCustomIcon];
}

- (void)removeIcon:(id)sender
{
	[[BundleLoader loadClass:b_ImageSave] removeCustomIcon];
}


- (void)activateWebPage:(id)sender
{
	NSString *site = NSLocalizedString(@"Web Page of Takeshi Ogihara", Web Site);
	(void)[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: site]];
}


- (void)toggleFrontMode:(id)sender
{
	BOOL flag = [ToyWindow inFrontMode];
	if (flag || ![self hasWindow]) {
		// [frontModeMenu setState: NO];
		[ToyWindow setZoomedWindow: nil];
	}else {
		ToyWindow *tw = (ToyWindow *)[[self keyWindow] window];
		[tw setZoom: YES];
		// [frontModeMenu setState: YES];
	}
}

/****** Info.Panel attraction *************************/

- (void)attraction:sender
{
	if ([sender state]) {
		sleep(1);
		[sender setState:0];
	}
}

#ifdef  ToyViewer2_5
- (void)attraction:sender
{
	NSRect	wrct, brct;
	NSPoint pnt[2];
	NSImage *img;
	id	ws, win;

	img = [sender image];
	brct = [sender frame];
	wrct = [(win = [sender window]) frame];
	pnt[0].x = wrct.origin.x + brct.origin.x + 4;
	pnt[0].y = wrct.origin.y + brct.origin.y + 4;
	wrct = [[NSApp applicationIconImage] frame];
	pnt[1].x = wrct.origin.x + 8;
	pnt[1].y = wrct.origin.y + 8;
	ws = [NSWorkspace sharedWorkspace];
	[win performClose:self];
	[ws slideImage:img from:pnt[0] to:pnt[1]];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(1)]];
	[ws slideImage:img from:pnt[1] to:pnt[0]];
	[win makeKeyAndOrderFront:self]; 
}
#endif

@end
