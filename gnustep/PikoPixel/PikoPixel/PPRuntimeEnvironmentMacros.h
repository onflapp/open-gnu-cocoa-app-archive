/*
    PPRuntimeEnvironmentMacros.h

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

#if defined(__APPLE__)


#   import <Foundation/Foundation.h>

#   ifndef NSFoundationVersionNumber10_5
#       define NSFoundationVersionNumber10_5    677.00
#   endif

#   ifndef NSFoundationVersionNumber10_6
#       define NSFoundationVersionNumber10_6    751.00
#   endif

#   ifndef NSFoundationVersionNumber10_7
#       define NSFoundationVersionNumber10_7    833.10
#   endif

#   ifndef NSFoundationVersionNumber10_8
#       define NSFoundationVersionNumber10_8    945.00
#   endif

#   ifndef NSFoundationVersionNumber10_10
#       define NSFoundationVersionNumber10_10   1151.00
#   endif

#   ifndef NSFoundationVersionNumber10_10_3
#       define NSFoundationVersionNumber10_10_3 1153.20
#   endif

#   ifndef NSFoundationVersionNumber10_12
#       define NSFoundationVersionNumber10_12   1300.00
#   endif


#   define _PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(DOT_VERSION)             \
                (NSFoundationVersionNumber >= NSFoundationVersionNumber10_##DOT_VERSION)

#   define _PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(DOT_VERSION)         \
                (NSFoundationVersionNumber < NSFoundationVersionNumber10_##DOT_VERSION)


#   define PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_OBJC_RUNTIME_API_VERSION_2                \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(5))

#   define PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_BOTTOM_SQUARE_BRACKET_UNICODE_CHAR        \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(5))

#   define PP_RUNTIME_CHECK__RUNTIME_INTERCEPTS_INACTIVE_MENUITEM_KEY_EQUIVALENTS       \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(5))

#   define PP_RUNTIME_CHECK__RUNTIME_REQUIRES_MANUAL_SETUP_OF_AUTOSAVE_FILE_EXTENSIONS  \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(5))

#   define PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_RETINA_DISPLAY                            \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(7))

#   define PP_RUNTIME_CHECK__RUNTIME_OVERRIDES_CURSOR_WHEN_DRAGGING_OVER_RESIZABLE_WINDOW_EDGES \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_AT_LEAST_10_(7))

#   define PP_RUNTIME_CHECK__RUNTIME_ROUNDS_OFF_SUBPIXEL_MOUSE_COORDINATES              \
                (_PP_RUNTIME_CHECK__MAC_OS_X_VERSION_IS_EARLIER_THAN_10_(8))


#elif defined(GNUSTEP)  // !defined(__APPLE__)


#   define PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_OBJC_RUNTIME_API_VERSION_2                (true)

#   define PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_BOTTOM_SQUARE_BRACKET_UNICODE_CHAR        (true)

#   define PP_RUNTIME_CHECK__RUNTIME_INTERCEPTS_INACTIVE_MENUITEM_KEY_EQUIVALENTS       (true)

#   define PP_RUNTIME_CHECK__RUNTIME_REQUIRES_MANUAL_SETUP_OF_AUTOSAVE_FILE_EXTENSIONS  (false)

#   define PP_RUNTIME_CHECK__RUNTIME_SUPPORTS_RETINA_DISPLAY                            (false)

#   define PP_RUNTIME_CHECK__RUNTIME_OVERRIDES_CURSOR_WHEN_DRAGGING_OVER_RESIZABLE_WINDOW_EDGES \
                                                                                        (false)

#   define PP_RUNTIME_CHECK__RUNTIME_ROUNDS_OFF_SUBPIXEL_MOUSE_COORDINATES              (false)


#endif  // defined(GNUSTEP)
