//
//  CvsTag.h
//  CVL
//
//  Created by William Swats on Mon Oct 20 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class WorkAreaViewer;


@interface CvsTag : NSObject {
    NSString *tagTitle;
    NSString *tagRevision;
    NSNumber *isABranchTagAsANumber;
}


+ (BOOL) isDirectoryABranch:(NSString *)aDirectory;
+ (NSString *) getStringTagForDirectory:(NSString *)aDirectory;
+ (NSCalendarDate *) getDateTagForDirectory:(NSString *)aDirectory;
+ (NSString *) getTagOrDateStringForDirectory:(NSString *)aDirectory;
+ (NSString *) getStringTagFromString:(NSString *)aString;
+ (NSCalendarDate *) getDateTagFromString:(NSString *)aString;
+ (NSArray *) checkTheTagsForViewer:(WorkAreaViewer *)aViewer;
+ (void) changeTagsToNonBranch:(NSArray *)someDirectories;
+ (NSString *) cvsTagPathForDirectory:(NSString *)aDirectory;
+ (BOOL) writeCvsTagFileForDirectory:(NSString *)aDirectory withString:(NSString *)aCvsTagString;


- (NSString *)tagTitle;
- (void)setTagTitle:(NSString *)newTagTitle;
- (NSNumber *)isABranchTagAsANumber;
- (void)setIsABranchTagAsANumber:(NSNumber *)newIsABranchTagAsANumber;
- (NSString *)tagRevision;
- (void)setTagRevision:(NSString *)newTagRevision;

- (BOOL)isABranchTag;
- (void)setIsABranchTag:(BOOL)newIsABranchTag;

- (NSComparisonResult)compare:(CvsTag *)aCvsTag;
- (NSComparisonResult)compareRevision:(CvsTag *)aCvsTag;

- (BOOL)isANonBranchTag;


@end
