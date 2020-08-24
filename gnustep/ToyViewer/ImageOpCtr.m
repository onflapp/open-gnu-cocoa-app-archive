#import "ImageOpCtr.h"
#import <Foundation/NSString.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSUserDefaults.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSTabView.h>
#import <AppKit/NSTabViewItem.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import "TVController.h"
#import "ToyWin.h"
#import "ToyWinEPS.h"
#import "ToyView.h"
#import "common.h"
#import "BundleLoader.h"
#import "ImgToolCtrlAbs.h"
#import "getpixel.h"
#import "strfunc.h"
#import "ImageOpr.bproj/ImageOpr.h"
#import "ImageOpr.bproj/MonoCtr.h"
#import "ImageOpr.bproj/SmResizeCtr.h"
#import "Reduction.bproj/ImageReduce.h"
#import "Resize.bproj/ImageResize.h"
#import "Enhance.bproj/EnhanceCtr.h"
#import "Noise.bproj/NoiseCtr.h"

#define ToolPanelName @"ToolPanel"

static ImgToolCtrlAbs *toolsObj[MAX_TAG];	/* all nil */

static int ops2tag(int op)
{
	int tag = 0;

	switch (op) {
	case NoOperation:
	case FromPasteBoard:	break;

	case Rotation:
	case SmoothRotation:	tag = 0; break;

	case Monochrome:
	case BiLevel:
	case Brightness:	tag = 1; break;

	case SmoothResize:
	case SimpleResize:	tag = 2; break;

	case Reduction:		tag = 3; break;
	case ColorTone:		tag = 4; break;
	case Enhance:
	case Blur:		tag = 5; break;
	case ColorChange:	tag = 6; break;
	case RandomPttn:	tag = 7; break;
	case SoftFrame:		tag = 8; break;
	case Posterize:		tag = 9; break;

	case Emboss:
	case Contour:		tag = 10; break;

	default:		tag = -1; break;
	}
	return tag;
}

static int tag2ops[] = {
	Rotation, Monochrome, SmoothResize, Reduction, ColorTone,
	Enhance, ColorChange, RandomPttn, SoftFrame, Posterize,
	Contour
};


@implementation ImageOpCtr

/* Local Class Method */
+ (id)loadToolAndUI:(int)idx
{
	static NSString *toolsUI[] = {
		nil, nil, nil, nil,
		@"ColorTune",
		@"Enhance",
		@"ColorChange",
		@"Noise",
		@"SoftFrame",
		@"Posterize",
		nil /* Contour */
	};
	static int toolsBundleID[] = {
		0, 0, 0, 0,
		bt_ColorTune,
		bt_Enhance,
		bt_ColorChange,
		bt_Noise,
		bt_SoftFrame,
		bt_Posterize,
		0
	};
	NSLog(@"load tool & UI %i",idx);

	if (toolsObj[idx] != nil)
	  return toolsObj[idx];

	/* Load "*.bundle" */
	toolsObj[idx] = [BundleLoader loadAndNew:toolsBundleID[idx]];
	if (toolsObj[idx] == nil)
		return nil;
	if (toolsUI[idx]) {
	  if (! [NSBundle loadNibNamed:toolsUI[idx] owner:toolsObj[idx]] )
	  {
	    NSLog(@"Not Load");
	  }
	  else 
	  {
	    NSLog(@"Load");
	  }
	}

	return toolsObj[idx];
}


- (id)init
{
	int i;

	[super init];
	currentTab = -1;
	for (i = 0; i < MAX_TAG; i++)
		tag2control[i] = nil;
	return self;
}

/* Local Method */
- (id)loadBundle
{
	static id classImgOp = nil;

	if (classImgOp && imageOpr)
		return self;
	/* Load "ImageOpr.bundle" */
	classImgOp = [BundleLoader loadClass:b_ImageOpr];
	if (classImgOp == nil) /* ERROR */
		return nil;
	imageOpr = [[classImgOp alloc] init];
	return self;
}


/*  If you want to send message to the controller object when its
    tool panels is displayed, set it as the delegate of the panel
    using Interface Builder.
    It is stored in 'tag2control[]', and ImageOpCtr sends 'setup:'
    message when its panel(view) is opened.
 */

/* Local Method */
- (void)setTool:(NSPanel *)tp index:(int)idx
{
	id dg;
	[[toolView tabViewItemAtIndex:idx] setView:[tp contentView]];
	if ((dg = [tp delegate]) != nil) {
		tag2control[idx] = dg;
		[tp setDelegate: nil];
	}
}

#define  IsIsolatedTag(tag)	((tag) >= 4)

