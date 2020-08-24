#import  "BackgCtr.h"
#import  <AppKit/NSApplication.h>
#import  <AppKit/NSControl.h>
#import  <AppKit/NSMenuItem.h>
#import  <AppKit/NSWorkspace.h>
#import  <Foundation/NSData.h>
#import  <Foundation/NSString.h>
#import  <Foundation/NSBundle.h>	/* LocalizedString */
#import  <Foundation/NSUserDefaults.h>
// #import  <Foundation/NSDistributedNotificationCenter.h>
#import  <stdio.h>
#import  <stdlib.h>
#import  <string.h>
#import  <objc/objc.h>
#import  <libc.h>
//#import  <mach/mach_init.h>
#import  "../TVController.h"
#import  "../ToyWin.h"
#import  "../ToyView.h"
#import  "../common.h"
#import  "../strfunc.h"
#import  "Background.h"
#import  "FullScreenView.h"
#import  "FullScreenWindow.h"
#import <Foundation/NSZone.h>

@implementation BackgCtr

static NSZone	*backZone = NULL;
static int	countOfwin = 0;

+ (NSZone *)zoneForBackground
{
  if (backZone == NULL) {
    backZone = NSCreateZone(100,100, YES);
    countOfwin = 0;
  }
  return backZone;
}

+ (void)clearZone
{
  NSRecycleZone(backZone);
  backZone = NULL;
}

- (id)init
{
	[super init];
	backWin = nil;
	fullscreenCtr = nil;
	return self;
}

- (void)setFullScreen:(id)controller
{
	fullscreenCtr = controller;
}

#ifdef DEBUG
- (void)notify:(NSNotification *)notif
{
	NSLog(@"Name=%@, Obj=%@, Info=%@\n",
		[notif name], [notif object], [notif userInfo]);
}
#endif

- (void)cleanBackground:(id)sender
{
  if (backWin == nil)
    return;
  [backWin close];
  /* backWin is released because setReleasedWhenClosed:YES */
  backWin = nil;
  if (--countOfwin == 0)
    [[self class] clearZone];
  // [[NSDistributedNotificationCenter defaultCenter]
  // 	postNotificationName:@"com.apple.desktop" object:nil];
  // [[NSDistributedNotificationCenter defaultCenter]
  //	addObserver:self selector:@selector(notify:) name:nil object:nil];
}

- (void)makeFront:(id)sender
{
	if (backWin == nil)
	  return;
	if (![[backWin contentView] isFront])
		[backWin toFront:self]; 
}

- (void)toggleFront:(id)sender
{
	if (backWin == nil)
		return;
	if ([[backWin contentView] isFront]) /* toggle */
		[backWin toBehind:self];
	else
		[backWin toFront:self]; 
}


/* Local Method */
- (id)makeWindowForBackground
{
	id	view;
	int	mask;
	NSZone *zone;

	zone = [[self class] zoneForBackground];
	if (fullscreenCtr != nil) {
		view = [[FullScreenView allocWithZone:zone] init];
		[view setController: fullscreenCtr];
		mask = NSTitledWindowMask;
		/* NSTitledWindowMask is needed to be a key-window */
	}else {
		view = [[Background allocWithZone:zone] init];
		mask = 0;
	}
	backWin = [[FullScreenWindow allocWithZone:zone]
			initWithContentRect:[FullScreenView screenRect]
			styleMask:mask];
	[backWin setContentView:view];
	[backWin setReleasedWhenClosed:YES];
	[view release]; // backWin retains it.
	[view paintDefaultColor];

	if (fullscreenCtr != nil) {
	  [backWin setDelegate: fullscreenCtr];
	  [backWin makeFirstResponder:view];
	  [backWin toFront:self];
	}else
	  [backWin toBehind:self];
	++countOfwin;
	return backWin;
}

- (id)setImage:(NSImage *)backimage hasAlpha:(BOOL)alpha with:(int)method
{
  id	view;
  id	rtn;
  
  if (backWin == nil)
    [self makeWindowForBackground];
  view = [backWin contentView];
  NSLog(@"========================");
  rtn = [view setImage: backimage hasAlpha: alpha with: method];
  if (fullscreenCtr)
    [backWin makeKeyWindow];
  NSLog(@"========================");
  [backWin display];
  return rtn;	/* If nil Err_Memory */
}

- (id)setStream:(NSData *)data with:(int)method
{
  id	view;
	id	rtn;
	
	if (backWin == nil)
	  [self makeWindowForBackground];
	view = [backWin contentView];
	rtn = [view setStream: data with: method];
	if (fullscreenCtr)
	  [backWin makeKeyWindow];
	[backWin display];
	return rtn;	/* If nil Err_Memory */
}

@end



