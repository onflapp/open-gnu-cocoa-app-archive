#import  "IntervalTimer.h"
#import  <Foundation/NSThread.h>
#import  <Foundation/NSLock.h>
#import  <Foundation/NSDate.h>
#import  <Foundation/NSAutoreleasePool.h>

enum {
	Lc_waiting,
	Lc_timeup,
	Lc_exit
};


@implementation IntervalTimer

- (id)init
{
	[super init];
	theLock = [[NSLock alloc] init];
	status = Lc_exit;
	intv = 0.5;
	return self;
}

- (void)setInterval:(float)interval
{
	intv = interval;
}

#if 0
- (void)dealloc	/* This method is not good */
{
	[theLock release];
	[super dealloc];
}
#endif

/* Local Method */
- (void)loopThread:sender
{
        NSAutoreleasePool *subpool;
	NSDate	*wakeup;

	for ( ; ; ) {
	        subpool = [[NSAutoreleasePool alloc] init];
		[theLock lock];
		status = Lc_timeup;
		[theLock unlock];
		wakeup = [[NSDate date] addTimeInterval: intv];
		[NSThread sleepUntilDate: wakeup];
		if (status == Lc_exit) {
			[subpool release];
			[NSThread exit];
			return;
		}
		[subpool release];
	}
}

- (void)startThread
{
	status = Lc_waiting;
	[NSThread detachNewThreadSelector:@selector(loopThread:)
		toTarget:self withObject:self];
}

- (void)stopThread
{
	[theLock lock];
	status = Lc_exit;
	[theLock unlock];
}

- (BOOL)check
{
	if (status != Lc_timeup)
		return NO;
	[theLock lock];
	status = Lc_waiting;
	[theLock unlock];
	return YES;
}

@end

#ifdef ALONE
/* cc -DALONE -o tim IntervalTimer.m -framework AppKit */
#include <stdio.h>
void main(void)
{
	int	i, n;
	IntervalTimer *tim = [[IntervalTimer alloc] init];

	[tim startThread];
	for (i = 0, n = 0; n < 10; n++) {
		while (![tim check]) i++;
		printf("i = %d\n", i);
	}
	[tim stopThread];
	[tim release];
}
#endif
