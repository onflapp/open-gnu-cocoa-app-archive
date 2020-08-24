//
//  CvsEntry.h
//  CVL
//
//  Created by William Swats on Mon Oct 20 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface CvsEntry : NSObject
{
    NSNumber        *doesNotExistsInWorkArea;
    NSNumber        *markedForRemovalAsANumber;
    NSNumber        *markedForAdditionAsANumber;
    NSNumber        *isADirectory;
    NSString        *filename;
    NSString        *inDirectory;
    NSCalendarDate  *dateOfLastCheckout;
    NSString        *revisionInWorkArea;
    NSString        *stickyOptions;
    NSString        *stickyTag;
    NSCalendarDate  *stickyDate;
}
    /*" Class Methods "*/
+ (NSString *) cvsEntriesPathForDirectory:(NSString *)aDirectory;
+ (NSString *) cvsEntriesLogPathForDirectory:(NSString *)aDirectory;
+ (NSArray *) getCvsEntriesForDirectory:(NSString *)aDirectory;
+ (NSString *) readCvsEntriesForDirectory:(NSString *)aDirectory;
+ (NSString *) readCvsEntriesLogForDirectory:(NSString *)aDirectory;
+ (NSString *) readCvsEntriesAndEntriesLogForDirectory:(NSString *)aDirectory;
+ (BOOL) writeCvsEntriesForDirectory:(NSString *)aDirectory withString:(NSString *)aCvsEntriesString;
+ (NSString *) mergeContentsOfEntriesLog:(NSString *)aCvsEntriesLogString intoEntries:(NSString *)aCvsEntriesString forDirectory:(NSString *)aDirectory;
+ (BOOL) deleteEntriesLogForDirectory:(NSString *)aDirectory;
+ (NSString *) getStringTagFromString:(NSString *)aString branchTagEnabled:(BOOL)branchTagEnabledState;
+ (BOOL) doesDirectoryContainAnyCVSFiles:(NSString *)aDirectory;
+ (void) removeCvsEntryWithFilename:(NSString *)aFilename fromDirectory:(NSString *)aDirectory;

    /*" Creation Methods "*/
- (id) initWithFilename:(NSString *)aFilename inDirectory:(NSString *)aDirectory;

    /*" Accessor Methods "*/
- (NSNumber *) doesNotExistsInWorkArea;
- (void) setDoesNotExistsInWorkArea:(NSNumber *)newDoesNotExistsInWorkArea;
- (NSNumber *) markedForRemovalAsANumber;
- (void) setMarkedForRemovalAsANumber:(NSNumber *)newMarkedForRemovalAsANumber;
- (NSNumber *) markedForAdditionAsANumber;
- (void) setMarkedForAdditionAsANumber:(NSNumber *)newMarkedForAdditionAsANumber;
- (NSNumber *) isADirectory;
- (void) setIsADirectory:(NSNumber *)newIsADirectory;
- (NSString *) filename;
- (void) setFilename:(NSString *)newFilename;
- (NSString *) inDirectory;
- (void) setInDirectory:(NSString *)newInDirectory;
- (NSCalendarDate *) dateOfLastCheckout;
- (void) setDateOfLastCheckout:(NSCalendarDate *)newDateOfLastCheckout;
- (NSString *) revisionInWorkArea;
- (void) setRevisionInWorkArea:(NSString *)newRevisionInWorkArea;
- (NSString *) stickyOptions;
- (void) setStickyOptions:(NSString *)newStickyOptions;
- (NSString *) stickyTag;
- (void) setStickyTag:(NSString *)newStickyTag;
- (NSCalendarDate *) stickyDate;
- (void) setStickyDate:(NSCalendarDate *)newStickyDate;

    /*" Cover Methods "*/
- (BOOL) markedForRemoval;
- (BOOL) markedForAddition;

    /*" Helper Methods "*/
- (NSString *) path;
- (void) deleteTheMarkedForRemovalFlag;
- (NSString *) cvsEntriesPath;
- (void) removeCvsEntry;


@end
