#import  "RotateCtr.h"
#import  "RotateView.h"
#import  <Foundation/NSString.h>
#import  <math.h>
#import  <AppKit/NSImage.h>
#import  <AppKit/NSControl.h>
#import  <AppKit/NSTextField.h>
#import  <AppKit/NSButton.h>
#import  <AppKit/NSStepper.h>
#import  "../common.h"
#import  "../ImageOpCtr.h"
#import  "ImageOpr.h"

@implementation RotateCtr

- (int)intValue:(id)sender { return (int)value; }
- (int)floatValue:(id)sender { return value; }

- (void)changeValue:(id)sender
{
	value = [angleSlider intValue];
	[rotView setAngle:(int)value];
	[angleText setIntValue:(int)value];
	[angleStepper setIntValue:(int)value];
}

- (void)adjustValue:(id)sender
{
	value = [angleStepper floatValue];
	[rotView setAngle:(int)value];
	[angleText setStringValue:
		[NSString stringWithFormat:@"%.1f", value]];
	[angleSlider setFloatValue:value];
}

- (void)writenAngle:(id)sender
{
	float angle = [angleText floatValue];
	while (angle < -180.0) angle += 360.0;
	while (angle >= 180.0) angle -= 360.0;
	value = angle;
	[rotView setAngle: (int)value];
	[angleSlider setFloatValue:value];
	[angleStepper setFloatValue:value];
	[angleText selectText:self];
}

- (void)doit:(id)sender
{
	float	angle;
	int	a16;
	id	op;

	[self writenAngle:self];
	if (value == 0.0) {
	  // NSBeep(); //TODO > GNUStep Where is define NSBeep()
	  return;
	}
	if ((angle = value) < 0)
		angle += 360.0;
	a16 = (int)(angle * 16.0);
	angle = a16 / 16.0;
	op = [[ImageOpr alloc] init];
	if ([smoothSW state] && (a16 % (90*16)) != 0)
		[op doRotateFlipClip:SmoothRotation to:angle];
	else
		[op doRotateFlipClip:Rotation to:angle];
	[op release];
}

@end
