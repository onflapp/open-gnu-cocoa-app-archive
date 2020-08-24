/*
	AlertShower.m	1997-12-28
		by T.Ogihara (ogihara@seg.kobe-u.ac.jp)
*/


#import  "AlertShower.h"
#import  <stdio.h>
#import  <stdlib.h>
//#import  <libc.h>
#import  <objc/objc.h>
#import  <Foundation/NSString.h>
#import  <Foundation/NSThread.h>
#import  <Foundation/NSBundle.h>	/* LocalizedString */
#import  <AppKit/NSWindow.h>
#import  <AppKit/NSPanel.h>		/* NSRunAlertPanel() */
#import  <AppKit/NSGraphics.h>		/* NSPing() */
#import  "common.h"
#import  "ToyWindow.h"

@implementation AlertShower

static BOOL timedflag = NO;
static BOOL suppress = NO;

+ (void)setTimedAlert:(BOOL)flag
{
	timedflag = flag;
}

+ (void)setSuppress:(BOOL)flag
{
	suppress = flag;
}

- (id)initWithTitle:(NSString *)str
{
	[super init];
	title = [str retain];
	return self;
}


static NSString *err_message(int err)
{
	switch (err) {
	case Err_OPEN:
		return NSLocalizedString(@"Can't open file", Err_OPEN);
	case Err_FORMAT:
		return NSLocalizedString(@"Illegal image format", Err_FORMAT);
	case Err_MEMORY:
		return NSLocalizedString(
			@"Can't get working memory", Err_MEMORY);
	case Err_SHORT:
		return NSLocalizedString(
			@"Encountered unexpected EOF", Err_SHORT);
	case Err_ILLG:
		return NSLocalizedString(
			@"Illegal information included", Err_ILLG);
	case Err_IMPLEMENT:
		return NSLocalizedString(
			@"Unsupported image format", Err_IMPLEMENT);
	case Err_SAVE:
		return NSLocalizedString(
			@"Can't write into file", Err_SAVE);
	case Err_SAV_IMPL:
		return NSLocalizedString(
			@"Can't save this format", Err_SAV_IMPL);
	case Err_EPS_IMPL:
		return NSLocalizedString(@"Can't apply to EPS", Err_EPS_IMPL);
	case Err_EPS_ONLY:
		return NSLocalizedString(
			@"This operation is only to EPS", Err_EPS_ONLY);
	case Err_PDF_IMPL:
		return NSLocalizedString(@"Can't apply to PDF", Err_PDF_IMPL);
	case Err_PDF_ONLY:
		return NSLocalizedString(
			@"This operation is only to PDF", Err_PDF_ONLY);
	case Err_EPS_PDF_IMPL:
		return NSLocalizedString(@"Can't apply to PDF/EPS", Err_EPS_PDF_IMPL);
	case Err_EPS_PDF_ONLY:
		return NSLocalizedString(
			@"This operation is only to PDF/EPS", Err_EPS_PDF_ONLY);
	case Err_OPR_IMPL:
		return NSLocalizedString(
			@"Can't apply this operation", Err_OPR_IMPL);
	case Err_NOFILE:
		return NSLocalizedString(@"There is no file", Err_NOFILE);
	case Err_FLT_EXEC:
		return NSLocalizedString(
			@"Can't execute filter program", Err_FLT_EXEC);
	case Err_ACCESS:
		return NSLocalizedString(
			@"Can't access to file", Err_ACCESS);
	default:
		break;
	}
	return NULL;
}

- (void)runAlert:(NSString *)fname :(int)err
{
	id panel;
	NSString *msg = err_message(err);

	if (suppress)
		return;
	[ToyWindow setZoomedWindow: nil];  // Cancel Zoom Mode
	if (timedflag) {
		panel = NSGetAlertPanel(title, @"%@ :\n%@",
				nil, nil, nil, fname, msg);
		NSBeep();
		[panel center];
		[panel makeKeyAndOrderFront:panel];
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:(3)]];
		[panel close];
		NSReleaseAlertPanel(panel);
	}else
		NSRunAlertPanel(title, @"%@ :\n%@", @"", nil, nil, fname, msg);
}


- (void)runAlertSheet:(NSWindow *)win doc:(NSString *)fname :(int)err
{
	NSString *msg = err_message(err);
	if (suppress)
		return;
	NSBeginAlertSheet(title, @"", nil, nil, win,
		nil, (SEL)0, (SEL)0, (void *)self, @"%@ :\n%@", fname, msg);
}

@end
