//
//  PXAboutController.m
//  Pixen-XCode
//
//  Created by Andy Matuschak on Sun Aug 01 2004.
//  Copyright (c) 2004 Open Sword Group. All rights reserved.
//

#import "PXAboutController.h"
#import "PXAboutPanel.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSValue.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSTextStorage.h>
#import <AppKit/NSTextView.h>

static PXAboutController *singleInstance = nil;

@implementation PXAboutController

-(id) init
{
	if ( singleInstance ) 
    {
		[self dealloc];
		return singleInstance;
    }
	
	
	if ( ! ( self = [super init] ) ) 
		return nil;
	
	if ( ! [NSBundle loadNibNamed :@"PXAbout" owner:self] )
	  NSLog(@"Warm the user");
	
	singleInstance = self;
	
	return singleInstance;
}

+(id) sharedAboutController
{
	if ( ! singleInstance  ) 
		singleInstance = [[self alloc] init]; 
	
	return singleInstance;
}


- (void)loadCreditsText
{
  id linkString = [NSString stringWithFormat:@"<a href=\"http://www.opensword.org/license.php\">MIT License</a>"];
	
  id plainString = [[[NSMutableString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"html"]] autorelease];
	
  [plainString replaceOccurrencesOfString:@"<PXLICENSE>"
	       withString:linkString
	       options:nil
	       range:NSMakeRange(0,[(NSString *)plainString length])];
	
	
#ifdef __COCOA__
  NSData *htmlData = [NSData dataWithBytes:[plainString cString] length:[(NSString *)plainString length]];
  NSDictionary *attributedOptions = [NSDictionary dictionaryWithObject:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]] forKey:@"BaseURL"];
  NSAttributedString *attributedString = [[[NSMutableAttributedString alloc] initWithHTML:htmlData options:attributedOptions documentAttributes:nil] autorelease];
  [[credits textStorage] setAttributedString:attributedString];
#else
  [credits setString :plainString];
#endif
}



- (void)createPanel
{
	id content;
	aboutPanel = [[PXAboutPanel alloc]
		 initWithContentRect:[[panelInNib contentView] frame]
				   styleMask:NSBorderlessWindowMask
					 backing:[panelInNib backingType]
					   defer:NO];
	
	[aboutPanel setBackgroundColor: [NSColor whiteColor]];
	[aboutPanel setHasShadow: YES];
	[aboutPanel setNextResponder: self];
	[aboutPanel setBecomesKeyOnlyIfNeeded: NO];
	[aboutPanel setDelegate: self];
	[aboutPanel setLevel:NSModalPanelWindowLevel];
	
	
	content = [[panelInNib contentView] retain];
	[content removeFromSuperview];
	[(PXAboutPanel *)aboutPanel setContentView:content];
	[content release];
}

//	Watch for notifications that the application is no longer active, or that
//	another window has replaced the About panel as the main window, and hide
//	on either of these notifications.
- (void) watchForNotificationsWhichShouldHidePanel
{
	//	This works better than just making the panel hide when the app
	//	deactivates (setHidesOnDeactivate:YES), because if we use that
	//	then the panel will return when the app reactivates.
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(hidePanel)
												 name: NSApplicationDidResignActiveNotification
											   object: nil];
	
	//	If the panel is no longer main, hide it.
	//	(We could also use the delegate notification for this.)
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(hidePanel)
												 name: NSWindowDidResignMainNotification
											   object: aboutPanel];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(hidePanel)
												 name: NSWindowDidResignKeyNotification
											   object: aboutPanel];
}

- (void)dealloc
{
	[aboutPanel release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)setupPanel
{
	[self createPanel];
	[self loadCreditsText];
	[aboutPanel center];
	[self watchForNotificationsWhichShouldHidePanel];
}

- (void)showPanel:(id) sender
{
	if (!aboutPanel) 
    { 
		[self setupPanel]; 
    }
	[aboutPanel setAlphaValue:0.0];
	[aboutPanel makeKeyAndOrderFront:nil];
	[fadeTimer invalidate];
	[fadeTimer release];
	fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:.05 
												  target:self 
												selector:@selector(fade:) 
												userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:0.0], @"opacity",
													[NSNumber numberWithFloat:.1], @"direction",
													nil] repeats:NO] retain];
}


- (void)hidePanel
{
	[fadeTimer invalidate];
	[fadeTimer release];
	
	fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:.05 
												  target:self 
												selector:@selector(fade:) 
												userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:1.0], @"opacity", 
													[NSNumber numberWithFloat:-.1],@"direction", 
													nil] repeats:NO] retain];
	//[aboutPanel orderOut:nil];
}


- (void)fade:(NSTimer *)timer
{
	float alphaValue = [[[timer userInfo] objectForKey:@"opacity"] floatValue];
	float fadeDirection = [[[timer userInfo] objectForKey:@"direction"] floatValue];
	[aboutPanel setAlphaValue:alphaValue];
	[fadeTimer invalidate];
	[fadeTimer release];
	
	if ( ( (alphaValue > 0 ) &&  ( fadeDirection < 0 ) )
		 || ( (alphaValue < 1)  && (fadeDirection > 0 ) ) )
    {
		fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:.02 
													  target:self 
													selector:@selector(fade:) 
													userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithFloat:alphaValue+fadeDirection], @"opacity", 
														[NSNumber numberWithFloat:fadeDirection], @"direction",
														nil] repeats:NO] retain];
    }
	else
    {
		fadeTimer = nil;
		//[aboutPanel setAlphaValue:1.0 - alphaValue];
		if (alphaValue <= 0) {
			[aboutPanel orderOut:nil];
		}
    }
}

- (void)mouseDown:(NSEvent *) event
{
	[self hidePanel];
}

@end
