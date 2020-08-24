// AGRegexMatch.h
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


#import <Foundation/Foundation.h>


@class AGRegex;

/*!
@class AGRegexMatch
@abstract A single occurence of a regular expression.
@discussion An AGRegexMatch represents a single occurence of a regular expression within the target string. The range of each subpattern within the target string is returned by -range, -rangeAtIndex:, or -rangeNamed:. The part of the target string that matched each subpattern is returned by -group, -groupAtIndex:, or -groupNamed:.
*/
@interface AGRegexMatch : NSObject {
	AGRegex *regex;
	NSString *string;
	int *matchv;
	unsigned int count;
}

- (id)initWithRegex:(AGRegex *)re string:(NSString *)str vector:(int *)mv count:(unsigned int)c;

/*!
@method count
 The number of capturing subpatterns, including the pattern itself. */
- (unsigned int)count;

    /*!
    @method group
     Returns the part of the target string that matched the pattern. */
- (NSString *)group;

    /*!
    @method groupAtIndex:
     Returns the part of the target string that matched the subpattern at the given index or nil if it wasn't matched. The subpatterns are indexed in order of their opening parentheses, 0 is the entire pattern, 1 is the first capturing subpattern, and so on. */
- (NSString *)groupAtIndex:(unsigned int)idx;

    /*!
        @method groupNamed:
     Returns the part of the target string that matched the subpattern of the given name or nil if it wasn't matched. */
- (NSString *)groupNamed:(NSString *)name;

    /*!
    @method range
     Returns the range of the target string that matched the pattern. */
- (NSRange)range;

    /*!
    @method rangeAtIndex:
     Returns the range of the target string that matched the subpattern at the given index or {NSNotFound, 0} if it wasn't matched. The subpatterns are indexed in order of their opening parentheses, 0 is the entire pattern, 1 is the first capturing subpattern, and so on. */
- (NSRange)rangeAtIndex:(unsigned int)idx;

    /*!
     @method rangeNamed:
     Returns the range of the target string that matched the subpattern of the given name or {NSNotFound, 0} if it wasn't matched. */
- (NSRange)rangeNamed:(NSString *)name;

    /*!
    @method string
     Returns the target string. */
- (NSString *)string;

@end
