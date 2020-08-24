/* NSString+CVL.m created by stephane on Wed 31-Oct-2001 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "NSString+CVL.h"
#import <Foundation/Foundation.h>
#include <fnmatch.h>
#import <AGRegex/AGRegexes.h>


@implementation NSString(CVL)

- (NSString *) cvlFilenameForRevision:(NSString *)aVersion
{
#warning (Stephane) Check for other chars like slash, $, ...
    NSString	*dottedRevision = [aVersion replaceMatchesOfPattern:@" " 
                                                         withString:@"\\." 
                                                            options:0];
    NSString	*extension = [self pathExtension];
        
    // Let's not modify the file extension!
    // But if the file does not have an extension then we add the "txt" 
    // extension so that the workspace can open them. Note: If the a file name
    // ends with a revision number (e.g. file1-1.22) then the workspace thinks
    // "22" is an extension. So in this example we change this to file1-1.22.txt.
    if([extension length])
        return [[[self stringByDeletingPathExtension] stringByAppendingFormat:@"-%@", dottedRevision] stringByAppendingPathExtension:extension];
    else
        return [[self stringByAppendingFormat:@"-%@", dottedRevision] stringByAppendingPathExtension:@"txt"];
}

- (NSString *) cvlFilenameForDate:(NSString *)aDate
{
#warning (Stephane) Check for other chars like slash, $, ...
    NSString	*dottedDate = [aDate replaceMatchesOfPattern:@" " 
                                                  withString:@"\\." 
                                                     options:0];
    NSString	*dashDottedDate = [dottedDate replaceMatchesOfPattern:@":" 
                                                           withString:@"-" 
                                                              options:0];
    NSString	*extension = [self pathExtension];
    NSString    *aStringByDeletingPathExtension = [self stringByDeletingPathExtension];

    // Let's not modify the file extension!
    // But if the file does not have an extension then we add the "txt" 
    // extension so that the workspace can open them. Note: If the a file name
    // ends with a revision number (e.g. file1-1.22) then the workspace thinks
    // "22" is an extension. So in this example we change this to file1-1.22.txt.    
    if( [extension length] > 0 ) {
        return [[aStringByDeletingPathExtension stringByAppendingFormat:@"-%@", dashDottedDate] stringByAppendingPathExtension:extension];
    }
    return [[aStringByDeletingPathExtension stringByAppendingFormat:@"-%@", dashDottedDate] stringByAppendingPathExtension:@"txt"];
}

- (BOOL) cvlFilenameMatchesShellPatterns:(NSArray *)patterns
{
    // See fnmatch(3) and sh(1) for more information
    // Meta-characters: * ? [ !
    if(patterns != nil && [patterns count] > 0 && [self length] > 0){
        NSEnumerator	*anEnum = [patterns objectEnumerator];
        NSString		*aPattern;
        const char		*selfCString = [self fileSystemRepresentation];

        while ( (aPattern = [anEnum nextObject]) ) {
            int	result = fnmatch([aPattern fileSystemRepresentation], selfCString, 0);

            if(result == 0)
                return YES;
        }
    }
    
    return NO;
}

- (NSString *)removeTrailingWhiteSpace
    /*" This method returns this string with any trailing whitespace removed. 
        This includes spaces, tabs and newlines. Note that it is assumed that
        this is only one line. If it is more than one line then only the 
        whitespace from the last line is removed.
    "*/
{
    NSString *selfWithoutTrailingSpaces = nil;

    selfWithoutTrailingSpaces = [self replaceMatchesOfPattern:@"\\s+$" 
                                                   withString:@"" 
                                                      options:0]; 
    [[selfWithoutTrailingSpaces retain] autorelease];
    return selfWithoutTrailingSpaces;
}


@end
