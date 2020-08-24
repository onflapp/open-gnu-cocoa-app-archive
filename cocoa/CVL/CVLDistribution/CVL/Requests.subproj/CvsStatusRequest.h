/* CvsStatusRequest.h created by ja on Thu 04-Sep-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import <CvsRequest.h>


#define CVS_STATUS_KEYWORD              @"StatusKey"
#define CVS_VERSION_KEYWORD             @"VersionKey"
#define CVS_REPOSITORY_VERSION_KEYWORD	@"RepositoryVersionKey"
#define CVS_REPOSITORY_PATH_KEYWORD     @"RepositoryPathKey"
#define CVS_LAST_CHECKOUT_DATE_KEYWORD  @"LastCheckoutKey"
#define CVS_STICKY_TAG_KEYWORD          @"StickyTagKey"
#define CVS_STICKY_DATE_KEYWORD         @"StickyDateKey"
#define CVS_STICKY_OPTIONS_KEYWORD      @"StickyOptionsKey"

@class NSMutableDictionary;


extern NSString* CvsStatusExaminingPattern;
extern NSString* CvsStatusStatusPattern;
extern NSString* CvsStatusFilePattern;
extern NSString* CvsStatusRevisionPattern;
extern NSString* CvsStatusRepositoryPattern;
extern NSString* CvsStatusStickyTagPattern;
extern NSString* CvsStatusStickyOptionsPattern;
extern NSString* CvsStatusStickyDatePattern;
extern NSString* CvsStatusLineOfEqualsPattern;


@interface CvsStatusRequest : CvsRequest
{
    NSMutableString *parsingBuffer;
    NSMutableDictionary *result;
}
+ (CvsStatusRequest *)cvsStatusRequestForFiles:(NSArray *)files inPath:(NSString *)aPath;
-(NSDictionary *)result;

- (NSString *) parseFilenameFromString:(NSString *)aString;
- (NSCalendarDate *) parseLastCheckoutDateFromString:(NSString *)aString;
- (NSString *) parseRepositoryPathFromString:(NSString *)aString;
- (NSString *) parseRepositoryRevisionFromString:(NSString *)aString;
- (NSString *) parseStatusFromString:(NSString *)aString;
- (NSCalendarDate *) parseStickyDateFromString:(NSString *)aString;
- (NSString *) parseStickyOptionsFromString:(NSString *)aString;
- (NSString *) parseStickyTagFromString:(NSString *)aString;
- (NSString *) parseWorkAreaRevisionFromString:(NSString *)aString;

- (NSString *)createPathFrom:(NSString *)aFilename andRepositoryPath:(NSString *)aRepositoryPathString;


@end
