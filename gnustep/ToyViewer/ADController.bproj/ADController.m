#import "../ADController.h"
#import <Foundation/NSRunLoop.h>
#import <AppKit/NSButton.h>
#import "ADSlave.h"
#import "../TVController.h"
#import "../PrefControl.h"

enum {
	Stat_INIT,
	Stat_PLAY,
	Stat_PAUSE,
	Stat_QUIT
};

enum {
	fw_forward,
	fw_backward,
	fw_EOL
};

static id activePanel = nil;


@implementation ADController

#define  Panel_X(n)	(6.0 + ((n) % 4) * 16.0 + ((n) / 8) * 9.0)
#define  Panel_Y(n)	(400.0 - ((n) % 8) * 20.0)

/* Local Method */
- locatePanel
{
	static int panelNum = 0;

	[panel setFrameTopLeftPoint:
		NSMakePoint(Panel_X(panelNum), Panel_Y(panelNum))];
	++panelNum;
	return self;
}

/* Local Method */
- jumpTo:(int) pos
{
	[slider setIntValue:pos];
	currentNum = pos;
	[nextFile setStringValue:[dirlist filenameAt:pos]];
	forwarding = fw_forward;
	return self;
}


- (id)init:(id)sender dir:(NSString *)dir with:(DirList *)list
{
	[super init];
	[NSBundle loadNibNamed:@"AutoDisplay" owner:self];
	dirlist = list;
	status = Stat_INIT;
	fileNum = [dirlist fileNumber];
	[slider setMaxValue:(fileNum - 1)];
	[sliderMax setIntValue:fileNum];
	[[self locatePanel] jumpTo: 0];
	[panel setTitle: [dir lastPathComponent]];
	[panel display];
	[panel makeKeyAndOrderFront:self];
	[panel setFloatingPanel:YES];
	[panel setWorksWhenModal:YES];
	[panel setReleasedWhenClosed:YES];
	[lButton setContinuous:YES];
	[lButton setPeriodicDelay:0.5 interval:0.2];
	[rButton setContinuous:YES];
	[rButton setPeriodicDelay:0.5 interval:0.2];
	slave = [[ADSlave alloc] init:self with:sender dir: dir];
	waiting = NO;
	return self;
}

- (void)dealloc
{
	[dirlist release];
	[slave release];
	[super dealloc];
}


/* Local Method */
- setButton:(int)stat
{
	if (activePanel == self && stat != Stat_PLAY)
		activePanel = nil;	/* UNLOCKED */
	[playButton setState:(stat == Stat_PLAY)];
	[pauseButton setState:(stat == Stat_PAUSE)];
	[quitButton setState:(stat == Stat_INIT)];
	[stepButton setState:NO];
	[slider setEnabled:(stat != Stat_PLAY)];
	return self;
}

- (void)pausePush:(id)sender
{
	if ([fscreenSW state] && status != Stat_PLAY) {
	  [fscreenSW setState: NO];
	  [fscreenMethod setEnabled: NO];
	  [slave cancelFullScreen];
	}
	[self setButton: (status = Stat_PAUSE)];
}

- (void)playPush:(id)sender
{
	if (activePanel != nil && activePanel != self) {
		[self setButton: status];
		NSBeep();
		return;
	}
	activePanel = self;	/* LOCKED */
	[self setButton: Stat_PLAY];
	if (status != Stat_PLAY) {
		status = Stat_PLAY;
		[NSObject cancelPreviousPerformRequestsWithTarget:slave
				selector:@selector(donext:) object:self];
		[slave performSelector:@selector(donext:) withObject:self
				afterDelay: 300 / 1000.0];
		waiting = YES;
	} 
}

/* Local Method */
- (void)stepForwardOrBackward
{
	if (activePanel != nil && activePanel != self) {
		[self setButton: status];
		NSBeep();
		return;
	}
	activePanel = self;	/* LOCKED */
	[playButton setState:NO];
	[pauseButton setState:NO];
	[quitButton setState:NO];
	status = Stat_PLAY;
	[slave dostep:self];
	[self setButton: (status = Stat_PAUSE)];	/* UNLOCKED */
}

