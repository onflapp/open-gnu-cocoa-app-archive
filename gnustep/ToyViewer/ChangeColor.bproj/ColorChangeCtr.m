#import  "ColorChangeCtr.h"
#import  <AppKit/NSColorWell.h>
#import  <AppKit/NSColor.h>
#import  "ColorChanger.h"
#import  "../ImageOpCtr.h"
#import  "../common.h"

@implementation ColorChangeCtr

- (void)changeAlpha:(id)sender
{
	NSColorWell *well;

	well = (NSColorWell *)(([sender selectedTag] == 0)
					? origWell : newWell);
	[well setEnabled:![sender state]];
	[methodMenu setEnabled:(![origAlpha state] && ![newAlpha state])];
}

/* Local Method */
- (void)getfrom:(NSColorWell *)well : (id)alphastat colors:(int *)color
{
	int i;
	float cl[MAXPLANE];

	if ([alphastat state]) {
		for (i = 0; i < 3; i++)
			color[i] = 255;
		color[ALPHA] = AlphaTransp;
	}else {
		id colobj = [[well color]
			colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
		[colobj getRed:&cl[0] green:&cl[1] blue:&cl[2] alpha:NULL];
		for (i = 0; i < 3; i++)
			color[i] = cl[i] * 255;
		color[ALPHA] = AlphaOpaque;
	}
}

- (void)doit:(id)sender
{
	int	origclr[MAXPLANE], newclr[MAXPLANE];
	int	methodid;
	id	changer;

	changer = [[[ColorChanger alloc] init] autorelease];
	if (changer == nil)
		return;

	[self getfrom:origWell : origAlpha colors:origclr];
	[self getfrom:newWell : newAlpha colors:newclr];

	methodid = ([methodMenu isEnabled])
		? [methodMenu indexOfSelectedItem] : cnv_Uniq;
	[changer setColor:origclr to:newclr
		method:methodid with:[comparison floatValue]];
	[changer setOutside:[whichside selectedTag]];
	[changer createNewImage];
}


@end
