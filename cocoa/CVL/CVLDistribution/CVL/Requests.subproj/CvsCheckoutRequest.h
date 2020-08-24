/* CvsCheckoutRequest.h created by vincent on Wed 26-Nov-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@interface CvsCheckoutRequest : CvsRequest
{
    NSString *destinationPath;
    NSString *finalDestinationPath;
    NSString *revision;
    NSString *date;
    BOOL		removesStickyAttributes;
    BOOL		readOnly;
	BOOL		fetchingACvsWrappersFile;
}

+ (CvsCheckoutRequest *)cvsCheckoutRequestForModule:(NSString *)module inRepository:(CvsRepository *)aRepository toPath:(NSString *)aPath;

+ (CvsCheckoutRequest *)cvsCheckoutRequestForModule:(NSString *)module inRepository:(CvsRepository *)aRepository toPath:(NSString *)aPath revision:(NSString *)revision date:(NSString *)aDate;
+ (CvsCheckoutRequest *)cvsCheckoutRequestForModule:(NSString *)module inRepository:(CvsRepository *)aRepository toPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributes;
/*
+ (id) cvsCheckoutRequestForFile: (NSString*) aFile inPath: (NSString*) aPath;

+ (id) cvsCheckoutRequestForFile: (NSString*) aFile inDestinationPath: (NSString*) aDestinationPath;
// allow checkout with another dir name
*/
+ (CvsCheckoutRequest *)cvsUpdateRequestForFile:(NSString *)file inPath:(NSString *)aPath revision:(NSString *)aRevision date:(NSString *)aDate removesStickyAttributes:(BOOL)removesStickyAttributesFlag toFile:(NSString *)fullPath;

- (void) setDestinationPath: (NSString*) aString;
- (NSString*) destinationPath;

- (void)setRevision:(NSString *)revision;
- (void)setDate:(NSString *)date;
- (void) setRemovesStickyAttributes:(BOOL)flag;
    // Default is NO

- (void) setIsReadOnly:(BOOL)readOnly;

- (NSString *)module;

- (BOOL)fetchingACvsWrappersFile;
- (void)setFetchingACvsWrappersFile:(BOOL)flag;

- (NSString *)finalDestinationPath;
- (void)setFinalDestinationPath:(NSString *)newFinalDestinationPath;


@end
