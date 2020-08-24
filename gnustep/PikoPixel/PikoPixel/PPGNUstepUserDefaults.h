/*
    PPGNUstepUserDefaults.h

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

//  Keys

#   define kGSUserDefaultsKey_UseRunningCopy                    @"NSUseRunningCopy"
#   define kGSUserDefaultsKey_SuppressAppIcon                   @"GSSuppressAppIcon"
#   define kGSUserDefaultsKey_AppOwnsMiniwindow                 @"GSAppOwnsMiniwindow"
#   define kGSUserDefaultsKey_ThemeName                         @"GSTheme"
#   define kGSUserDefaultsKey_InterfaceStyleName                @"NSInterfaceStyleDefault"

#   define kGSUserDefaultsKey_FirstControlKey                   @"GSFirstControlKey"
#   define kGSUserDefaultsKey_SecondControlKey                  @"GSSecondControlKey"
#   define kGSUserDefaultsKey_FirstAlternateKey                 @"GSFirstAlternateKey"
#   define kGSUserDefaultsKey_SecondAlternateKey                @"GSSecondAlternateKey"
#   define kGSUserDefaultsKey_FirstCommandKey                   @"GSFirstCommandKey"
#   define kGSUserDefaultsKey_SecondCommandKey                  @"GSSecondCommandKey"

//  Values

#   define kGSUserDefaultsValue_InterfaceStyleName_Windows95    @"NSWindows95InterfaceStyle"

#   define kGSUserDefaultsValue_ModifierKeyName_LeftCtrl        @"Control_L"
#   define kGSUserDefaultsValue_ModifierKeyName_RightCtrl       @"Control_R"
#   define kGSUserDefaultsValue_ModifierKeyName_LeftAlt         @"Alt_L"
#   define kGSUserDefaultsValue_ModifierKeyName_RightAlt        @"Alt_R"
#   define kGSUserDefaultsValue_ModifierKeyName_LeftSuper       @"Super_L"
#   define kGSUserDefaultsValue_ModifierKeyName_RightSuper      @"Super_R"

#endif  // GNUSTEP