/* Local Method */
- (id)loadNib:(int)op
{
	int	tag,i;
	NSLog(@"op %i",op);
	if (monoPanel == nil) {
		[NSBundle loadNibNamed:@"ImageOpr" owner:self];
		//workaround for GNUstep (waiting for a better Gorm )
		[toolView removeTabViewItem:[toolView tabViewItemAtIndex:1]];
		[toolView removeTabViewItem:[toolView tabViewItemAtIndex:0]];
		for(i=0;i<11;i++)
		  [toolView insertTabViewItem:[[NSTabViewItem alloc] initWithIdentifier:[NSString stringWithFormat:@"%i",i]] atIndex:i];
		//END Workaround
		(void)[toolPanel setFrameUsingName: ToolPanelName];
		[self setTool:rotatePanel index:0];
		[self setTool:monoPanel index:1];
		[self setTool:resizePanel index:2];
		[self setTool:reducePanel index:3];
	}
	if ((op == NoOperation || op == FromPasteBoard) && currentTab == -1)
		op = Monochrome;
 	tag = ops2tag(op);
	if (tag < 0)
	  return nil;

	if ( tag2ops[tag] == Contour )
	  NSLog(@"Contour");

	if (tag2ops[tag] == Contour && toolsObj[tag] == nil) {	/* Contour */
	  int ex = ops2tag(Enhance);
	  NSLog(@"YAYAYYAYA");
	  if (toolsObj[ex] == nil) {
	    [[self class] loadToolAndUI: ex];
	    [[toolView tabViewItemAtIndex: ex] setView:[toolsObj[ex] controllerView]];
	    
	  }

	  toolsObj[tag] = [(EnhanceCtr *)toolsObj[ex] contourCtrl];
	  [[toolView tabViewItemAtIndex: tag]
	    setView:[toolsObj[tag] controllerView]];
	}
	else if (IsIsolatedTag(tag) && toolsObj[tag] == nil) {
	  [[self class] loadToolAndUI: tag];
	  NSLog(@"[toolsObj[tag] controllerView] %@",[toolsObj[tag] controllerView]);
	  [[toolView tabViewItemAtIndex: tag] setView:[toolsObj[tag] controllerView]];
	}
	if (currentTab != tag) {
	  NSLog(@"====>op %i tag %i",op,tag);
	  [toolView selectTabViewItemAtIndex:tag];
	  [toolButton selectItemAtIndex:tag];
	  currentTab = tag;
	  [toolPanel display];
	}
	[toolPanel display];
	[tag2control[tag] setup:self];
	[toolPanel makeKeyAndOrderFront:self];
	[toolPanel setFloatingPanel:YES];
	return self;
}

- (void)loadNewTool:(id)sender
{
  //#ifdef __APPLE__ // or GNUStep :)
	[self loadNib: tag2ops[ [sender tag] ]];
	//#else
	//	[self loadNib: tag2ops[ [sender selectedTag] ]];
	//#endif
}

- (void)activateToolPanel:(id)sender
{
	int tag = [sender tag];
	[self loadBundle];
	[self loadNib: tag2ops[tag]]; 
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[self loadBundle];
	if ([imageOpr respondsToSelector:[anInvocation selector]])
		[anInvocation invokeWithTarget:imageOpr];
	else
		[self doesNotRecognizeSelector:[anInvocation selector]];
}

- (void)saveData {
	[toolPanel saveFrameUsingName: ToolPanelName];
}

- (void)rotateByAngle:(id)sender
{
	static int tagAngles[] = { 0, 90, 270, 180 };
	int tag;

	[self loadBundle];
	tag = [sender tag];
	if (tag == 0) {
		[self loadNib: Rotation];
		return;
	}
	[imageOpr doRotateFlipClip:Rotation to:tagAngles[tag]];
}

- (void)flip:(id)sender
{
	static int flipkind[] = { Horizontal, Vertical, Clip, Negative };

	[self loadBundle];
	[imageOpr doRotateFlipClip:flipkind[[sender tag]] to:0];
}

- (void)readyForResize:(id)sender
{
	[self loadBundle];
	[self loadNib: SmoothResize];
}

- (void)newBitmap:(id)sender
{
	id	resize;

	[self loadBundle];
	[self loadNib: SmoothResize];
	resize = [BundleLoader loadAndNew: b_Resize];
	[resize newBitmapWith: 1.0];	/* 100% */
	[resize release];
}

- (void)reduce:(id)sender
{
	id reduce;

	[self loadBundle];
	reduce = [BundleLoader loadAndNew: b_Reduction];
	[reduce reduce:self];
	[reduce release];
}

- (void)doResize:(id)sender by:(int)op;
{
	int	a, b;
	float	f;
	id	resize;

	resize = [BundleLoader loadAndNew: b_Resize];
	switch (op) {
	case NewBitmap: /* EPS -> Bitmap */
		[sender getFactor:&f];
		[resize newBitmapWith: f];
		break;
	case ResizeEPS:
		[sender getFactor:&f];
		[resize EPSResizeWith: f];
		break;
	case SmoothResize:
		[sender getRatio:&b :&a];
		if (a <= 0)
			break;	/* Error? */
		[resize smoothResizeWith: b : a];
		break;
	case SimpleResize:
		[sender getFactor:&f];
		[resize simpleResizeWith: f];
		break;
	}
	[resize release];
}

- (void)convertCMYKtoRGB:(id)sender
{
	[self loadBundle];
	[imageOpr convertCMYKtoRGB:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
	return [theController hasWindow];
}

@end
