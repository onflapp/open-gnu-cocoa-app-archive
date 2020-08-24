/*$Id: SenValueTree.m,v 1.9 2005/04/29 09:56:30 stephane Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenValueTree.h"
#import "NSString_SenAdditions.h"
#import <SenFoundation/SenFoundation.h>
#import <Foundation/Foundation.h>

@interface NSObject (SenValueTreeExtensions)
- childForSenValueTreeClass:(Class) aSenValueTreeClass;
@end


@implementation NSObject (SenValueTreeExtensions)
- childForSenValueTreeClass:(Class) aSenValueTreeClass
{
    return [[[aSenValueTreeClass alloc] initWithValue:self] autorelease];
}
@end

@implementation NSArray (SenValueTreeExtensions)
- childForSenValueTreeClass:(Class) aSenValueTreeClass
{
    return [[[aSenValueTreeClass alloc] initWithSExpression:self] autorelease];
}
@end



@implementation SenValueTree
+ valueTreeWithPropertyList:(NSString *) aString
{
    return [[[self alloc] initWithPropertyList:aString] autorelease];
}


+ valueTreeWithOutlineString:(NSString *) aString
{
    return [[[self alloc] initWithOutlineString:aString] autorelease];
}


- initWithValue:(id) aValue
{
    [super init];
    [self setValue:aValue];
    return self;
}


- initWithSExpression:(NSArray *) anArray
{
    if (!isNilOrEmpty (anArray)) {
        NSEnumerator *objectEnumerator = [anArray objectEnumerator];
        id each;

        [self initWithValue:[objectEnumerator nextObject]];
        while ( (each = [objectEnumerator nextObject]) ) {
            [self addChild:[each childForSenValueTreeClass:[self class]]];
        }
        return self;
    }
    return nil;
}


- initWithPropertyList:(NSString *) aString
{
    NSArray *array;
    NS_DURING
        array = [aString propertyList];
    NS_HANDLER
        array = nil;
        [localException raise];
    NS_ENDHANDLER
    return ((array != nil) && [array isKindOfClass:[NSArray class]]) ? [self initWithSExpression:array] : nil;
}


- initWithOutlineArray:(NSArray *) array index:(unsigned int *) anIndexPointer
{
    if (*anIndexPointer < [array count]) {
        NSString *line = [array objectAtIndex:*anIndexPointer];
        NSRange indentationRange = [line indentationRange];
        NSString *content = [line substringFromIndex:indentationRange.length];

        [self initWithValue:content];
        *anIndexPointer = *anIndexPointer + 1;
        while ((*anIndexPointer < [array count]) && [[array objectAtIndex:*anIndexPointer] indentationRange].length > indentationRange.length) {
            id  newChild = [[[self class] alloc] initWithOutlineArray:array index:anIndexPointer];
            
            [self addChild:newChild];
            [newChild release];
        }
    }
    return self;
}


- initWithOutlineString:(NSString *) aString
{
    NSEnumerator *lineEnumerator = [[aString componentsSeparatedByString:@"\n"] objectEnumerator];
    NSString *each;
    NSMutableArray *array = [NSMutableArray array];
    unsigned int anIndex = 0;

    while ( (each = [lineEnumerator nextObject]) ) {
        if ([each rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].length != 0) {
            [array addObject:each];
        }
    }
    
    return (!isNilOrEmpty (array)) ? [self initWithOutlineArray:array index:&anIndex] : nil;
}


- (NSString *) description
{
    if ([self isLeaf]) {
        return [value description];
    }
    else {
        NSMutableArray *array = [NSMutableArray arrayWithObject:value];
        NSEnumerator *childEnumerator = [[self children] objectEnumerator];
        id child;
        while ( (child = [childEnumerator nextObject]) ) {
            [array addObject:[child description]];
        }
        return [array descriptionWithLocale:nil indent:[self depth]];
    }
}

- (BOOL) isEqual:(id) other
{
    if ([other isKindOfClass:[self class]]) {
        return [self isEqualToTree:other];
    }
    return [super isEqual:other];
}

- (BOOL) isEqualToNode:(id)other
{
    return [[self value] isEqual:[other value]];
}

- (void) dealloc
{
    RELEASE (value);
    [super dealloc];
}


- (id) value
{
    return value;
}


- (void) setValue:(id) aValue
{
    ASSIGN (value, aValue);
}
@end