- (void)stepPush:(id)sender
{
	if (forwarding == fw_EOL)
		NSBeep();
	else if (forwarding == fw_backward) {
		int n = currentNum + 2;
		if (n >= fileNum)
			n = fileNum - 1;
		[self jumpTo: n];
	}
	[self stepForwardOrBackward];
	if (currentNum < fileNum-1) {
		[self sliderUp:self];
		// forwarding = fw_forward;
	}else
		forwarding = fw_EOL;
}

- (void)backPush:(id)sender
	// Don't use this method via GUI control panel
{
	if (forwarding == fw_forward && currentNum <= 1) {
		NSBeep();
		return;
	}
	if (forwarding != fw_backward) {
		int n = (forwarding == fw_EOL) ? fileNum - 2 : currentNum - 2;
		if (n < 0) n = 0;
		[self jumpTo: n];
	}
	[self stepForwardOrBackward];
	if (currentNum > 0) {
		[self sliderDown:self]; 
		forwarding = fw_backward;
	}else {
		[self sliderUp:self];	/* currentNum := 1 */
		forwarding = fw_forward;
	}
}

- (void)quitPush:(id)sender
{
	[self setButton: Stat_INIT];
	if ([fscreenSW state])
		[slave cancelFullScreen];
	[panel close];
	if (waiting) {
		status = Stat_QUIT;
		return;
	}
	[self release];
}


- (void)sliderChange:sender
{
	int n = [slider intValue];
	if (currentNum != n)
		[self jumpTo: n]; 
}

- (void)sliderDown:sender
{
	if (status != Stat_PLAY && currentNum > 0)
		[self jumpTo: currentNum - 1];
}

- (void)sliderUp:sender
{
	if (status != Stat_PLAY && currentNum < fileNum-1)
		[self jumpTo: currentNum + 1];
}


- (NSString *)nextFilename
{
	/* If Quit button has been pushed already,
	   this method should return nil. */
	return (status == Stat_PLAY) ? [dirlist filenameAt:currentNum] : nil;
}

- (void)continueLoop:(BOOL)cont
{
	int intv;

	if (status == Stat_QUIT) {
		[self release];
		return;
	}else if (status == Stat_PAUSE) { /// R.B. 3.13.99
		[NSObject cancelPreviousPerformRequestsWithTarget: slave
			selector: @selector(donext:) object: self];
		return;
	}
	if (!cont) {
		waiting = NO;
		return;
	}
	if (currentNum >= fileNum-1) {
		if ([loopSW state]) {
			[self jumpTo: (currentNum = 0)];
		}else {
			[self pausePush:self];
			forwarding = fw_EOL;
			waiting = NO;
			return;
		}
	}else
		[self jumpTo: currentNum + 1];
	intv = [[PrefControl sharedPref] autoDisplayInterval];
	[NSObject cancelPreviousPerformRequestsWithTarget:slave
		selector:@selector(donext:) object:self];
	[slave performSelector:@selector(donext:)
		withObject:self afterDelay: intv / 1000.0];
	waiting = YES; 
}

- (BOOL)scanFixPosition
{
	return ([[PrefControl sharedPref] windowPosition] == pos_FixScan);
}

- (void)changeFullScreen:(id)sender
{
	BOOL backg = [fscreenSW state];
	[fscreenMethod setEnabled: backg];
	if (!backg)
	  [slave cancelFullScreen];
}

- (int)fullscreenMethod
{
  return [fscreenSW state] ? [fscreenMethod indexOfSelectedItem] : (-1);
}

/* Delegate of window */
- (void)windowDidResignKey:(NSNotification *)aNotification
{	/* If some error occured, the full-screen window should be closed
	   and the message panel would be displayed */
	[slave cancelFullScreen];
	[self setButton: (status = Stat_PAUSE)];
}

@end
