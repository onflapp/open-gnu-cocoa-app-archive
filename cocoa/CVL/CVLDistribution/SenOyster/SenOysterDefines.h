/*$Id: SenOysterDefines.h,v 1.3 2001/03/29 08:25:31 stephane Exp $*/

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#if defined(WIN32)
    #undef SENOYSTER_EXPORT
    #if defined(BUILDINGSENOYSTER)
    #define SENOYSTER_EXPORT __declspec(dllexport) extern
    #else
    #define SENOYSTER_EXPORT __declspec(dllimport) extern
    #endif
    #if !defined(SENOYSTER_IMPORT)
    #define SENOYSTER_IMPORT __declspec(dllimport) extern
    #endif
#endif

#if !defined(SENOYSTER_EXPORT)
    #define SENOYSTER_EXPORT extern
#endif

#if !defined(SENOYSTER_IMPORT)
    #define SENOYSTER_IMPORT extern
#endif

#if !defined(SENOYSTER_STATIC_INLINE)
#define SENOYSTER_STATIC_INLINE static __inline__
#endif

#if !defined(SENOYSTER_EXTERN_INLINE)
#define SENOYSTER_EXTERN_INLINE extern __inline__
#endif
