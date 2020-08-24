/*$Id: SenClassEnumerator.m,v 1.12 2003/11/20 16:34:09 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenClassEnumerator.h"
#import "SenAssertion.h"

#ifndef RHAPSODY
#import <objc/objc-runtime.h>
#endif

@implementation SenClassEnumerator

+ (NSEnumerator *) classEnumerator
{
    return [[[self alloc] init] autorelease];
}


#if defined (GNUSTEP)
- (id) init
{
    self = [super init];
    state = NULL;
    isAtEnd = NO;
    return self;
}


- (id) nextObject
{
    if (isAtEnd) {
        return nil;
    } 
	else {
        Class nextClass = objc_next_class(&state);
		if (nextClass == Nil) {
			isAtEnd = YES;
		}
		return isAtEnd ? nil : nextClass;
    }
}


#elif defined (RHAPSODY)
- (id) init
{
    [super init];
    class_hash = objc_getClasses();
    state = NXInitHashState(class_hash);
    isAtEnd = NO;
    return self;
}


- (id) nextObject
{
    if (isAtEnd) {
        return nil;
    } 
	else {
        Class nextClass = Nil;
		isAtEnd = !NXNextHashState(class_hash, &state, (void **) &nextClass);
		return isAtEnd ? nil : nextClass;
    }
}

#else  
// Mac OS X
- (NSSet *) rejectedClassNames
{
	static NSSet *rejectedClassNames = nil;
	if (rejectedClassNames == nil) {
		rejectedClassNames = [[NSSet setWithObjects:@"WOResourceManager", @"Object", @"List", @"Protocol", nil] retain];
	}
	return rejectedClassNames;
}


- (BOOL) isValidClass:(Class) aClass
{
	return (class_getClassMethod (aClass, @selector(description)) != NULL) 
	&& (class_getClassMethod (aClass, @selector(conformsToProtocol:)) != NULL)
	&& (class_getClassMethod (aClass, @selector(superclass)) != NULL)
	&& (class_getClassMethod (aClass, @selector(isKindOfClass:)) != NULL)
	&& ![[self rejectedClassNames] containsObject:NSStringFromClass (aClass)];
}


- (id) init
{
    int	numberOfClasses = objc_getClassList (NULL, 0);
	
	currentIndex = 0;
	[super init];
	
	if (numberOfClasses > 0) {
		Class *classList = malloc (sizeof (Class) * numberOfClasses);
		(void) objc_getClassList (classList, numberOfClasses);
		
		classes = [[NSMutableArray alloc] initWithCapacity:numberOfClasses];
		while (numberOfClasses--) {
			Class eachClass = classList[numberOfClasses];
			if ([self isValidClass:eachClass]) {
				[classes addObject:eachClass];
			} 
		}
		free (classList);
		isAtEnd = [classes isEmpty];
	} 
	else {
		isAtEnd = YES;
	}
    return self;
}


- (id) nextObject
{
    if (isAtEnd) {
        return nil;
    } 
	else {
        Class nextClass = Nil;
		isAtEnd = (currentIndex >= [classes count]);
		if(!isAtEnd) {
			nextClass = [classes objectAtIndex:currentIndex++];
		}
		return isAtEnd ? nil : nextClass;
    }
}


- (void) dealloc
{
	[classes release];
    [super dealloc];
}
#endif    

@end
