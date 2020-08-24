/*$Id: SenQualifier.m,v 1.5 2003/11/19 10:50:34 william Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#ifndef RHAPSODY

#import "SenQualifier.h"
#import <SenFoundation/SenFoundation.h>


@implementation SenQualifier
- (BOOL) evaluateWithObject:object
{
	return NO;
}
@end


@implementation SenKeyValueQualifier
+ qualifierWithKey:(NSString *) aKey operatorSelector:(SEL) aSelector value:(id) aValue
{
	return [[[self alloc] initWithKey:aKey operatorSelector:aSelector value:aValue] autorelease];
}


- initWithKey:(NSString *) aKey operatorSelector:(SEL) aSelector value:(id) aValue
{
	[super init];
	key = [aKey copy];
	selector = aSelector;
	value = [aValue copy];
	return self;
}


- (void) dealloc
{
	RELEASE (key);
	RELEASE (value);
	[super dealloc];
}


- (SEL) selector
{
	return selector;
}


- (NSString *) key
{
	return key;
}


- (id) value
{
	return value;
}


- (BOOL) evaluateWithObject:object
{
	return [[object valueForKey:key] performSelector:selector withObject:value] != nil ? YES : NO;
}


- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ %@ %@", key, NSStringFromSelector(selector), value];
}
@end


@implementation SenAndQualifier
+ qualifierWithQualifierArray:(NSArray *) array
{
	return [[[self alloc] initWithQualifierArray:array] autorelease];
}


- initWithQualifierArray:(NSArray *) array
{
	[super init];
	qualifiers = [array copy];
	return self;
}


- (void) dealloc
{
	RELEASE (qualifiers);
	[super dealloc];
}


- (NSArray *) qualifiers
{
	return qualifiers;
}


- (BOOL) evaluateWithObject:object
{
	NSEnumerator *qualifierEnumerator = [qualifiers objectEnumerator];
	id each;
	while ( (each = [qualifierEnumerator nextObject]) ) {
		if (![each evaluateWithObject:object]) {
			return NO;
		}
	}
	return YES;
}


- (NSString *) description
{
	return [NSString stringWithFormat:@"and %@", qualifiers];
}
@end


@implementation SenOrQualifier
+ qualifierWithQualifierArray:(NSArray *) array
{
	return [[[self alloc] initWithQualifierArray:array] autorelease];
}


- initWithQualifierArray:(NSArray *) array
{
	[super init];
	qualifiers = [array copy];
	return self;
}


- (void) dealloc
{
	RELEASE (qualifiers);
	[super dealloc];
}


- (NSArray *) qualifiers
{
	return qualifiers;
}


- (BOOL) evaluateWithObject:object
{
	NSEnumerator *qualifierEnumerator = [qualifiers objectEnumerator];
	id each;
	while ( (each = [qualifierEnumerator nextObject]) ) {
		if ([each evaluateWithObject:object]) {
			return YES;
		}
	}
	return NO;
}


- (NSString *) description
{
	return [NSString stringWithFormat:@"or %@", qualifiers];
}
@end


@implementation SenNotQualifier
+ qualifierWithQualifier:(SenQualifier *) aQualifier
{
	return [[[self alloc] initWithQualifier:aQualifier] autorelease];
}


- initWithQualifier:(SenQualifier *) aQualifier
{
	[super init];
	ASSIGN (qualifier, aQualifier);
	return self;
}


- (SenQualifier *) qualifier
{
	return qualifier;
}


- (BOOL) evaluateWithObject:object
{
	return ![qualifier evaluateWithObject:object];
}


- (NSString *) description
{
	return [NSString stringWithFormat:@"not %@", qualifier];
}
@end


@implementation NSArray (SenQualifierExtras)
- (NSArray *) arrayBySelectingWithQualifier:(SenQualifier *)qualifier
{
	NSMutableArray *result = [NSMutableArray array];
	NSEnumerator *objectEnumerator = [self objectEnumerator];
	id each;
	while ( (each = [objectEnumerator nextObject]) ) {
		if ([qualifier evaluateWithObject:each]) {
			[result addObject:each];
		}
	}
	return result;
}
@end
#endif