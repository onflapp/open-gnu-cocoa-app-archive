/*
    NSWindow_PPUtilities.m

    Copyright 2013-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X and GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#import "NSWindow_PPUtilities.h"

#import "PPGeometry.h"


#define kWindowAnimationBehavior_None           2   // value of NSWindowAnimationBehaviorNone
#define kIndexOfFirstInvocationMethodArgument   2


static NSInvocation *DisableAnimationBehaviorSharedInvocation(void);


@implementation NSWindow (PPUtilities)

- (void) ppMakeKeyWindowIfMain
{
    if ([self isMainWindow] && ![self isKeyWindow] && ![NSApp modalWindow])
    {
        [self makeKeyWindow];
    }
}

- (void) ppSetDocumentWindowTitlebarIcon: (NSImage *) iconImage
{
    NSButton *titlebarIconButton;
    NSSize buttonImageSize;
    NSImage *buttonImage;

    titlebarIconButton = [self standardWindowButton: NSWindowDocumentIconButton];

    if (!titlebarIconButton)
        return;

    buttonImageSize = [titlebarIconButton bounds].size;
    buttonImage = [[[NSImage alloc] initWithSize: buttonImageSize] autorelease];

    if (buttonImage && iconImage)
    {
        NSRect iconImageFrame, buttonBoundsForIconImage;

        iconImageFrame = PPGeometry_OriginRectOfSize([iconImage size]);

        buttonBoundsForIconImage =
            PPGeometry_ScaledBoundsForFrameOfSizeToFitFrameOfSize(iconImageFrame.size,
                                                                    buttonImageSize);

        if (!NSIsEmptyRect(buttonBoundsForIconImage))
        {
            [buttonImage lockFocus];

            [[NSGraphicsContext currentContext]
                                        setImageInterpolation: NSImageInterpolationHigh];

            [iconImage drawInRect: buttonBoundsForIconImage
                        fromRect: iconImageFrame
                        operation: NSCompositeCopy
                        fraction: 1.0f];

            [buttonImage unlockFocus];
        }
    }

    [titlebarIconButton setImage: buttonImage];
}

- (void) ppDisableOSXLionAnimationBehavior
{
    NSInvocation *disableAnimationBehaviorInvocation =
                                                DisableAnimationBehaviorSharedInvocation();

    if (disableAnimationBehaviorInvocation)
    {
        [disableAnimationBehaviorInvocation invokeWithTarget: self];
    }
}

@end

#pragma mark Private functions

static NSInvocation *DisableAnimationBehaviorSharedInvocation(void)
{
    static SEL setAnimationBehaviorSelector = NULL;
    static NSInvocation *disableAnimationBehaviorInvocation = nil;

    if (!setAnimationBehaviorSelector)
    {
        setAnimationBehaviorSelector = NSSelectorFromString(@"setAnimationBehavior:");

        if (!setAnimationBehaviorSelector)
            goto ERROR;
    }

    if (![NSWindow instancesRespondToSelector: setAnimationBehaviorSelector])
    {
        return nil;
    }

    if (!disableAnimationBehaviorInvocation)
    {
        NSMethodSignature *methodSignature;
        NSInteger animationBehaviorArgument;

        methodSignature =
                [NSWindow instanceMethodSignatureForSelector: setAnimationBehaviorSelector];

        if (!methodSignature)
            goto ERROR;

        disableAnimationBehaviorInvocation =
                    [[NSInvocation invocationWithMethodSignature: methodSignature] retain];

        if (!disableAnimationBehaviorInvocation)
            goto ERROR;

        animationBehaviorArgument = kWindowAnimationBehavior_None;

        [disableAnimationBehaviorInvocation setSelector: setAnimationBehaviorSelector];
        [disableAnimationBehaviorInvocation setArgument: &animationBehaviorArgument
                                            atIndex: kIndexOfFirstInvocationMethodArgument];
    }

    return disableAnimationBehaviorInvocation;

ERROR:
    return nil;
}
