//
//  CvsTag.m
//  CVL
//
//  Created by William Swats on Mon Oct 20 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

/*" This class is used in the following two ways.

1.  This class is used to interpret the tag part of the strings that appears in 
    the CVS/Entries and CVS/Tag files that are found in the workarea. 

    In the CVS/Entries the tag part of the string is the sixth item in the line  
    [D]/NAME/REVISION/CHECKOUT_DATE/STICKY_OPTIONS/STICKY_TAG_OR_DATE.
    If there is a sticky tag in STICKY_TAG_OR_DATE then the first character is a
    single letter indicating the type of tag: T for branch tag or non-branch tag 
    and D for date.  The rest of the STICKY_TAG_OR_DATE field is the tag or date
    itself.

    In the CVS/Tag the tag is recorded in the first line of the file. The first 
    character is a single letter indicating the type of tag: T for branch tag, 
    N for non-branch tag and D for date.  The rest of the line is the tag or date
    itself.

    The difference in these two representations of tags causes us not to know if
    a tag is a branch tag for the CVS/Entries file. Hence, we are making the assumption
    in this application that if the directory is a branch directory then all the
    files in it that have a tag are branch tags.

    CAUTION: Sticky non-branch tags are sometines treated as branches in empty
    directories - Bug?
    The problem is that tags do not have an independent existance -- they
    only exist inside RCS files.  Thus, a tag can be a branch tag in one
    file and a non-branch tag in another.  The rule CVS uses is that if the
    tag is a non-branch tag in any file in the directory, then the tag is
    marked as a non-branch tag in the CVS/Tag file; otherwise, it is marked
    as a branch tag, which naturally results in a branch tag in an empty
    directory.  Just one more reason why you should always use -P on
    checkout and update and not try to store empty directories in CVS. But -P
    does not work if there are only sub-directories in a directory.

2.  Instances of this class is used by the CVLFile class to represent its tags 
    instead of using dictionaries.
"*/
#import "CvsTag.h"

#import <SenFoundation/SenFoundation.h>
#import "NSString+CVL.h"
#import "CvsEntry.h"
#import "CVLFile.h"
#import "WorkAreaViewer.h"
#import <SelectorRequest.h>


@implementation CvsTag


+ (BOOL) isDirectoryABranch:(NSString *)aDirectory
    /*" This method returns YES if the path given in aDirectory has a branch 
        tag. Otherwise NO is returned. NO means that either aDirectory has no
        tag or has a tag that is not a branch.

        This method ultimately gets its information from the CVS/Tags file in 
        the directory given in aDirectory.
    "*/
{
    NSString        *aTag = nil;
    BOOL            directoryIsABranch = NO;

    aTag = [self getStringTagForDirectory:aDirectory];
    if ( isNotEmpty(aTag) ) {
        if ( [aTag rangeOfString:@"branch:"].length > 0 ) {
            directoryIsABranch = YES;
        }        
    }
    return directoryIsABranch;
}

+ (NSString *) getStringTagForDirectory:(NSString *)aDirectory
    /*" This method returns a string tag for the directory given in the argument
        aDirectory if one exists otherwise nil is returned. There are two types
        of tags; a string tag and a date tag. This method only returns the 
        string tag.

        This method ultimately gets its information from the CVS/Tags file in 
        the directory given in aDirectory.

        Also see #{-getTagOrDateStringForDirectory: and -getStringTagFromString:} 
        for more information.
    "*/
{
    NSString        *aString = nil;
    NSString        *aTag = nil;
    
    aString = [self getTagOrDateStringForDirectory:aDirectory];
    if ( isNotEmpty(aString) ) {
        aTag = [self getStringTagFromString:aString];
    }
    return aTag;
}

+ (NSCalendarDate *) getDateTagForDirectory:(NSString *)aDirectory
    /*" This method returns a date tag for the directory given in the argument
        aDirectory if one exists otherwise nil is returned. There are two types
        of tags; a string tag and a date tag. This method only returns the 
        date tag.
    
        This method ultimately gets its information from the CVS/Tags file in 
        the directory given in aDirectory.
    
        Also see #{-getTagOrDateStringForDirectory: and -getDateTagFromString:} 
        for more information.
    "*/
{
    NSString        *aString = nil;
    NSCalendarDate  *aDate = nil;

    aString = [self getTagOrDateStringForDirectory:aDirectory];
    if ( isNotEmpty(aString) ) {
        aDate = [self getDateTagFromString:aString];
    }
    return aDate;
}

