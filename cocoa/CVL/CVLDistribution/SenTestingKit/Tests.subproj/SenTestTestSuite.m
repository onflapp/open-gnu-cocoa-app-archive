/*$Id: SenTestTestSuite.m,v 1.12 2005/04/02 03:18:24 phink Exp $*/

// Copyright (c) 1997-2005, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the following license:
// 
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
// 
// (1) Redistributions of source code must retain the above copyright notice, 
// this list of conditions and the following disclaimer.
// 
// (2) Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation 
// and/or other materials provided with the distribution.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
// IN NO EVENT SHALL Sente SA OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
// OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 
// Note: this license is equivalent to the FreeBSD license.
// 
// This notice may not be removed from this file.

#import "SenTestTestSuite.h"

@implementation SenTestTestSuite
- (void) testEmpty
{
    STAssertTrue ([[SenEmptyTest defaultTestSuite] isEmpty],nil);
}


- (void) testDefaultSuite
{
    STAssertTrue ([[SenSupersuite defaultTestSuite] testCaseCount] == 4, nil);
}


- (void) testTestSuiteWithoutInheritance
{
    STAssertTrue ([[SenSubsuiteWithoutInheritance defaultTestSuite] testCaseCount] == 1, nil);
}


- (void) testTestSuiteWithInheritance
{
    STAssertTrue ([[SenSubsuiteWithInheritance defaultTestSuite] testCaseCount] == 5, nil);
}


- (void) testSuiteComposition
{
    SenTestSuite *suite = [SenTestSuite testSuiteWithName:@"Composite"];
    [suite addTest:[SenSupersuite defaultTestSuite]];
    [suite addTest:[SenSubsuiteWithoutInheritance defaultTestSuite]];
    STAssertTrue ([suite testCaseCount] == [[SenSupersuite defaultTestSuite] testCaseCount] + [[SenSubsuiteWithoutInheritance defaultTestSuite] testCaseCount], nil);
}


- (void) testSuiteForSingleCase
{
    STAssertTrue ([[SenTestSuite testSuiteForTestCaseWithName:@"SenSupersuite/test"] testCaseCount] == 1, nil);
}


- (void) testSuiteForSingleCaseClass
{
    STAssertTrue ([[SenTestSuite testSuiteForTestCaseWithName:@"SenSupersuite"] testCaseCount] == [[SenSupersuite defaultTestSuite] testCaseCount], nil);
}

@end


@implementation SenSupersuite
- (void) test
{
}

- (void) test1
{
}

- (void) test2
{
}

- (void) test3
{
}

- (void) notATest
{
}
@end


@implementation SenSubsuiteWithoutInheritance
- (void) test4
{
}


+ (BOOL) isInheritingTestCases
{
    return NO;
}
@end


@implementation SenSubsuiteWithInheritance
- (void) test4
{
}


+ (BOOL) isInheritingTestCases
{
    return YES;
}
@end


@implementation SenEmptyTest:SenTestCase
- (void) notATest
{
}
@end
