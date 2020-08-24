// AGRegexMatchEnumerator.h
//
// Copyright (c) 2002 Aram Greenman. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "AGRegexMatchEnumerator.h"
#import "AGRegexMatch.h"
#import "AGRegex.h"


@implementation AGRegexMatchEnumerator

- (id)initWithRegex:(AGRegex *)re string:(NSString *)s range:(NSRange)r {
    if ( (self = [super init]) ) {
        regex = [re retain];
        string = [s copy]; // create one immutable copy of the string so we don't copy it over and over when the matches are created
        range = r;
        end = range.location + range.length;
    }
    return self;
}

- (void)dealloc {
    [regex release];
    [string release];
    [super dealloc];
}

- (id)nextObject {
    AGRegexMatch *next;
    if ( (next = [regex findInString:string range:range]) ) {
        range.location = [next range].location + [next range].length;
        if ([next range].length == 0)
            range.location++;
        range.length = end - range.location;
        if (range.location > end)
            return nil;
    }
    return next;
}

- (NSArray *)allObjects {
    NSMutableArray *all = [NSMutableArray array];
    AGRegexMatch *next;
    while ( (next = [self nextObject]) )
        [all addObject:next];
    return all;
}

@end