+ (NSString *) getTagOrDateStringForDirectory:(NSString *)aDirectory
    /*" This method returns a string that represents either a string tag or a 
        date tag for the directory given in the argument
        aDirectory. If none exists then nil is returned.
    
        This method ultimately gets its information from the CVS/Tags file in 
        the directory given in aDirectory.
    "*/
{
    NSString        *cvsTagPath = nil;
    NSString        *aString = nil;
    
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    cvsTagPath = [self cvsTagPathForDirectory:aDirectory];
    
    if ( [[NSFileManager defaultManager] senFileExistsAtPath:cvsTagPath] == NO ) {
        return nil;
    }
    
    aString = [NSString stringWithContentsOfFile:cvsTagPath];
    if( aString == nil ) {
        // Error: cvs Tag String was nil.
        NSString *aTitle = nil;
        NSString *aMessage = nil;
        
        aTitle = [NSString stringWithFormat:@"CVL Warning"];
        aMessage = [NSString stringWithFormat:
            @"The CVS Tag file \"%@\" could not be opened for reading.",
            cvsTagPath];
        (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
    }
    return aString;
}

+ (NSString *) getStringTagFromString:(NSString *)aString
    /*" This method returns a string tag from the string given in the argument
        aString. If aString is nil or empty then nil is returned.
    
        The string in aString is of the form of a code letter in the first 
        column and a string tag or date tag starting in the second column and 
        running until the end of the line. The code letters are a single letter
        indicating the type of tag: T for branch tag, N for non-branch tag and D
        for date. If this is a branch tag then the string "branch: " is inserted 
        before the tag string and then the whole string is enclosed in 
        parenthesis.
    "*/
{
    unichar         aTagCode = 0;
    NSString        *aTagOrDate = nil;
    NSString        *aTagOrDateString = nil;
    NSString        *aTag = nil;
    NSString        *aMsg = nil;
    
    if ( isNotEmpty(aString) ) {
        aTagCode = [aString characterAtIndex:0];
        aTagOrDateString = [aString substringFromIndex:1];
        // Removing trailing whitespace.
        aTagOrDate = [aTagOrDateString removeTrailingWhiteSpace];    
        switch (aTagCode) {
            case 'T': // branch tag
                aTag = [NSString stringWithFormat:@"(branch: %@)", aTagOrDate];
                break;
            case 'D': // date tag
                break;
            case 'N': // non-branch/non-date tag
                aTag = aTagOrDate;
                break;
            default:
                aMsg = [NSString stringWithFormat:
                    @"Unable to parse the string \"%@\" into a tag or date! The tag code of \"%c\" is unknown to this application. Known codes are T, D and N.", 
                    aString, aTagCode];
                SEN_ASSERT_CONDITION_MSG((NO), aMsg);
        }
    }
    return aTag;
}

+ (NSCalendarDate *) getDateTagFromString:(NSString *)aString
    /*" This method returns a date tag from the string given in the argument
        aString. If aString is nil or empty then nil is returned.

        The string in aString is of the form of a code letter in the first 
        column and a string tag or date tag starting in the second column and 
        running until the end of the line. The code letters are a single letter
        indicating the type of tag: T for branch tag, N for non-branch tag and D
        for date.
    "*/
{
    unichar         aTagCode = 0;
    NSString        *aTagOrDate = nil;
    NSCalendarDate  *aDate = nil;
    NSString        *aMsg = nil;

    if ( isNotEmpty(aString) ) {
        aTagCode = [aString characterAtIndex:0];
        aTagOrDate = [aString substringFromIndex:1];
        switch (aTagCode) {
            case 'T': // branch tag
                break;
            case 'D': // date tag
                aDate = [NSCalendarDate dateWithString:aTagOrDate 
                                        calendarFormat:@"%Y.%d.%m.%H.%M.%S"];
                break;
            case 'N': // non-branch/non-date tag
                break;
            default:
                aMsg = [NSString stringWithFormat:
                    @"Unable to parse the string \"%@\" into a tag or date! The tag code of \"%c\" is unknown to this application. Known codes are T, D and N.", 
                    aString, aTagCode];
                SEN_ASSERT_CONDITION_MSG((NO), aMsg);
        }
    }
    return aDate;
}

+ (NSArray *) checkTheTagsForViewer:(WorkAreaViewer *)aViewer
    /*" This method examines all the Tags files in the CVS directories in the 
        workarea being viewed by aViewer. If all of them are non-branch except 
        the ones in empty directories then the user is asked if he would like to
        overwrite them. Here empty directories means ones without CVS files, 
        there could be sub-directories. An array of these empty directories with
        branch tags is returned. If there are none then an empty array is 
        returned.
    "*/
{
    NSString *aWorkArea = nil;
    NSString *cvsTagPath = nil;
    NSString *aPath = nil;
    NSString *aRelativePath = nil;
    NSString *aDirectory = nil;
    CVLFile *aCVLFile = nil;
    NSFileManager	*fileManager = nil;
    NSDirectoryEnumerator *directoryEnumerator = nil;
    NSMutableArray *directoriesWithEmptyBranchTags = nil;
    int aChoice = NSAlertDefaultReturn;
    BOOL aBranchTagWasFound = NO;
    BOOL anEmptyBranchTagWasFound = NO;
    unsigned int aCount = 0;
    
    SEN_ASSERT_NOT_NIL(aViewer);

    aWorkArea = [aViewer rootPath];
    if ( isNilOrEmpty(aWorkArea) ) return nil;
    
    directoriesWithEmptyBranchTags = [NSMutableArray arrayWithCapacity:3];
    
    cvsTagPath = [self cvsTagPathForDirectory:aWorkArea];
    
    fileManager = [NSFileManager defaultManager];
    if ( [fileManager senFileExistsAtPath:cvsTagPath] == YES ) {
        directoryEnumerator = [fileManager enumeratorAtPath:aWorkArea];
        if ( directoryEnumerator != nil ) {
            // Examine all the Tags files.
            while ( (aRelativePath = [directoryEnumerator nextObject]) ) {
                if ( [aRelativePath hasSuffix:@"CVS/Tag"] == YES ) {
                    aPath = [aWorkArea stringByAppendingPathComponent:aRelativePath];
                    // Delete the Tag part.
                    aDirectory = [aPath stringByDeletingLastPathComponent];
                    // Delete the CVS part.
                    aDirectory = [aDirectory stringByDeletingLastPathComponent];                    
                    if ( isNotEmpty(aDirectory) ) {
                        if ( [self isDirectoryABranch:aDirectory] == YES ) {
                            if ( [CvsEntry doesDirectoryContainAnyCVSFiles:aDirectory] ) {
                                // This is a real branch.
                                aBranchTagWasFound = YES;
                            } else {
                                aCVLFile = (CVLFile *)[CVLFile treeAtPath:aDirectory];
                                if ( [aCVLFile isIgnored] == NO ) {
                                    // This may or may not be a branch.
                                    anEmptyBranchTagWasFound = YES;
                                    [directoriesWithEmptyBranchTags addObject:aDirectory];                                    
                                }
                            }
                        }
                    }
                }
            }
        }
        if ( (aBranchTagWasFound == NO) && 
             (anEmptyBranchTagWasFound == YES) ) {
            aCount = [directoriesWithEmptyBranchTags count];
            if ( aCount == 1 ) {
				// This is the single directory version of the alert panel.
                aDirectory = [directoriesWithEmptyBranchTags objectAtIndex:0];
                aChoice = NSRunAlertPanel(@"Branch Tag Warning", 
                                          @"The empty directory \"%@\" had a branch tag while all the other directories had non-branch tags. This is a because CVS will tag an empty directory as a branch tag since it has no information via files in that directory to determine otherwise. But since all the other directories have non-branch tags; CVL suspects that this directory should also be non-branch. Would you like CVL to change this directory to a non-branch tag.\n\nNote: by empty directory we mean ones without any files under CVS control. These directories may have, and probably do have, sub-directories.",
                                          @"NO, do not change", @"YES, change to a non-branch tag", nil, aDirectory); 
            } else {
				// This is the multple directories version of the alert panel.
                aChoice = NSRunAlertPanel(@"Branch Tag Warning", 
                                          @"There were %d empty directories that had a branch tag while all the other directories had non-branch tags. This is a because CVS will tag an empty directory as a branch tag since it has no information via files in that directory to determine otherwise. But since all the other directories have non-branch tags; CVL suspects that these directories should also be non-branch. Would you like CVL to change these directories to a non-branch tag.\n\nNote: by empty directory we mean ones without any files under CVS control. These directories may have, and probably do have, sub-directories.",
							  @"YES, change to a non-branch tag", 
							  @"NO, do not change", nil, aCount); 
            }
            if ( aChoice == NSAlertDefaultReturn ) {
                [self changeTagsToNonBranch:directoriesWithEmptyBranchTags];
            }            
        }
    }    
    [[directoriesWithEmptyBranchTags retain] autorelease];
    return directoriesWithEmptyBranchTags;
}

+ (void) changeTagsToNonBranch:(NSArray *)someDirectories
    /*" This method rewrites the Tags file in the CVS directories in the 
        directories listed in the array someDirectories so that the tags are 
        coded as non-branch tags. An exception is raised if the tag code in the
        Tags file is not a "T". Note; this method expects the CVS/Tags files in 
        someDirectories to be branch tags (i.e. to have a tag code of "T").

        See also #{-checkTheTagsForViewer:}
    "*/
{
    NSString *aDirectory = nil;
    NSString *aString = nil;
    NSString *aNewString = nil;
    NSString *aMsg = nil;
    NSEnumerator *anEnumerator = nil;
    unichar aTagCode = 0;

    if ( isNilOrEmpty(someDirectories) ) return;
    
    anEnumerator = [someDirectories objectEnumerator];
    while ( (aDirectory = [anEnumerator nextObject]) ) {
        aString = [self getTagOrDateStringForDirectory:aDirectory];
        
        // Note: It is possible that by the time we get here some other code
        // has already deleted this directory. So if aString is nil or empty,
        // we ignore this directory.
        if ( isNilOrEmpty(aString) ) continue;
        
        aTagCode = [aString characterAtIndex:0];
        // Test tag code; It should be a 'T'.
        switch (aTagCode) {
            case 'T': // branch tag
                break;
            case 'D': // date tag
            case 'N': // non-branch/non-date tag
            default:
                aMsg = [NSString stringWithFormat:
                    @"Unable to parse the string \"%@\" into a branch tag! The tag code should be T but was \"%c\" instead. Known codes are T, D and N. This occurred for directory \"%@\".", 
                    aString, aTagCode, aDirectory];
                SEN_ASSERT_CONDITION_MSG((NO), aMsg);
        }
        // End of Test tag code.
        aNewString = [NSString stringWithFormat:@"N%@",
            [aString substringFromIndex:1]];
        
        [self  writeCvsTagFileForDirectory:aDirectory withString:aNewString];
    }
}

+ (NSString *) cvsTagPathForDirectory:(NSString *)aDirectory
    /*" This method returns the standardized path to the Entries file in the CVS
        directory that resides in aDirectory. For example if the path in 
        aDirectory is "/Users/jdoe/Projects/TestProject" then this method would
        return "/Users/jdoe/Projects/TestProject/CVS/Entries".
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *cvsEntriesPath = nil;
    NSString        *cvsEntriesPathStandardized = nil;
    
    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];
    cvsEntriesPath = [cvsDirectory stringByAppendingPathComponent:@"Tag"];
    cvsEntriesPathStandardized = [cvsEntriesPath stringByStandardizingPath];
    
    return cvsEntriesPathStandardized;
}

+ (BOOL) writeCvsTagFileForDirectory:(NSString *)aDirectory withString:(NSString *)aCvsTagString
    /*" This method returns YES if it was able to write out a new CVS/Entries 
        file with contents equal to the string aCvsTagString. The containing 
        directory path is given in the argument aDirectory. NO is return if this
        method was not successful. An exception is raised if aDirectory is nil,
        empty or does not exists. An exception is raised if aCvsTagString is
        nil. Note; if aCvsTagString is empty then an empty CVS/Entries file
        is written out.
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *cvsDirectoryStandardized = nil;
    NSString        *cvsTagPath = nil;
    NSFileManager   *fileManager = nil;
    BOOL            results = NO;
    
    // Lets check to make sure aCvsTagString is not nil.
    SEN_ASSERT_NOT_NIL(aCvsTagString);
    
    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    fileManager = [NSFileManager defaultManager];
    SEN_ASSERT_CONDITION(([fileManager senDirectoryExistsAtPath:aDirectory] == YES));
    
    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];    
    cvsDirectoryStandardized = [cvsDirectory stringByStandardizingPath];    
    if ( [fileManager senDirectoryExistsAtPath:cvsDirectoryStandardized] == YES ) {
        cvsTagPath = [self cvsTagPathForDirectory:aDirectory];
        if ([fileManager senFileExistsAtPath:cvsTagPath] == YES) {
            // Write out backup file.
            // Not implemeted.
        }
        results = [aCvsTagString writeToFile:cvsTagPath atomically:YES];
    } else {
        // Error: cvsDirectory does not exists.
        NSString *aTitle = nil;
        NSString *aMessage = nil;
        
        aTitle = [NSString stringWithFormat:@"CVL Warning"];
        aMessage = [NSString stringWithFormat:
            @"The CVS Directory \"%@\" does not exists.",
            cvsDirectory];
        (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil); 
        results = NO;
    }
    
    return results;
}

- (NSString *)tagTitle
    /*" This is the get method for the instance variable tagTitle. The tag title
        is the string representation of the tag.

        See also #{-setTagTitle:}
    "*/
{
	return tagTitle;
}

- (void)setTagTitle:(NSString *)newTagTitle
    /*" This is the set method for the instance variable tagTitle. The tag title
        is the string representation of the tag.

        See also #{-tagTitle}
    "*/
{
    ASSIGN(tagTitle, newTagTitle);
}

- (NSNumber *)isABranchTagAsANumber
    /*" This is the get method for the isABranchTagAsANumber state expressed 
        as a NSNumber (1 is YES and 0 is NO). This variable means that this tag 
        represents a branch.

        See also #{-setIsABranchTagAsANumber:}
    "*/
{
	return isABranchTagAsANumber;
}

- (void)setIsABranchTagAsANumber:(NSNumber *)newIsABranchTagAsANumber
    /*" This is the set method for the isABranchTagAsANumber state expressed 
        as a NSNumber (1 is YES and 0 is NO). This variable means that this tag 
        represents a branch.

        See also #{-isABranchTagAsANumber}
    "*/
{
    ASSIGN(isABranchTagAsANumber, newIsABranchTagAsANumber);
}

- (BOOL)isABranchTag
    /*" This is a cover method for the method -isABranchTagAsANumber. This
        method interperts the return value of the method 
        -isABranchTagAsANumber and returns either YES or NO based whether 
        the returned value is non-zero or not. If this return value is nil then
        this method returns NO.

        See also #{-isABranchTagAsANumber}.
    "*/
{
    NSNumber *aBooleanNumber = nil;
    BOOL isABranchTag = NO;
    
    aBooleanNumber = [self isABranchTagAsANumber];
    if ( aBooleanNumber != nil ) {
        isABranchTag = [aBooleanNumber boolValue];
    }
    
    return isABranchTag;
}

- (void)setIsABranchTag:(BOOL)newIsABranchTag
    /*" This is a cover method for the method -setIsABranchTagAsANumber:. This
        method takes the value of newIsABranchTag and wraps it in an NSNumber 
        and then calls the method -setIsABranchTagAsANumber: with this number.

        See also #{-setIsABranchTagAsANumber:}.
    "*/
{
    NSNumber *aBooleanNumber = nil;

    aBooleanNumber = [NSNumber numberWithBool:newIsABranchTag];
    [self setIsABranchTagAsANumber:aBooleanNumber];
}

- (NSString *)tagRevision
    /*" This is the get method for the instance variable tagRevision. The tag revision
        is the string representation of the tag's revision.

        See also #{-setTagRevision:}
    "*/
{
	return tagRevision;
}

- (void)setTagRevision:(NSString *)newTagRevision
    /*" This is the set method for the instance variable tagRevision. The tag 
        revision is the string representation of the tag's revision.

        See also #{-tagRevision}
    "*/
{
    ASSIGN(tagRevision, newTagRevision);
}

- (BOOL)isANonBranchTag
    /*" This is a convenience method. It returns YES if this tag is not a branch
        tag; otherwise NO is returned.
    "*/
{
    return ![self isABranchTag];
}

- (NSString *)description
    /*" This method overrides supers implementation. Here we return the tagTitle,
        tagRevision and isABranchTag.
    "*/
{
    return [NSString stringWithFormat:
        @"%@: tagTitle = %@, tagRevision = %@, isABranchTag = %@", 
        [super description], tagTitle, tagRevision, 
        ([self isABranchTag] ? @"YES" : @"NO")];
}

- (NSComparisonResult)compare:(CvsTag *)aCvsTag
    /*" This method returns NSOrderedAscending if the tag title of the receiver 
        precedes the tag title of aCvsTag in lexical ordering, NSOrderedSame if
        the tag title of the receiver and aCvsTag are equivalent in lexical 
        value, and NSOrderedDescending if the tag title of the receiver follows 
        aCvsTag.
    "*/
{
    return [[self tagTitle] caseInsensitiveCompare:[aCvsTag tagTitle]];
}

- (NSComparisonResult)compareRevision:(CvsTag *)aCvsTag
    /*" This method returns NSOrderedAscending if the tag revision of the receiver 
        precedes the tag revision of aCvsTag in lexical ordering, NSOrderedSame if
        the tag revision of the receiver and aCvsTag are equivalent in lexical 
        value, and NSOrderedDescending if the tag revision of the receiver follows 
        aCvsTag.
    "*/
{
    NSString *aString = [aCvsTag tagRevision];
    NSEnumerator* myEnum= [[[self tagRevision] componentsSeparatedByString: @"."] objectEnumerator];
    NSEnumerator* anEnum= [[aString componentsSeparatedByString: @"."] objectEnumerator];
    NSString* mySub= [myEnum nextObject];
    NSString* aSub= [anEnum nextObject];
    NSComparisonResult lastCompare = NSOrderedSame;
    
    while ((lastCompare == NSOrderedSame) && mySub && aSub)
    {
        int myValue= [mySub intValue];
        int aValue= [aSub intValue];
        
        lastCompare= (myValue == aValue ? NSOrderedSame : (myValue < aValue ? NSOrderedAscending : NSOrderedDescending));
        mySub= [myEnum nextObject];
        aSub= [anEnum nextObject];
    }
    if (lastCompare == NSOrderedSame)
    {
        if ((!mySub) && (!aSub))
        {
            return lastCompare;
        }
        else if (!mySub)
        {
            return NSOrderedAscending;
        }
        else return NSOrderedDescending;
    }
    return lastCompare;
}

- (BOOL)isEqual:(id)anObject
    /*" This method returns YES if the receiver and anObject are equal, NO 
        otherwise. Two CvsTag objects are said to be equal if their tag titles 
        are equal.

        See the method -allCommonCvsTagsInRequest: in the class 
        ResultsRepository for where this method is needed.

        If two objects are equal, they must have the same hash value. This last 
        point is particularly important if you define isEqual: in a subclass and
        intend to put instances of that subclass into a collection. Make sure 
        you also define hash in your subclass.
    "*/
{
    // We need this method so that we can put instances of this class in a set
    // and then intersect that set with another set. We also need the -hash 
    // method below for this to work in a collection.
    if ( self == anObject ) return YES;
    if ( [anObject isMemberOfClass:[self class]] == YES ) {
        if ( [[self tagTitle] isEqual:[anObject tagTitle]] ) return YES;
    }
    return NO;
}

- (unsigned)hash
    /*" Returns an unsigned integer that can be used as a hash table address. 
        This method just returns the hash value of its tag title.

        See the method -allCommonCvsTagsInRequest: in the class 
        ResultsRepository for where this method is needed.
    "*/
{
    // We need this method so that we can put instances of this class in a set
    // and then intersect that set with another set. We also need the -isEqual: 
    // method above for this to work in a collection.    
    return [[self tagTitle] hash];
}


@end
