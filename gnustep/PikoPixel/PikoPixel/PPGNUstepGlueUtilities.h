/*
    PPGNUstepGlueUtilities.h

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

#import <Foundation/Foundation.h>


// Window manager type masks

#define kPPGSWindowManagerTypeMask_Budgie       (1 << 0)    // Budgie
#define kPPGSWindowManagerTypeMask_Compiz       (1 << 1)    // Unity
#define kPPGSWindowManagerTypeMask_Gala         (1 << 2)    // Pantheon
#define kPPGSWindowManagerTypeMask_KWin         (1 << 3)    // KDE
#define kPPGSWindowManagerTypeMask_Marco        (1 << 4)    // MATE
#define kPPGSWindowManagerTypeMask_Muffin       (1 << 5)    // Cinnamon
#define kPPGSWindowManagerTypeMask_Mutter       (1 << 6)    // GNOME Shell
#define kPPGSWindowManagerTypeMask_Openbox      (1 << 7)    // LXDE
#define kPPGSWindowManagerTypeMask_WindowMaker  (1 << 8)    // WindowMaker
#define kPPGSWindowManagerTypeMask_Xfwm         (1 << 9)    // Xfce


bool PPGSGlueUtils_WindowManagerMatchesTypeMask(unsigned typeMatchMask);

bool PPGSGlueUtils_PerformNSUserDefaultsSelectorBeforeGSBackendLoads(SEL selector);

bool PPGSGlueUtils_PerformPPScreencastControllerSelectorOnEnableOrDisable(SEL selector);


@interface NSUserDefaults (PPGNUstepGlueUtilities)

+ (bool) ppGSGlueUtils_RegisterDefaultsFromDictionaryNamed: (NSString *) dictionaryName;

@end

#endif  // GNUSTEP

