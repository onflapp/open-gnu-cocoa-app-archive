/* CvsUpdateRequest.h created by ja on Fri 29-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@interface CvsUpdateRequest : CvsRequest
{
    NSMutableString 	*parsingBuffer;
    NSString *destinationFile;
    NSString *revision;
    NSString *date;
    BOOL		removesStickyAttributes;
}

+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)files inPath:(NSString *)aPath;
+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)files inPath:(NSString *)aPath removesStickyAttributes:(BOOL)removesStickyAttributes;
+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)files inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate;
+ (CvsUpdateRequest *)cvsUpdateRequestForFiles:(NSArray *)files inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributes;
+ (CvsUpdateRequest *)cvsUpdateRequestForFile:(NSString *)file inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate toFile:(NSString *)fullPath;
+ (CvsUpdateRequest *)cvsUpdateRequestForFile:(NSString *)file inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributes toFile:(NSString *)fullPath;

- (void)setRevision:(NSString *)revision;
- (void)setDate:(NSString *)date;
- (void)setDestinationFilePath:(NSString *)fullPath;
- (void) setRemovesStickyAttributes:(BOOL)flag;
    // Default is NO

- (NSString *) destinationFilePath;
- (void) parseUnremovedNibsFromString:(NSString *)aString;

@end
