/*$Id: RegexTestCase.m,v 1.6 2003/11/20 10:51:42 william Exp $*/


// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

// Runs tests from the Perl distribution.
// FIXME ? ((foo)|(bar))*	foobar	y	$1-$2-$3	bar-foo-bar

#import "RegexTestCase.h"
#import "SenOyster.h"
#import <SenFoundation/SenFoundation.h>

#define TEST_DATA_FILE @"re_tests"
#define TEST_DATA_COLUMNS_COUNT 5


// FIXME: this test should be refactored. Could build a suite of cases, one per line.
@implementation RegexTestCase

- (void) setUp
{
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:TEST_DATA_FILE ofType:nil];
    NSString *fileString = [NSString stringWithContentsOfFile:filePath];
    NSArray *components = [fileString componentsSeparatedByOperator:@"/[\\t\\n]/"];
    int count = [components count];
    int i = 0;

    senassert (count % TEST_DATA_COLUMNS_COUNT == 0);
    ASSIGN(testCases, [NSMutableArray arrayWithCapacity:count / TEST_DATA_COLUMNS_COUNT]);
    while (i < count){
        NSMutableDictionary *testCase = [NSMutableDictionary dictionary];
        NSArray *pattern = [[components objectAtIndex:i++] componentsSeparatedByString:@"'"];
        [testCase setObject:(([pattern count] > 1) ? [pattern objectAtIndex:1] : [pattern objectAtIndex:0]) forKey:@"pattern"];
        [testCase setObject:(([pattern count] > 1) ? [pattern objectAtIndex:2] : @"") forKey:@"modifiers"];
        [testCase setObject:[components objectAtIndex:i++] forKey:@"subject"];
        [testCase setObject:[components objectAtIndex:i++] forKey:@"result"];
        [testCase setObject:[components objectAtIndex:i++] forKey:@"replacement"];
        [testCase setObject:[components objectAtIndex:i++] forKey:@"expected"];
        [testCases addObject:testCase];
    }
}


- (void) tearDown
{
    RELEASE (testCases);
}


- (void) testFile
{

    NSEnumerator *caseEnumerator = [testCases objectEnumerator];
    id each;

    while ( (each = [caseEnumerator nextObject]) ) {
        NSString *pattern = [each objectForKey:@"pattern"];
        NSString *modifiers = [each objectForKey:@"modifiers"];
        NSString *target = [each objectForKey:@"subject"];
        NSString *result = [each objectForKey:@"result"];
        NSString *substitution = [each objectForKey:@"replacement"];
        BOOL shouldNotCompile = [result isEqualToString:@"c"];
        BOOL shouldNotMatch = [result isEqualToString:@"n"];
        BOOL shouldInterpolate = ![substitution isEqualToString:@"-"];
        
        NSString *matchingOperator = [NSString stringWithFormat:@"m'%@'%@", pattern, modifiers];
        NSString *interpolatingOperator = [NSString stringWithFormat:@"s/%@/%@/%@", pattern ,substitution, modifiers];

        NSString *caseDescription = [each description];
        
        if (shouldNotCompile) {
            shouldRaise1 ([target isMatchedByOperator:matchingOperator], caseDescription);
        }
        else if (shouldNotMatch) {
            shouldnt1 ([target isMatchedByOperator:matchingOperator], caseDescription);
        }
        else if (shouldInterpolate) {
            // We do not have access to Perl $&, $1, ... variables
            // (maybe match should return an object with all these ?)
            // so we have to use the following workaround to do the double quote interpolating
            NSString *match = [target substringMatchedByOperator:matchingOperator];
            NSString *interpolation = [((match != nil) ? match : @"") stringByApplyingReplacementOperator:interpolatingOperator];
            NSString *expectedInterpolation = [each objectForKey:@"expected"];

            if (isNilOrEmpty(expectedInterpolation)) {
                should1 (isNilOrEmpty(interpolation), caseDescription);
            }
            else {
                shouldBeEqual1 (interpolation, expectedInterpolation, caseDescription);
            }
        }
        else {
            should1 ([target isMatchedByOperator:matchingOperator], caseDescription);
        }
    }
}
@end
