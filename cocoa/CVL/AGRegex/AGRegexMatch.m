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


#import "AGRegexMatch.h"
#import "AGRegex.h"

#ifdef SUPPORT_UTF8
// count the number of UTF-8 characters in a string
// there is probably a better way to do this but this works for now
static int utf8charcount(const char *str, int len) {
	int chars, pos;
	unsigned char c;
	for (pos = chars = 0; pos < len; pos++) {
		c = str[pos];
		if (c <= 0x7f || (0xc0 <= c && c <= 0xfd))
			chars++;
	}
	return chars;
}
#else
#define utf8charcount(str, len) (len)
#endif


@implementation AGRegexMatch

// takes ownership of the passed match vector, free on dealloc
- (id)initWithRegex:(AGRegex *)re string:(NSString *)str vector:(int *)mv count:(unsigned int)c {
	if ( (self = [super init]) ) {
		regex = [re retain];
		string = [str copy]; // really only copies if the string is mutable, immutable strings are just retained
		matchv = mv;
		count = c;
	}
	return self;
}

- (void)dealloc {
	free(matchv);
	[regex release];
	[string release];
	[super dealloc];
}

- (unsigned int)count {
	return count;
}

- (NSString *)group {
	return [self groupAtIndex:0];
}

- (NSString *)groupAtIndex:(unsigned int)idx {
	NSRange r = [self rangeAtIndex:idx];
	return r.location == NSNotFound ? nil : [string substringWithRange:r];
}

- (NSString *)groupNamed:(NSString *)name {
	unsigned int idx = pcre_get_stringnumber([regex pcre], [name UTF8String]);
	if (idx == PCRE_ERROR_NOSUBSTRING)
		[NSException raise:NSInvalidArgumentException format:@"no group named %@", name];
	return [self groupAtIndex:idx];
}

- (NSRange)range {
	return [self rangeAtIndex:0];
}

- (NSRange)rangeAtIndex:(unsigned int)idx {
	int start, end;
	if (idx >= count)
		[NSException raise:NSRangeException format:@"index %d out of bounds", idx];
	start = matchv[2 * idx];
	end = matchv[2 * idx + 1];
	if (start < 0)
		return NSMakeRange(NSNotFound, 0);
	// convert byte locations to character locations
	return NSMakeRange(utf8charcount([string UTF8String], start), utf8charcount([string UTF8String] + start, end - start));
}

- (NSRange)rangeNamed:(NSString *)name {
	unsigned int idx = pcre_get_stringnumber([regex pcre], [name UTF8String]);
	if (idx == PCRE_ERROR_NOSUBSTRING)
		[NSException raise:NSInvalidArgumentException format:@"no group named %@", name];
	return [self rangeAtIndex:idx];
}

- (NSString *)string {
	return string;
}

- (NSString *)description {
	NSMutableString *desc = [NSMutableString stringWithFormat:@"%@ {\n", [super description]];
	unsigned int i;
	for (i = 0; i < count; i++)
		[desc appendFormat:@"\t%d %@ %@\n", i, NSStringFromRange([self rangeAtIndex:i]), [self groupAtIndex:i]];
	[desc appendString:@"}"];
	return desc;
}

@end
