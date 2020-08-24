/* CVLOpendiffRequest.h created by stephane on Mon 27-Sep-1999 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


@class CVLFile;
@class NSDictionary;
@class CvsUpdateRequest;


@interface CVLOpendiffRequest : TaskRequest
{
#ifdef JA_PATCH
    NSString *leftPath;
    NSString *rightPath;
    NSString *ancestorPath;
    NSString *mergePath;
    CvsUpdateRequest *leftRequest;
    CvsUpdateRequest *rightRequest;
    CvsUpdateRequest *ancestorRequest;
    BOOL allGetVersionRequestsSucceeded;
#endif
}

+ (BOOL) opendiffIsValid; // Checks if path is not nil
+ (CVLOpendiffRequest *) opendiffRequestForFile:(NSString *)fileFullPath;

- (id) initWithFile:(CVLFile *)file parameters:(NSDictionary *)parameterDictionary;
/*
	ParameterDictionary: keys are evaluated in this order
	LeftRevision, LeftTag, LeftDate: if no value, uses current local file
	RightRevision, RightTag, RightDate: if no value, uses current local file
	AncestorRevision, AncestorTag, AncestorDate: if no value, uses no ancestor
	MergeFile: if no value, use current local file
*/

@end
