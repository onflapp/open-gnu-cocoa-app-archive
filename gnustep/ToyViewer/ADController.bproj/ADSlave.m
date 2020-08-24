#import "ADSlave.h"
#import  <Foundation/NSAutoreleasePool.h>
#import  <Foundation/NSArray.h>
#import "../NSStringAppended.h"
#import "../ADController.h"
#import "../TVController.h"
#import "../BundleLoader.h"
#import "../BackgCtr.bproj/BackgCtr.h"
#import "../ToyWin.h"
#import "../common.h"

#define  WinBufSIZE	4

@implementation ADSlave

- (id)init:(id)sender with:(id)controller dir:(NSString *)path
{
	[super init];
	adCtrl = sender;
	tvCtrl = controller;
	backCtrl = nil;
	directory = [[NSString alloc] initWithString:path];
	windowBuffer = [[NSMutableArray alloc] initWithCapacity:WinBufSIZE];
	return self;
}

- (void)dealloc
{
	[directory release];
	[backCtrl release];
	[windowBuffer release];
	[super dealloc];
}

- (void)cancelFullScreen
{
	[backCtrl cleanBackground:self];
}

/* Local Method */
- doNextImage: sender
{
	NSString *fname, *nextf;
	id	tw;
	int	method;

	if ((nextf = [adCtrl nextFilename]) == nil)
		return nil;
	fname = [directory newStringByAppendingPathComponent: nextf];

	if ((method = [adCtrl fullscreenMethod]) < 0) {
		BOOL	fixpos, oldflag = NO;
		if ([tvCtrl winOpened:fname makeKey:YES] != nil) /* already opened */
			return self;
		fixpos = [adCtrl scanFixPosition];
		if (fixpos) {
			oldflag = [ToyWin displayOverKeyWindow];
			[ToyWin setDisplayOverKeyWindow: YES];
		}
		tw = [tvCtrl drawFile: fname];
		if (fixpos && oldflag == NO)
			[ToyWin setDisplayOverKeyWindow: NO];
		if (tw) {
			ToyWin *oldtw;
			NSString *str;
			int idx, cnt, k;
			int num = [windowBuffer count] + 1;
			ToyWin *closewin[num];

			[windowBuffer addObject: fname];
			for (idx = 0, cnt = 0; idx < num; idx++) {
				str = [windowBuffer objectAtIndex:idx];
				oldtw = (ToyWin *)[tvCtrl winOpened:str makeKey:NO];
				if ([oldtw keepOpen])
					closewin[idx] = nil;
				else {
					closewin[idx] = oldtw;
					cnt++;
				}
			}
			if (cnt > WinBufSIZE) {
			    for (idx = num-1, k = WinBufSIZE; idx >= 0 && k > 0; idx--)
				if (closewin[idx] != nil)
					k--;
			    for ( ; idx >= 0; idx--)
				if (closewin[idx] != nil) {
					[[closewin[idx] window] performClose:self];
					[windowBuffer removeObjectAtIndex:idx];
				}
			}
		}
	}else { /* Full Screen */
	  NSData *stream;
	  if (backCtrl == nil) {
	    backCtrl = [BundleLoader loadAndNew: b_BackgCtr];
	    [backCtrl setFullScreen: adCtrl];
	  }
	  if ((stream = [tvCtrl openDataFromFile:fname]) == nil)
	    return nil;
	  if ([backCtrl setStream: stream with: method] == nil)
	    return nil;
	}
	return self;
}

- donext: sender
{
	id	r;
	NSAutoreleasePool *subpool;

	subpool = [[NSAutoreleasePool alloc] init];
	r = [self doNextImage: sender];
	[adCtrl continueLoop:(r != nil)];
	[subpool release];
	return r;
}

- dostep: sender
{
	id	r;
	NSAutoreleasePool *subpool;

	subpool = [[NSAutoreleasePool alloc] init];
	r = [self doNextImage: sender];
	[adCtrl continueLoop:NO];
	[subpool release];
	return r;
}

@end
