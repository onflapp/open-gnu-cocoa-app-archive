/*
    PPBuildEnvironmentMacros.h

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

#   define _PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(DOT_VERSION)                \
            (defined(MAC_OS_X_VERSION_10_##DOT_VERSION)                         \
                && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_##DOT_VERSION))

#   define _PP_MAC_OS_X_DEPLOYMENT_TARGET_IS_AT_LEAST_10_(DOT_VERSION)          \
            (defined(MAC_OS_X_VERSION_10_##DOT_VERSION)                         \
                && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_##DOT_VERSION))



#   define PP_SDK_ALLOWS_NONASCII_STRING_LITERALS                               \
                                            (_PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(5))

#   define PP_SDK_DEPRECATED_NSMENUITEM_PROTOCOL                                \
                                            (_PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(5))

#   define PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES              \
                                            (_PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(6))

#   define PP_SDK_SUPPORTS_OBJC_RUNTIME_API_VERSION_2                           \
                                            (_PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(5))

#   define PP_SDK_DEFINES_TYPE_NSWINDOWSTYLEMASK                                \
                                            (_PP_MAC_OS_X_SDK_VERSION_IS_AT_LEAST_10_(12))


#   define PP_DEPLOYMENT_TARGET_DEPRECATED_CREATEDIRECTORYATPATHATTRIBUTES      \
                                            (_PP_MAC_OS_X_DEPLOYMENT_TARGET_IS_AT_LEAST_10_(5))

#   define PP_DEPLOYMENT_TARGET_DEPRECATED_REMOVEFILEATPATHHANDLER              \
                                            (_PP_MAC_OS_X_DEPLOYMENT_TARGET_IS_AT_LEAST_10_(5))

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_CARBON                                 (true)

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_COLOR_MANAGEMENT                       (true)

#   define PP_DEPLOYMENT_TARGET_DEPRECATED_KEYBOARDLAYOUT                       \
                                            (_PP_MAC_OS_X_DEPLOYMENT_TARGET_IS_AT_LEAST_10_(5))

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_APPLE_NSARCHIVER_FORMAT                (true)

#   define PP_DEPLOYMENT_TARGET_NSEVENT_DELTAY_RETURNS_FLIPPED_COORDINATE       (true)

#   define PP_DEPLOYMENT_TARGET_INCORRECTLY_FILLS_PIXEL_CENTERED_RECTS          (false)

#   ifdef __ppc__

#       define PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY                     (false)

#   else   // i386/x86_64

#       define PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY                     (true)

#   endif  // __ppc__


#elif defined(GNUSTEP)  // !defined(__APPLE__)

#   define PP_SDK_ALLOWS_NONASCII_STRING_LITERALS                               (false)

#   define PP_SDK_DEPRECATED_NSMENUITEM_PROTOCOL                                (false)

#   define PP_SDK_REQUIRES_PROTOCOLS_FOR_DELEGATES_AND_DATASOURCES              (true)

#   define PP_SDK_SUPPORTS_OBJC_RUNTIME_API_VERSION_2                           (true)

#   define PP_SDK_DEFINES_TYPE_NSWINDOWSTYLEMASK                                (false)


#   define PP_DEPLOYMENT_TARGET_DEPRECATED_CREATEDIRECTORYATPATHATTRIBUTES      (false)

#   define PP_DEPLOYMENT_TARGET_DEPRECATED_REMOVEFILEATPATHHANDLER              (false)

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_CARBON                                 (false)

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_COLOR_MANAGEMENT                       (false)

#   define PP_DEPLOYMENT_TARGET_DEPRECATED_KEYBOARDLAYOUT                       (false)

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_APPLE_NSARCHIVER_FORMAT                (false)

#   define PP_DEPLOYMENT_TARGET_NSEVENT_DELTAY_RETURNS_FLIPPED_COORDINATE       (false)

#   define PP_DEPLOYMENT_TARGET_INCORRECTLY_FILLS_PIXEL_CENTERED_RECTS          (true)

#   define PP_DEPLOYMENT_TARGET_SUPPORTS_RETINA_DISPLAY                         (false)

#endif  // defined(GNUSTEP)
