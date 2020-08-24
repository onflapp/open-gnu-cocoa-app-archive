/*$Id: SenQualifier.h,v 1.4 2003/07/25 16:07:43 phink Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#ifndef RHAPSODY
#import <Foundation/Foundation.h>

@protocol SenQualifierEvaluation
- (BOOL) evaluateWithObject:object;
@end


// These are implemented in Foundation.
#define SenQualifierOperatorEqual @selector(isEqualTo:)
#define SenQualifierOperatorNotEqual @selector(isNotEqualTo:)
#define SenQualifierOperatorLessThan @selector(isLessThan:)
#define SenQualifierOperatorGreaterThan @selector(isGreaterThan:)
#define SenQualifierOperatorLessThanOrEqualTo @selector(isLessThanOrEqualTo:)
#define SenQualifierOperatorGreaterThanOrEqualTo @selector(isGreaterThanOrEqualTo:)
#define SenQualifierOperatorContains @selector(doesContain:)
#define SenQualifierOperatorLike @selector(isLike:)
#define SenQualifierOperatorCaseInsensitiveLike @selector(isCaseInsensitiveLike:)



@interface SenQualifier : NSObject <SenQualifierEvaluation>
{
}
@end


@interface SenKeyValueQualifier:SenQualifier <SenQualifierEvaluation>
{
	SEL selector;
	NSString *key;
	id value;
}

+ qualifierWithKey:(NSString *) key operatorSelector:(SEL) selector value:(id) value;
- initWithKey:(NSString *) key operatorSelector:(SEL) selector value:(id) value;
- (SEL) selector;
- (NSString *) key;
- (id) value;
@end


@interface SenAndQualifier : SenQualifier <SenQualifierEvaluation>
{
    NSArray *qualifiers;
}

+ qualifierWithQualifierArray:(NSArray *) array;
- initWithQualifierArray: (NSArray *) array;
- (NSArray *) qualifiers;
@end


@interface SenOrQualifier : SenQualifier <SenQualifierEvaluation>
{
    NSArray *qualifiers;
}

+ qualifierWithQualifierArray:(NSArray *) array;
- initWithQualifierArray:(NSArray *)array;
- (NSArray *)qualifiers;
@end


@interface SenNotQualifier:SenQualifier <SenQualifierEvaluation>
{
    SenQualifier *qualifier;
}
+ qualifierWithQualifier:(SenQualifier *) qualifier;
- initWithQualifier:(SenQualifier *) qualifier;
- (SenQualifier *) qualifier;
@end


@interface NSArray (SenQualifierExtras)
- (NSArray *) arrayBySelectingWithQualifier:(SenQualifier *)qualifier;
@end
#endif

