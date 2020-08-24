/* NSString+Lines.m created by stephane on Mon 05-Feb-2001 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString+Lines.h"
#import <Foundation/Foundation.h>

@implementation NSString(Lines)

// Use -lines instead of -componentsSeparatedByString: to get lines
// from a string.
// Thanks to Moritz Thomas <motho@gmx.net> for this suggestion

- (NSArray *) lines
    /*" Moritz Thomas found that CVL cannot interpret cvs info created by Mac 
        programs like MacCVSPro, because of the \015 linebreaks (especially the
        Entries file). In order to fix this, you shouldn't use NSString's 
        componentsSeparatedByString: with a fixed newline depending on the OS,
        but a method like the following:
    "*/
{
    NSRange			range = NSMakeRange(0, 1);
    unsigned		length = [self length], content, line;
    NSMutableArray	*anArray = [NSMutableArray array];

    while(range.location < length){
        [self getLineStart:&range.location end:&line contentsEnd:&content forRange:range];
        range.length = content - range.location;
        [anArray addObject:[self substringWithRange:range]];

        range.location = line;
        range.length = 1;
    }

    return anArray;
}

@end
