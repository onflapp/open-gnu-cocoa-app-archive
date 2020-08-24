#import "PXPreviewController.h"
#import "PXCanvas.h"
#import "PXCanvasView.h"
#import "PXDocument.h"
#import "PXGrid.h"
#import "PXMonotoneBackground.h"
#import "PXCrosshair.h"
#import "PXPreviewResizeSizeView.h"

#ifndef __COCOA__
#include <math.h>
#endif

@implementation PXPreviewController

+ sharedPreviewController
{
  static id instance = nil;
  if(instance == nil) { instance = [[self alloc] init]; }
  return instance;
}

- (void)windowWillClose:notification
{
  if (!temporarilyHiding) {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PXPreviewWindowIsOpen"];
  }
}

- (void)documentClosed:(NSNotification *)notification
{
  if ([[notification object] canvas] == canvas) {
    [self setCanvas:nil];
  }
}

- init
{
  [super initWithWindowNibName:@"PXPreview"];
  [NSTimer scheduledTimerWithTimeInterval:0.5 
	   target:self selector:@selector(shouldRedraw:) 
	   userInfo:nil 
	   repeats:YES];
  updateRect = NSMakeRect(0,0,0,0);

  [[self window] setFrameAutosaveName:@"PXPreviewFrame"];
  resizeSizeWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 60, 27) 
				       styleMask:NSBorderlessWindowMask 
				       backing:NSBackingStoreBuffered 
				       defer:YES];
  [resizeSizeWindow setOpaque:NO];
  [resizeSizeWindow setContentView:[[[PXPreviewResizeSizeView alloc] 
				      initWithFrame:NSMakeRect(0, 0, 60, 27)]
				     autorelease]];

  [resizeSizeWindow setLevel:NSPopUpMenuWindowLevel];
  [[NSNotificationCenter defaultCenter]  addObserver:self 
					 selector:@selector(documentClosed:) 
					 name:PXDocumentClosed
					 object:nil];
  temporarilyHiding = NO;

  [(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];

  return self;
}

