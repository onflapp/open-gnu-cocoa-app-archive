/*$Id: SenInvocationEnumerator.h,v 1.6 2003/07/25 16:07:42 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <objc/objc.h>
#if defined (GNUSTEP)
#import <objc/runtime.h>
#else
#import <objc/objc-class.h>
#endif

@interface SenInvocationEnumerator : NSObject
{
    @private
    Class class;
    void *iterator;
    struct objc_method_list *mlist;
    int count;
}

+ (id) instanceInvocationEnumeratorForClass:(Class) aClass;
- (id) initForClass:(Class) aClass;
@end
