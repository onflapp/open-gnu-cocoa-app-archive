/*$Id: NSString_SenAdditions.m,v 1.17 2004/01/21 08:13:44 william Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString_SenAdditions.h"
#import "SenCollection.h"
#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

#define NT_PATH_SEPARATOR  @"\\"
#define UNIX_PATH_SEPARATOR @"/"

@implementation NSString (SenAdditions)

- (NSString *) asUnixPath
{
    NSArray *components = [[[self pathComponents] collectionByRejectingWithSelector:@selector(isEqualToString:) withObject:NT_PATH_SEPARATOR] asArray];
    return [[components componentsJoinedByString:UNIX_PATH_SEPARATOR] stringByStandardizingPath];
}

- (NSArray *) componentsSeparatedBySpace
{
    NSCharacterSet *space = [NSCharacterSet whitespaceCharacterSet];
    NSMutableArray *elements = [NSMutableArray array];
    NSScanner *elementScanner = [NSScanner scannerWithString:self];
    while (![elementScanner isAtEnd]) {
        NSString *element;
        if ([elementScanner scanUpToCharactersFromSet:space intoString:&element]) {
            [elements addObject:element];
        }
    }
    return elements;
}

- (NSArray *) componentsSeparatedBySpaceAndNewline
{
    NSCharacterSet *space = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSMutableArray *elements = [NSMutableArray array];
    NSScanner *elementScanner = [NSScanner scannerWithString:self];
    while (![elementScanner isAtEnd]) {
        NSString *element;
        if ([elementScanner scanUpToCharactersFromSet:space intoString:&element]) {
            [elements addObject:element];
        }
    }
    return elements;
}

- (NSArray *) words
{
    static NSMutableCharacterSet *separator = nil;
    NSMutableArray *elements = [NSMutableArray array];
    NSScanner *elementScanner = [[NSScanner alloc] initWithString:self];

    if(!separator){
        separator = [[NSCharacterSet whitespaceCharacterSet] mutableCopy];
        [separator formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    }

    [elementScanner setCharactersToBeSkipped:separator];

    while (![elementScanner isAtEnd]) {
        NSString *element;
        if ([elementScanner scanUpToCharactersFromSet:separator intoString:&element]) {
            [elements addObject:element];
        }
    }
    [elementScanner release];
    
    return elements;
}

- (NSArray *)paragraphs
{
    NSCharacterSet *paragraphSeparators=[NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    NSCharacterSet *notParagraphSeparatorsOrWhiteSpaces = [[NSCharacterSet characterSetWithCharactersInString:@"\n\t\r  "] invertedSet];
    NSRange searchRange;
    NSRange foundRange;
    NSRange textRange;
    NSMutableArray *paragraphs=[NSMutableArray array];

    searchRange.location=0;
    searchRange.length=[self length];

    while (searchRange.length) {
        foundRange=[self rangeOfCharacterFromSet:notParagraphSeparatorsOrWhiteSpaces options:0 range:searchRange];
        if (foundRange.length) {
            searchRange.location=foundRange.location+foundRange.length-1;
            searchRange.length=[self length]-searchRange.location;
            foundRange=[self rangeOfCharacterFromSet:paragraphSeparators options:0 range:searchRange];
            if (foundRange.length) {
                textRange.location=searchRange.location;
                textRange.length=foundRange.location-searchRange.location;
                [paragraphs addObject:[self substringWithRange:textRange]];
                searchRange.location=foundRange.location+foundRange.length-1;
                searchRange.length=[self length]-searchRange.location;
            }
            else {
                textRange=searchRange;
                [paragraphs addObject:[self substringWithRange:textRange]];
                searchRange.length=0;
            }
        }
        else {
            searchRange.length=0;
        }
    }
    return paragraphs;
}

- (NSString *) stringByTruncatingAtNumberOfCharacters:(unsigned int) aValue
{
    if ([self length] <= aValue) {
        return self;
    }
    return [[self substringToIndex:MIN (aValue, [self length] - 1)] stringByAppendingString:@"..."];
}

- (NSString *) asASCIIString
{
    NSData *asciiData = [self dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    return [[[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding] autorelease];
}

- (NSRange) indentationRange
{
    NSCharacterSet *nonWhitespaceCharacterSet = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
    NSRange first = [self rangeOfCharacterFromSet:nonWhitespaceCharacterSet];
    return NSMakeRange (0, first.location);
}

- (NSString *) stringByTrimmingSpace
{
	NSEnumerator *componentEnumerator = [[self componentsSeparatedByString:@" "] objectEnumerator];
	NSMutableArray *components = [NSMutableArray array];
	id each;

	while ( (each = [componentEnumerator nextObject]) ) {
		if (!isNilOrEmpty (each)) {
			[components addObject:each];
		}
	}
	return [components componentsJoinedByString:@" "];
}


+ (id) stringWithData:(NSData *)data encoding:(NSStringEncoding) encoding
{
	return [[[self alloc] initWithData:data encoding:encoding] autorelease];

}


- (NSString *) stringByAddingURLPercentEscape
{
	return [(NSString *) CFURLCreateStringByAddingPercentEscapes (NULL, (CFStringRef) self, NULL, NULL, kCFStringEncodingUTF8) autorelease];
}


- (NSString *) stringByReplacingURLPercentEscape
{
	return [(NSString *) CFURLCreateStringByReplacingPercentEscapes (NULL, (CFStringRef) self, CFSTR("")) autorelease];	
}


- (NSDictionary *) asURLQueryDictionary
{
	NSMutableDictionary *queryDictionary = [NSMutableDictionary dictionary];
	NSEnumerator *parameterEnumerator = [[self componentsSeparatedByString:@"&"] objectEnumerator];
	id each;

	while ( (each = [parameterEnumerator nextObject]) ) {
		NSArray *components = [each componentsSeparatedByString:@"="];
		if ([components count] == 2) {
			[queryDictionary setObject:[components objectAtIndex:1] forKey:[components objectAtIndex:0]];
		}
	}
	return queryDictionary;
}


+ (NSString *) universallyUniqueID
{
	CFUUIDRef uuid = CFUUIDCreate (NULL);
	NSString *universallyUniqueID = (NSString *)CFUUIDCreateString (NULL, uuid);
	CFRelease (uuid);
	return [universallyUniqueID autorelease];	
}

- (NSString *) titleFromPath
    /*" This method returns a string that can used as a title in a window. It 
        looks at the path in aPath and takes the last component and puts it 
        first then adds a dash and the rest of the path afterwards. So if aPath
        is "/User/john/Documents/Test1" then the title returned would be
        "Test1  -  /User/john/Documents/". This method first calls the
        method -stringByStandardizingPath to cleanup and/or resolve any links in
        in the path.

        The method -setTitleWithRepresentedFilename: in NSWindow works in a 
        different way. If you command click on the title then you will get a
        drop list of the path components.
    "*/
{
    NSString    *aStandardizedPath = nil;
    NSString    *aTitle = @"Untitled";
    NSString    *aDirectory = nil;
    NSString    *aFilename = nil;
    
    if ( isNotEmpty(self) ) {
        aStandardizedPath = [self stringByStandardizingPath];
        aDirectory = [aStandardizedPath stringByDeletingLastPathComponent];
        aFilename = [aStandardizedPath lastPathComponent];
        aTitle = [NSString stringWithFormat:@"%@  -  %@", aFilename, aDirectory];
    }
    return aTitle;
}

- (BOOL)containsOnlyWhiteSpace
    /*" This method returns YES if this string contains only whitespace and NO
        otherwise. Here whitespace is defined as the characters space (U+0020) 
        and tab (U+0009) and the newline and nextline characters (U+000AÐU+000D,
        U+0085).
    "*/
{
    NSScanner *aScanner;
    NSCharacterSet *anEmptyCharacterSet = nil;
    
    anEmptyCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];    
    // Create a scanner.
    aScanner = [NSScanner scannerWithString:self];
    // Scan past all the whitespace.
    (void)[aScanner scanCharactersFromSet:anEmptyCharacterSet
                               intoString:NULL];
    // Are we at the end of the string. If so return YES.
    if ( [aScanner isAtEnd] ) {
        return YES;
    }
    return NO;
}

@end
