/*$Id: NSString_SenAdditions.h,v 1.14 2004/01/21 08:13:44 william Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <Foundation/NSString.h>

@interface NSString (SenAdditions)
- (NSString *) asUnixPath;
- (NSString *) titleFromPath;
- (NSArray *) componentsSeparatedBySpace;
- (NSArray *) componentsSeparatedBySpaceAndNewline;
- (NSArray *) words;
- (NSArray *) paragraphs;
- (NSString *) stringByTruncatingAtNumberOfCharacters:(unsigned int) aValue;
- (NSString *) asASCIIString;
- (NSRange) indentationRange;

- (NSString *) stringByTrimmingSpace;

+ (id) stringWithData:(NSData *)data encoding:(NSStringEncoding) encoding;

- (NSString *) stringByAddingURLPercentEscape;
- (NSString *) stringByReplacingURLPercentEscape;

- (NSDictionary *) asURLQueryDictionary;

+ (NSString *) universallyUniqueID;

- (BOOL)containsOnlyWhiteSpace;

@end
