#import <Foundation/NSObject.h>
#import <AppKit/NSResponder.h>

@class IntervalTimer;

@interface WaitMessageCtr:NSObject
{
	id	messagePanel;
	id	messageText;
	id	progressView;
	IntervalTimer *timer;
	float	aswhole;
}

- (id)init;
- (id)messageDisplay:(NSString *)msg;
- (void)setStringValue:(NSString *)aString;
- (void)resetProgress;
- (void)setProgress:(int)whole;
- (void)progress:(int)value;

@end

extern WaitMessageCtr *theWaitMsg;

/* ---- Sample 1 ----
	[theWaitMsg messageDisplay:@"Reducing..."];	-- Display message
	...
	[theWaitMsg setProgress:(height - 1)];	-- Start progress display
	...					-- Arg is a value as 100%
	for (y = 0; y < height; ++y) {
		...
		[theWaitMsg progress: y];	-- Check & display progress
		...
	}
	[theWaitMsg resetProgress];		-- Stop progress display
	...
	[theWaitMsg messageDisplay:@"Packing Bits..."];
	...
	[theWaitMsg messageDisplay:nil];	-- Close message panel

   ---- Sample 2 ----
	[theWaitMsg messageDisplay:@"Reducing..."];	-- Display message
	...
	[theWaitMsg setProgress:0.0];		-- Start 'Barber pole'
	...
	[theWaitMsg messageDisplay:@"Packing Bits..."];
	...
	[theWaitMsg messageDisplay:nil];	-- Close message panel
*/
