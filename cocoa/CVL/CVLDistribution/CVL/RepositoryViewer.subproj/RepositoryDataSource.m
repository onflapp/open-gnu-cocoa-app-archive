/* RepositoryDataSource.m created by ja on Mon 15-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "RepositoryDataSource.h"

#import "CvsRepository.h"

@interface CvsRepository (SortedDisplays)
- (NSComparisonResult)compareRoot:(CvsRepository *)theOtherRepository;
@end

@implementation CvsRepository (SortedDisplays)
- (NSComparisonResult)compareRoot:(CvsRepository *)theOtherRepository
{
    return [[self root] compare:[theOtherRepository root]];
}
@end

@implementation RepositoryDataSource
- (void)dealloc
{
    [repositories release];

    [super dealloc];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    [repositories release];
    repositories=[[CvsRepository registeredRepositories] sortedArrayUsingSelector:@selector(compareRoot:)];
    [repositories retain];
    
    return [repositories count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)aRow
	/*" This method returns the object value for the column given by 
		aTableColumn in row given by aRow. aTableColumn contains the identifier 
		for the attribute, which you get by using NSTableColumn’s identifier
		method.

		Note: This method is called each time the table cell needs to be 
		redisplayed, so it must be efficient.
	"*/
{
    CvsRepository *aCvsRepository;
    NSString *columnIdentifier;
	NSNumber *aCompressionLevel = nil;

    aCvsRepository=[repositories objectAtIndex:aRow];
    columnIdentifier=[aTableColumn identifier];

    if ([columnIdentifier isEqualToString:ROOT_KEY]) {
        return [aCvsRepository root];
    }
    if ([columnIdentifier isEqualToString:PASSWORD_KEY]) {
        return @"";
    }
    if ([columnIdentifier isEqualToString:COMPRESSION_LEVEL_KEY]) {
		aCompressionLevel = [aCvsRepository compressionLevel];
        return [aCompressionLevel stringValue];;
    }
    if ([columnIdentifier isEqualToString:@"repositoryStatus"]) {
		if ( [aCvsRepository isRepositoryMarkedForRemoval] == YES ) {
			return @"Removed";
		}		
		if ( [aCvsRepository needsLogin] == YES ) {
			if ( [aCvsRepository isLoggedIn] == YES ) {
				return @"Logged In";
			}			
		}
		return @"";
    }
    if ([columnIdentifier isEqualToString:@"upToDate"]) {
        return [NSNumber numberWithBool:[aCvsRepository isUpToDate]];
    }
    return @"";
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)aRow
	/*" This method sets an attribute value for the record in aTableView at aRow.
		anObject is the new value, and aTableColumn contains the identifier for 
		the attribute, which you get by using NSTableColumn’s identifier method.
	"*/
{
	CvsRepository *aCvsRepository = nil;
    NSString *columnIdentifier = nil;
	NSNumber *aNewCompressionLevel = nil;
	int anInt = 0;
	
    aCvsRepository = [repositories objectAtIndex:aRow];
    columnIdentifier = [aTableColumn identifier];
	
	if ([columnIdentifier isEqualToString:COMPRESSION_LEVEL_KEY]) {
		anInt = [anObject intValue];
		aNewCompressionLevel = [NSNumber numberWithInt:anInt];
        [aCvsRepository setCompressionLevel:aNewCompressionLevel];
    }	
}

- (id)objectAtRow:(int)aRow
{
    return [repositories objectAtIndex:aRow];
}

- (int)rowOfObject:(id)anObject
{
    int result;

    result=[repositories indexOfObject:anObject];
    if (result==NSNotFound)
        result=-1;
    return result;
}
@end
