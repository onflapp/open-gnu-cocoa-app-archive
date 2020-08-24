/*
    PPGNUstepGlue_DocumentSheets.m

    Copyright 2014-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for GNUstep.
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

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPDocumentSheetController.h"

// Sheet header textfields that are the minimum correct size on OS X can crop their text
// when displayed on GNUstep (bold system-font on GS is slightly bigger?), so manually increase
// header textfield width

#define kSheetHeaderTextFieldWidthPadding   25


@implementation NSObject (PPGNUstepGlue_DocumentSheets)

+ (void) ppGSGlue_DocumentSheets_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocumentSheetController, initWithNibNamed:delegate:,
                                ppGSPatch_InitWithNibNamed:delegate:);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_DocumentSheets_InstallPatches);
}

@end

@implementation PPDocumentSheetController (PPGNUstepGlue_DocumentSheets)

- ppGSPatch_InitWithNibNamed: (NSString *) nibName delegate: (id) delegate
{
    self = [self ppGSPatch_InitWithNibNamed: nibName delegate: delegate];

    if (self)
    {
        NSArray *controlViews = [[_sheet contentView] subviews];
        NSEnumerator *controlViewsEnumerator = [controlViews objectEnumerator];
        NSView *controlView;
        Class textFieldClass = [NSTextField class];

        while (controlView = [controlViewsEnumerator nextObject])
        {
            if ([controlView isKindOfClass: textFieldClass])
            {
                NSRect controlFrame = [controlView frame];

                controlFrame.size.width += kSheetHeaderTextFieldWidthPadding;

                [controlView setFrame: controlFrame];
            }
        }

        [_sheet setTitle: @""];
    }

    return self;
}

@end

#endif  // GNUSTEP

