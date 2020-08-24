#import  "WaitMessageCtr.h"
#import  <AppKit/NSOpenPanel.h>
#import  <Foundation/NSDate.h>
#import  <Foundation/NSArray.h>
#import  <Foundation/NSThread.h>
#import  <Foundation/NSLock.h>
#import  <Foundation/NSConnection.h>
#import  <Foundation/NSAutoreleasePool.h>
#import  <AppKit/NSProgressIndicator.h>
#import  "IntervalTimer.h"

/* extern */ WaitMessageCtr *theWaitMsg = nil;

@implementation WaitMessageCtr

- (id)init
{
	[super init];
	timer = [[IntervalTimer alloc] init];
	aswhole = 100.0; /* dummy */
	if (theWaitMsg == nil)
		theWaitMsg = self;
	return self;
}

- (id)messageDisplay:(NSString *)msg
{
	if (msg) {
		[messagePanel makeKeyAndOrderFront:self];
		[messageText setStringValue:msg];
		[messagePanel setFloatingPanel:YES];
		[messagePanel display];
	}else {
		[messagePanel setFloatingPanel:NO];
		[messagePanel close];
		if (aswhole <= 0.0) {
			[progressView stopAnimation:self];
			[progressView setIndeterminate:NO];
		}
		[progressView setDoubleValue:0.0];
	}
	return self;
}

- (void)setStringValue:(NSString *)aString
{
	[self messageDisplay: aString];
}

- (void)resetProgress
{
	if (aswhole <= 0.0) {
		[progressView stopAnimation:self];
		[progressView setIndeterminate:NO];
	}else
		[timer stopThread];
	[progressView setDoubleValue:0.0];
	[messagePanel display];
}

- (void)setProgress:(int)whole
{
	if ((aswhole = (float)whole) <= 0.0) {
		[progressView setIndeterminate:YES];
		[progressView setUsesThreadedAnimation:YES];
		[progressView setAnimationDelay:5.0/60.0];
		[progressView startAnimation:self];
		return;
	}
	[progressView setIndeterminate:NO];
	[timer startThread];
}

- (void)progress:(int)value
{
	if ([timer check]) {
		float cv = [progressView doubleValue];
		float nv = value * 100.0 / aswhole;
		if ((nv -= cv) > 0.0) {
		    [progressView incrementBy: nv];
		    [progressView displayIfNeeded];
		}
	}
}

@end