- (void)dealloc
{
  [fadeOutTimer invalidate];
  [fadeOutTimer dealloc];

  [resizeSizeWindow release];
  [[NSUserDefaults standardUserDefaults] setBool:([[self window] isVisible] || temporarilyHiding) forKey:@"PXPreviewWindowIsOpen"];

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

- (void)shouldRedraw:timer
{
  if (NSIsEmptyRect(updateRect)) 
    {
      NSLog(@"plop plop");
      return; 
    }

  if ([[self window] isVisible])
    {
      [view setNeedsDisplayInCanvasRect:updateRect];
      updateRect = NSZeroRect;
    }
}

- (void)windowDidLoad
{
  [[self window] setBackgroundColor:[NSColor lightGrayColor]];
  [view setMainBackground:[[[PXMonotoneBackground alloc] init] autorelease]];
  [view setAlternateBackground:[[[PXMonotoneBackground alloc] init] autorelease]];
  [view setCrosshair:nil];
  [[view grid] setShouldDraw:NO];
  if([[NSUserDefaults standardUserDefaults] boolForKey:@"PXPreviewWindowIsOpen"]) 
    {
      [[self window] display]; 
    }
  else 
    {
      [[self window] close]; 
    }
}

- (void)sizeToCanvas
{
  if (canvas == nil) 
    {
      [view setFrame:NSMakeRect(0,0,64,64)];
      return;
    }

  NSSize newSize = [[[self window] contentView] frame].size;
  NSPoint newOrigin = [view frame].origin;

  if ([canvas previewSize].width > 64)
    {
      newSize.width = [canvas previewSize].width;
      newOrigin.x = 0;
    }
  else
    {
      newSize.width = 64;
      newOrigin.x = (64 - [canvas previewSize].width) / 2;
    }
  if ([canvas previewSize].height > 64)
    {
      newSize.height = [canvas previewSize].height;
      newOrigin.y = 0;
    }
  else
    {
      newSize.height = 64;
      newOrigin.y = (64 - [canvas previewSize].height) / 2;
    }

  NSPoint topLeft = [[self window] frame].origin;
  topLeft.y += [[self window] frame].size.height;
  [[self window] setContentSize:newSize];
  [[self window] setFrameTopLeftPoint:topLeft];
  [view setFrameOrigin:newOrigin];
  [view setFrameSize:[canvas previewSize]];

  if ([canvas size].height > 0 
      && [canvas size].width > 0) {
    float ratio = MIN([canvas previewSize].height / [canvas size].height,
		      [canvas previewSize].width / [canvas size].width);
    if (ratio != 0) {
      [view setZoomPercentage:ratio * 100.0f];
    }
  }
  [[[self window] contentView] setNeedsDisplay:YES];
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
  if (canvas == nil || !([[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask)) 
    {
      return proposedFrameSize;
    }

  float titleBarSize = [sender frame].size.height - [[sender contentView] frame].size.height; // ewww hack
  float scaleFactor = roundf((proposedFrameSize.height - titleBarSize) / [canvas size].height);
  if (scaleFactor == 0) 
    {
      scaleFactor = 1;
    }
	
  NSSize newSize = [canvas size];
  newSize.height *= scaleFactor;
  newSize.width *= scaleFactor;
  newSize.height += titleBarSize;
  return newSize;
}

- (void)updateResizeSizeViewScale
{
  if (canvas == nil) 
    {
      return;
    }

/*[[[self window] contentView] frame].size.height / [canvas size].height*/

#ifdef __COCOA__
 [[resizeSizeWindow contentView] updateScale:[view zoomPercentage]/100];
#else
 NSLog(@"resizeSizeWindow %@",resizeSizeWindow);
 [[resizeSizeWindow contentView] updateScale:6.0];
#endif
  


	
  [resizeSizeWindow setContentSize:[[resizeSizeWindow contentView] scaleStringSize]];
	
  NSPoint newOrigin = [[self window] frame].origin;
  newOrigin.x += ([[[self window] contentView] frame].size.width - [resizeSizeWindow frame].size.width) / 2.0;
  newOrigin.y += ([[[self window] contentView] frame].size.height - [resizeSizeWindow frame].size.height) / 2.0;
  [resizeSizeWindow setFrameOrigin:newOrigin];
	
  [resizeSizeWindow setAlphaValue:1];
  [resizeSizeWindow orderFront:self];
	
  [fadeOutTimer invalidate];
  [fadeOutTimer release];
  fadeOutTimer = [[NSTimer scheduledTimerWithTimeInterval:1
			   target:self 
			   selector:@selector(fadeOutSize:)
			   userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:.95] forKey:@"opacity"] repeats:NO] retain];



}

- (void)fadeOutSize:(NSTimer *)timer
{
  float alphaValue = [[[timer userInfo] objectForKey:@"opacity"] floatValue];
  [resizeSizeWindow setAlphaValue:alphaValue];
  [fadeOutTimer invalidate];
  [fadeOutTimer release];
  if (alphaValue > 0) 
    {
      fadeOutTimer = [[NSTimer scheduledTimerWithTimeInterval:.05
			       target:self
			       selector:@selector(fadeOutSize:) 
			       userInfo:[NSDictionary dictionaryWithObject:
							[NSNumber numberWithFloat:alphaValue-.1] forKey:@"opacity"] repeats:NO] retain];
  } 
  else 
    {
      fadeOutTimer = nil;
    }
}

- (void)windowDidResize:(NSNotification *)aNotification
{
  NSLog(@"windowDidResize canvas %@",canvas);
  if (canvas == nil) 
    return;
  
  NSLog(@"==========> Size %@",NSStringFromSize( [[[self window] contentView] frame].size) );
  [canvas setPreviewSize:[[[self window] contentView] frame].size];
  [self sizeToCanvas];
  [self updateResizeSizeViewScale];
}

- (void)initializeWindow
{
#ifdef __COCOA__
  [[self window] setContentAspectRatio:[canvas size]];
#else
  [[self window] setResizeIncrements:NSMakeSize(1.0,1.0)];
#endif
  [self sizeToCanvas];
  [view setCanvas:canvas]; 
  [[view grid] setShouldDraw:NO];
  float titleBarSize = [[self window] frame].size.height - [[[self window] contentView] frame].size.height;
  [[self window] setMinSize:NSMakeSize(64, 64 + titleBarSize)];
}

- (IBAction)showWindow:sender
{
  [super showWindow:sender];
  [self initializeWindow];
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PXPreviewWindowIsOpen"];
}

- (void)setCanvas:aCanvas
{
  //we have to do all this no matter what so there aren't inconsistency-bugs
  [view setCanvas:nil];
  [view display];
  [[NSNotificationCenter defaultCenter] removeObserver:self 
					name:PXCanvasChangedNotificationName 
					object:canvas];
  canvas = aCanvas;
  if (aCanvas == nil) 
    {
      if ([[self window] isVisible]) 
	{
	  temporarilyHiding = YES;
	  [[self window] close];
	}
    } 
  else 
    {
      [[NSNotificationCenter defaultCenter] addObserver:self 
					    selector:@selector(canvasDidChange:) 
					    name:PXCanvasChangedNotificationName 
					    object:canvas];
    }
  if ((temporarilyHiding && aCanvas != nil) 
      || [[self window] isVisible]) 
    {
      temporarilyHiding = NO;
      [self showWindow:self];
      //[[self window] display];
      [self updateResizeSizeViewScale];
    }
}

- (void)canvasDidChange:aNotification
{
  if ([[self window] isVisible])
    {
      updateRect = NSUnionRect(updateRect, [[[aNotification userInfo] objectForKey:@"changedRect"] rectValue]);
    }
}

@end
