/*$Id: SenUtilities.h,v 1.10 2003/07/25 16:07:44 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import "SenFoundationDefines.h"
#import "SenAssertion.h"

// Defining ASSIGN and RETAIN.
//
// ASSIGN should be used in -set... methods instead of the Apple 
// promoted pattern (autorelease / retain). It is faster and 
// semantically more correct.
// ___newVal is to avoid multiple evaluations of val.
// RETAIN is deprecated and should not used.

#if defined (GNUSTEP)
// GNUstep has its own definitions of ASSIGN and RETAIN
#else
    #define RETAIN(var,val) \
    ({ \
        id ___newVal = (val); \
        id ___oldVar = (var); \
        if (___oldVar != ___newVal) { \
            if (___newVal != nil) { \
                [___newVal retain]; \
            } \
            var = ___newVal; \
            if (___oldVar != nil) { \
                [___oldVar release]; \
            } \
        } \
    })
    
    #if defined(GARBAGE_COLLECTION)
        #define ASSIGN(var,val) \
        ({ \
            var = val; \
        })
    #else
        #define ASSIGN RETAIN
    #endif
#endif

// Defining CHANGE_ASSIGN and CHANGE_RETAIN.
//
// Like ASSIGN above, CHANGE_ASSIGN should be used in -set... methods 
// instead of the Apple promoted pattern (autorelease / retain).
// CHANGE_ASSIGN sends willChange to self, but only if the variable 
// is really changed.
// CHANGE_RETAIN is deprecated and should not used.

@protocol Changes
- (void) willChange;
@end

#define SELF_WILL_CHANGE ({ \
        [(id <Changes>) self willChange]; \
})


#define CHANGE_RETAIN(var,val) ({ \
    id ___newVal = (val); \
    id ___oldVar = (var); \
    if (___oldVar != ___newVal) { \
        SELF_WILL_CHANGE; \
        if (___newVal != nil) { \
            [___newVal retain]; \
        } \
        var = ___newVal; \
        if (___oldVar != nil) { \
            [___oldVar release]; \
        } \
    } \
})

#if defined(GARBAGE_COLLECTION)
    #define CHANGE_ASSIGN(var,val) \
    ({ \
        SELF_WILL_CHANGE; \
        var = val; \
    })
#else
    #define CHANGE_ASSIGN  CHANGE_RETAIN 
#endif

// Defining RELEASE.
//
// The RELEASE macro can be used in any place where a release 
// message would be sent. VAR is released and set to nil
#if defined (GNUSTEP)
// GNUstep has its own macro.
#else
    #if defined(GARBAGE_COLLECTION)
        #define RELEASE(var)
    #else
        #define RELEASE(var) \
        ({ \
            id	___oldVar = (id)(var); \
            if (___oldVar != nil) { \
                var = nil; \
                [___oldVar release]; \
            } \
        })
    #endif
#endif


// Protected type casting
#define AsKindOfClass(_class,_object) \
({ \
    id _val = (_object); \
    senassert((_val == nil) || [_val isKindOfClass:[_class class]]); \
    (_class *) _val; \
})


#define AsConformingToProtocol(_protocol,_object) \
({ \
    id _val = (_object); \
    senassert((_val == nil) || [_val conformsToProtocol:@protocol(_protocol)]); \
    (id <_protocol>) _val; \
})


// Miscellaneous constants and predicates
SENFOUNDATION_EXPORT NSRange SenRangeNotFound;

#define isEmptyStringRange(x)          ((x).length == 0)
#define isFoundStringRange(x)          ((x).length > 0)
#define isValidTextRange(x)            ((x).location != NSNotFound)

#define SenDefaultNotificationCenter   [NSNotificationCenter defaultCenter]
#define SenDefaultUserDefaults         [NSUserDefaults standardUserDefaults]
#define SenDefaultFileManager          [NSFileManager defaultManager]
#define SenDefaultNotificationQueue    [NSNotificationQueue defaultQueue]
#define SenDefaultTimeZone             [NSTimeZone defaultTimeZone]
