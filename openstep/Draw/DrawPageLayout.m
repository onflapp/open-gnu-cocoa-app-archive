#import "draw.h"

@implementation DrawPageLayout
/*
 * PageLayout is overridden so that the user can set the margins of
 * the page.  This is important in a Draw program where the user
 * typically wants to maximize the drawable area on the page.
 *
 * The accessory view is used to add the additional fields, and
 * pickedUnits: is overridden so that the margin is displayed in the
 * currently selected units.  Note that the accessoryView is set
 * in InterfaceBuilder using the outlet mechanism!
 *
 * This can be used as an example of how to override Application Kit panels.
 */

#ifdef WIN32
- (void)convertOldFactor:(float *)oldf newFactor:(float *)newf
{
    if (oldf) *oldf = 1.0;
    if (newf) *newf = 1.0;
}
#endif

- (void)pickedUnits:(id)sender
/*
 * Called when the user selects different units (e.g. cm or inches).
 * Must update the margin fields.
 */
{
    float oldm, newm;

    [self convertOldFactor:&oldm newFactor:&newm];
    [leftMargin setFloatValue:newm * [leftMargin floatValue] / oldm];
    [rightMargin setFloatValue:newm * [rightMargin floatValue] / oldm];
    [topMargin setFloatValue:newm * [topMargin floatValue] / oldm];
    [bottomMargin setFloatValue:newm * [bottomMargin floatValue] / oldm];
#ifndef WIN32
    [super pickedUnits:sender];
#endif
}

- (void)readPrintInfo
/*
 * Sets the margin fields from the panel's PrintInfo.
 */
{
    NSPrintInfo *pi;
    float conversion, dummy;

    [super readPrintInfo];
    pi = [self printInfo];
    [self convertOldFactor:&conversion newFactor:&dummy];
    [leftMargin setFloatValue:[pi leftMargin] * conversion];
    [rightMargin setFloatValue:[pi rightMargin] * conversion];
    [topMargin setFloatValue:[pi topMargin] * conversion];
    [bottomMargin setFloatValue:[pi bottomMargin] * conversion];
}

- (void)writePrintInfo
/*
 * Sets the margin values in the panel's PrintInfo from
 * the margin fields in the panel.
 */
{
    NSPrintInfo *pi;
    float conversion, dummy;

    [super writePrintInfo];
    pi = [self printInfo];
    [self convertOldFactor:&conversion newFactor:&dummy];
    if (conversion) {
	[pi setLeftMargin:[leftMargin floatValue] / conversion];
	[pi setRightMargin:[rightMargin floatValue] / conversion];
	[pi setTopMargin:[topMargin floatValue] / conversion];
	[pi setBottomMargin:[bottomMargin floatValue] / conversion];
    }
}

/* outlet setting methods */

- (void)setTopBotForm:anObject
{
    topMargin = [anObject cellWithTag:5];
    bottomMargin = [anObject cellWithTag:6]; 
}

- (void)setSideForm:anObject
{
    leftMargin = [anObject cellWithTag:3];
    rightMargin = [anObject cellWithTag:4]; 
}

@end

