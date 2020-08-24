/*
 * vhfCompatibility.h
 *
 * Copyright (C) 2000-2013 by vhf interservice GmbH
 * Author:   Georg Fleischmann
 *
 * created:  2000-04-01
 * modified: 2013-04-10 (VHFIsDrawingToScreen(): workaround for GNUstep Cairo backend)
 *           2013-01-24 (use sel_isEqual() instead of sel_eq())
 *           2012-01-06 (CGFloat, NSInteger)
 *           2010-02-13 (NSAppKitVersionNumber##_# for Apple)
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_COMPATIBILITY
#define VHF_H_COMPATIBILITY

#include <AppKit/AppKit.h>
#include "types.h"

/* GNUstep
 */
#if defined( GNUSTEP_BASE_VERSION )

//#   define VHFIsDrawingToScreen()	( [[NSGraphicsContext currentContext] isDrawingToScreen] )
static __inline__ BOOL VHFIsDrawingToScreen()
{   NSGraphicsContext   *gc = [NSGraphicsContext currentContext];
    return ( [gc isDrawingToScreen] ||
             [[[gc attributes] valueForKey:@"NSDeviceIsScreen"] hasPrefix:@"Y"] );  // 2013-04-10, workaround: Cairo
}
#   define VHFSelectorIsEqual(a, b)	sel_isEqual(a, b)
//#   define VHFSelectorIsEqual(a, b)	sel_eq(a, b)
#   define VHFAntialiasing()		[[NSGraphicsContext currentContext] shouldAntialias]
#   define VHFSetAntialiasing(f)	[[NSGraphicsContext currentContext] setShouldAntialias:f]
#   define PSWait()                 [[NSGraphicsContext currentContext] flushGraphics]

/* MAC OS X
 */
#elif defined ( __APPLE__ )

#   define VHFIsDrawingToScreen()	[[NSGraphicsContext currentContext] isDrawingToScreen]
//#   define VHFSelectorIsEqual(a, b)	sel_isEqual(a, b)   // same as '=='
#   define VHFSelectorIsEqual(a, b)	a == b
#   define VHFAntialiasing()		[[NSGraphicsContext currentContext] shouldAntialias]
#   define VHFSetAntialiasing(f)	[[NSGraphicsContext currentContext] setShouldAntialias:f]
#   define PSWait()                 [[NSGraphicsContext currentContext] flushGraphics]
#   define PSgsave()                [NSGraphicsContext saveGraphicsState]
#   define PSgrestore()             [NSGraphicsContext restoreGraphicsState]
static __inline__ void PScomposite(float x, float y, float w, float h, int gstateNum, float dx, float dy, int op)	{ }
/* add definitions missing in OS X 10.4 (2012-01-06) */
//#   ifndef CGFloat
#   if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
#       if __LP64__ || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
            typedef long            NSInteger;
            typedef unsigned long   NSUInteger;
            typedef double          CGFloat;
#       else
            typedef int             NSInteger;
            typedef unsigned int    NSUInteger;
            typedef float           CGFloat;
#       endif
#   endif

// for runtime version checks use if (NSAppKitVersionNumber ><= ):
#   ifndef NSAppKitVersionNumber10_4
#       define NSAppKitVersionNumber10_4 824
#   endif
#   ifndef NSAppKitVersionNumber10_5
#       define NSAppKitVersionNumber10_5 949
#   endif
#   ifndef NSAppKitVersionNumber10_6
#       define NSAppKitVersionNumber10_6 1038
#   endif
#   ifndef NSAppKitVersionNumber10_7
#       define NSAppKitVersionNumber10_7 1138
#   endif
#   ifndef NSAppKitVersionNumber10_8
#       define NSAppKitVersionNumber10_8 1187
#   endif

// for compile time version checks use:
// #if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
// MAC_OS_X_VERSION_MIN_REQUIRED

/* OpenStep
 */
#else

#    include <NSBezierPath.h>
//#    include <AppKit/psops.h>
#    define VHFIsDrawingToScreen()	[[NSDPSContext currentContext] isDrawingToScreen]
#    define VHFSelectorIsEqual(a, b)	a == b
#    define VHFAntialiasing()		NO
#    define VHFSetAntialiasing(f)	
#    define NSGraphicsContext		NSDPSContext
#    define NSBackspaceCharacter	NSBackspaceKey
#    define NSDeleteCharacter		NSDeleteKey

#endif

#endif // VHF_H_COMPATIBILITY
