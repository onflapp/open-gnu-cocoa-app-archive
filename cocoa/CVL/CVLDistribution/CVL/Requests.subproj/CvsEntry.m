//
//  CvsEntry.m
//  CVL
//
//  Created by William Swats on Mon Oct 20 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

/*" This class is used to interpret the entries that appears in 
    the CVS/Entries files that are found in the workarea. This includes reading
    the file and parsing it into the instance variables of this classes objects.


	The CVS/Entrie file lists the files and directories in the working directory.
	The first character of each line indicates what sort of line it is. If the 
	character is unrecognized, programs reading the file should silently skip 
	that line, to allow for future expansion.

	If the first character is "/", then the format is:

	/name/revision/timestamp[+conflict]/options/tagdate

	where "[" and "]" are not part of the entry, but instead indicate that the 
	"+" and conflict marker are optional. name is the name of the file within 
	the directory. revision is the revision that the file in the working derives
	from, or "0" for an added file, or "-" followed by a revision for a removed
	file. timestamp is the timestamp of the file at the time that CVS created 
	it; if the timestamp differs with the actual modification time of the file 
	it means the file has been modified. It is stored in the format used by the 
	ISO C asctime() function (for example, "Sun Apr 7 01:29:26 1996"). One may 
	write a string which is not in that format, for example, "Result of merge",
	to indicate that the file should always be considered to be modified. This 
	is not a special case; to see whether a file is modified a program should 
	take the timestamp of the file and simply do a string compare with timestamp.
	If there was a conflict, conflict can be set to the modification time of the 
	file after the file has been written with conflict markers (see section 
	Conflicts example). Thus if conflict is subsequently the same as the actual 
	modification time of the file it means that the user has obviously not 
	resolved the conflict. options contains sticky options (for example "-kb" 
	for a binary file). tagdate contains "T" followed by a tag name, or "D" for
	a date, followed by a sticky tag or date. Note that if timestamp contains a 
	pair of timestamps separated by a space, rather than a single timestamp, you
	are dealing with a version of CVS earlier than CVS 1.5 (not documented here).

	The timezone on the timestamp in CVS/Entries (local or universal) should be 
	the same as the operating system stores for the timestamp of the file itself.
	For example, on Unix the file's timestamp is in universal time (UT), so the 
	timestamp in CVS/Entries should be too. On VMS, the file's timestamp is in 
	local time, so CVS on VMS should use local time. This rule is so that files
	do not appear to be modified merely because the timezone changed (for 
	example, to or from summer time).

	If the first character of a line in "Entries" is "D", then it indicates a 
	subdirectory. "D" on a line all by itself indicates that the program which
	wrote the "Entries" file does record subdirectories (therefore, if there is
	such a line and no other lines beginning with "D", one knows there are no 
	subdirectories). Otherwise, the line looks like:

	D/name/filler1/filler2/filler3/filler4

	where name is the name of the subdirectory, and all the filler fields should
	be silently ignored, for future expansion. Programs which modify Entries
	files should preserve these fields.

	The lines in the "Entries" file can be in any order.

	" Entries.Log "

	This file does not record any information beyond that in "Entries" file, 
	including the ability to preserve the information even if the program 
	writing "Entries" and "Entries.Log" abruptly aborts. Programs which are 
	reading the "Entries". If the latter exists, they should read "Entries" and 
	then apply the changes mentioned in "Entries.Log". After applying the 
	changes, the recommended practice is to rewrite "Entries" and then delete 
	"Entries.Log". The format of a line in "Entries.Log" is a single character 
	command followed by a space followed by a line in the format specified for a
	line in "Entries". The single character command is "A" to indicate that the
	entry is being added, "R" should be silently ignored (for future expansion).
	If the second character of the line in "Entries.Log" is not a space, then it
	was written by an older version of CVS (not documented here).

	Programs which are writing rather than reading can safely ignore 
	"Entries.Log" if they so choose.

	" Entries.Backup "

	This is a temporary file. Recommended usage is to write a new entries file
	to "Entries.Backup", and then to rename it (atomically, where possible) to 
	"Entries".

	" Entries.Static "

	The only relevant thing about this file is whether it exists or not. If it 
	exists, then it means that only part of a directory was gotten and CVS will 
	not create additional files in that directory. To clear it, use the update 
	command with the "-d" option, which will get the additional files and remove
	"Entries.Static".

"*/
#import "CvsEntry.h"

#import <SenFoundation/SenFoundation.h>
#import "NSFileManager_CVS.h"
#import <NSString+Lines.h>
#import <CvsTag.h>
#import <CVLConsoleController.h>
#import "NSString+CVL.h"



@implementation CvsEntry


+ (NSString *) cvsEntriesPathForDirectory:(NSString *)aDirectory
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
    cvsEntriesPath = [cvsDirectory stringByAppendingPathComponent:@"Entries"];
    cvsEntriesPathStandardized = [cvsEntriesPath stringByStandardizingPath];
    
    return cvsEntriesPathStandardized;
}

+ (NSString *) cvsEntriesLogPathForDirectory:(NSString *)aDirectory
    /*" This method returns the standardized path to the Entries.Log file in the
        CVS directory that resides in aDirectory. For example if the path in 
        aDirectory is "/Users/jdoe/Projects/TestProject" then this method would
        return "/Users/jdoe/Projects/TestProject/CVS/Entries.Log".
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *cvsEntriesLogPath = nil;
    NSString        *cvsEntriesLogPathStandardized = nil;
    
    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];
    cvsEntriesLogPath = [cvsDirectory stringByAppendingPathComponent:@"Entries.Log"];
    cvsEntriesLogPathStandardized = [cvsEntriesLogPath stringByStandardizingPath];
    
    return cvsEntriesLogPathStandardized;
}

+ (NSString *) readCvsEntriesAndEntriesLogForDirectory:(NSString *)aDirectory
    /*" This method returns the combined contents of the Entries file and the 
        Entries.Log file in the CVS sub-directory of the directory given in 
        aDirectory as a string. This method will return nil if there is no CVS 
        sub-directory or if the Entries file or the Entries.log file does not 
        exists or if an error occurred while trying to read these files.
    "*/
{
    NSString        *cvsMergedEntriesString = nil;
    NSString        *cvsEntriesString = nil;
    NSString        *cvsEntriesLogString = nil;
    NSString        *aMsg = nil;
    NSFileManager   *fileManager = nil;
    NSString        *cvsEntriesLogPath = nil;
    BOOL            success = NO;

    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    // If aDirectory does not exists then just return nil.
    fileManager = [NSFileManager defaultManager];
    if ( [fileManager senDirectoryExistsAtPath:aDirectory] == NO ) {
        //aMsg = [NSString stringWithFormat:
        //    @"The directory \"%@\" does not exist.",
        //    aDirectory];
        //SEN_LOG(aMsg);
        return nil;
    }
    
    // If CVS/Entries and CVS/Entries.Log do not exists then just return nil.
    cvsEntriesString = [self readCvsEntriesForDirectory:aDirectory];
    cvsEntriesLogString = [self readCvsEntriesLogForDirectory:aDirectory];
    if ( isNilOrEmpty(cvsEntriesString) &&
         isNilOrEmpty(cvsEntriesLogString) ) {
        return nil;
    }
    
    // If CVS/Entries.Log exists then merge it into CVS/Entries
    // and then delete it.
    if ( isNotEmpty(cvsEntriesLogString) ) {
        // Write a message to the Console that we are merging the Entries.Log
        // with the Entries file.
        aMsg = [NSString stringWithFormat:
            @"CVL is merging the Entries.Log  with the Entries file in the directory \"%@\".\n",
            aDirectory];
        [[CVLConsoleController sharedConsoleController] output:aMsg];
        // Perform the merge.
        cvsMergedEntriesString = [self 
                                mergeContentsOfEntriesLog:cvsEntriesLogString 
                                              intoEntries:cvsEntriesString
                                             forDirectory:aDirectory];
        // If we get back a nil string subsitute an empty string.
        if ( cvsMergedEntriesString == nil ) {
            cvsMergedEntriesString = @"";
        }
        // Need to write then new merged contents back to file.
        // But only if we are able to delete the Entries.Log file.
        cvsEntriesLogPath = [self cvsEntriesLogPathForDirectory:aDirectory];
        if ([fileManager isDeletableFileAtPath:cvsEntriesLogPath] == YES) {
            success = [CvsEntry writeCvsEntriesForDirectory:aDirectory 
                                            withString:cvsMergedEntriesString];
        } else {
            aMsg = [NSString stringWithFormat:
                @"Cannot delete the CVS Entries.Log file at \"%@\".", 
                cvsEntriesLogPath];
            SEN_LOG(aMsg);
        }
        if( success == YES ) {
            (void)[self deleteEntriesLogForDirectory:aDirectory];
        } else {
            // Could not write the CVS/Entries file.
            NSString *aTitle = nil;
            NSString *aMessage = nil;
            NSString *cvsDirectory = nil;
            
            aTitle = [NSString stringWithFormat:@"CVL Warning"];
            cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];
            aMessage = [NSString stringWithFormat:
                @"Could not write a new CVS Entries file containing the merger of the CVS Entries file the CVS Entries.Log file in the CVS Directory \"%@\".",
                cvsDirectory];
            (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
        }                    
    } else {
        cvsMergedEntriesString = cvsEntriesString;
    }
    return cvsMergedEntriesString;
}

+ (NSString *) readCvsEntriesForDirectory:(NSString *)aDirectory
    /*" This method returns the contents of the Entries file in the CVS 
        sub-directory of the directory given in aDirectory as a string. This 
        method will return nil if there is no CVS sub-directory or if the 
        Entries file does not exists or if an error occurred while trying to 
        read this file.
    "*/
{
    NSString        *cvsEntriesPath = nil;
    NSString        *cvsEntriesString = nil;
    NSFileManager   *fileManager = nil;
    
    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    // If aDirectory does not exists then just return nil.
    fileManager = [NSFileManager defaultManager];
    if ( [fileManager senDirectoryExistsAtPath:aDirectory] == NO ) {
        NSString *aMsg = [NSString stringWithFormat:
                            @"The directory \"%@\" does not exist.",
                            aDirectory];
        SEN_LOG(aMsg);
        return nil;
    }
    
    // If CVS/Entries does not exists then just return nil.
    cvsEntriesPath = [self cvsEntriesPathForDirectory:aDirectory];
    if ( [fileManager senFileExistsAtPath:cvsEntriesPath] == NO ) {
        return nil;
    }
    
    cvsEntriesString = [NSString stringWithContentsOfFile:cvsEntriesPath];
    // Test to see if we could actually read the file.
    if( cvsEntriesString == nil ) {
        // Error: cvsEntriesString was nil.
        NSString *aTitle = nil;
        NSString *aMessage = nil;
        
        aTitle = [NSString stringWithFormat:@"CVL Warning"];
        aMessage = [NSString stringWithFormat:
            @"The CVS Entries file \"%@\" could not be opened for reading.",
            cvsEntriesPath];
        (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
        return nil;
    }
    return cvsEntriesString;
}

+ (NSString *) readCvsEntriesLogForDirectory:(NSString *)aDirectory
    /*" This method returns the contents of the Entries.Log file in the CVS 
        sub-directory of the directory given in aDirectory as a string. This 
        method will return nil if there is no CVS sub-directory or if the 
        Entries.Log file does not exists or if an error occurred while trying to 
        read this file.
    "*/
{
    NSString        *cvsEntriesLogPath = nil;
    NSString        *cvsEntriesLogString = nil;
    NSFileManager   *fileManager = nil;
    
    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    // If aDirectory does not exists then just return nil.
    fileManager = [NSFileManager defaultManager];
    if ( [fileManager senDirectoryExistsAtPath:aDirectory] == NO ) {
        NSString *aMsg = [NSString stringWithFormat:
            @"The directory \"%@\" does not exist.",
            aDirectory];
        SEN_LOG(aMsg);
        return nil;
    }
        
    // If CVS/Entries.Log does not exists then just return nil.
    cvsEntriesLogPath = [self cvsEntriesLogPathForDirectory:aDirectory];
    if ( [fileManager senFileExistsAtPath:cvsEntriesLogPath] == NO ) {
        return nil;
    }
    
    cvsEntriesLogString = [NSString stringWithContentsOfFile:cvsEntriesLogPath];
    // Test to see if we could actually read the file.
    if( cvsEntriesLogString == nil ) {
        // Error: cvsEntriesLogString was nil.
        NSString *aTitle = nil;
        NSString *aMessage = nil;
        
        aTitle = [NSString stringWithFormat:@"CVL Warning"];
        aMessage = [NSString stringWithFormat:
            @"The CVS Entries.Log file \"%@\" could not be opened for reading.",
            cvsEntriesLogPath];
        (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
        return nil;
    }
    return cvsEntriesLogString;
}

+ (BOOL) writeCvsEntriesForDirectory:(NSString *)aDirectory withString:(NSString *)aCvsEntriesString
    /*" This method returns YES if it was able to write out a new CVS/Entries 
        file with contents equal to the string aCvsEntriesString. The containing 
        directory path is given in the argument aDirectory. NO is return if this
        method was not successful. An exception is raised if aDirectory is nil,
        empty or does not exists. An exception is raised if aCvsEntriesString is
        nil. Note; if aCvsEntriesString is empty then an empty CVS/Entries file
        is written out.
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *cvsDirectoryStandardized = nil;
    NSString        *cvsEntriesPath = nil;
    NSFileManager   *fileManager = nil;
    BOOL            results = NO;
    
    // Lets check to make sure aCvsEntriesString is not nil.
    SEN_ASSERT_NOT_NIL(aCvsEntriesString);

    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    fileManager = [NSFileManager defaultManager];
    SEN_ASSERT_CONDITION(([fileManager senDirectoryExistsAtPath:aDirectory] == YES));
    
    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];    
    cvsDirectoryStandardized = [cvsDirectory stringByStandardizingPath];    
    if ( [fileManager senDirectoryExistsAtPath:cvsDirectoryStandardized] == YES ) {
        cvsEntriesPath = [self cvsEntriesPathForDirectory:aDirectory];
        if ([fileManager senFileExistsAtPath:cvsEntriesPath] == YES) {
            // Write out backup file.
            // Not implemeted.
        }
        results = [aCvsEntriesString writeToFile:cvsEntriesPath atomically:YES];
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

+ (NSArray *) getCvsEntriesForDirectory:(NSString *)aDirectory
    /*" This method returns an array of CvsEntry objects created from the
        the Entries file and the Entries.Log file in the CVS sub-directory of
        the directory given in aDirectory. There will be one CvsEntry object 
        created for each line in the combined content of thes two files. This 
        method will return nil if there is no Entries file or Entries.Log file
        or if their combined content is empty.
    "*/
{
    NSMutableArray  *someCvsEntries = nil;
    NSString        *cvsEntriesString = nil;

    // Lets check to make sure aDirectory is not empty.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    cvsEntriesString = [self readCvsEntriesAndEntriesLogForDirectory:aDirectory];
    
    // We start the parsing of the CVS/Entries file here.
    if( isNotEmpty(cvsEntriesString) ) {
        NSArray         *lines = [cvsEntriesString lines];
        NSString        *aLine = nil;
        NSArray         *cvsEntryInfos = nil;
        CvsEntry        *aCvsEntry = nil;
        NSString        *aFilename = nil;
        NSString        *aStickyDateOrTag = nil;
        NSString        *aTag = nil;
        NSString        *aCvsEntryDirectory = nil;
        NSString        *aRevision = nil;
        NSString        *firstCharacter = nil;
        NSCalendarDate  *aDate = nil;
        unsigned int    lineCount = [lines count];
        unsigned int    lineIndex = 0;
        BOOL            isMyDirectoryABranch = NO;
        
        SEN_ASSERT_CONDITION((lineCount > 0));
        
        isMyDirectoryABranch = [CvsTag isDirectoryABranch:aDirectory];
        someCvsEntries = [NSMutableArray arrayWithCapacity:lineCount];
        for( lineIndex = 0; lineIndex < lineCount; lineIndex++ ) {
            aLine = [lines objectAtIndex:lineIndex];
            cvsEntryInfos = [aLine componentsSeparatedByString:@"/"];
            
            // Here we are ignoring the entries that only have "D" on a single
            // line. This line denotes a directory without any sub-directories.
            if([cvsEntryInfos count] >= 6){
                aStickyDateOrTag = [cvsEntryInfos objectAtIndex:5];
                aFilename = [cvsEntryInfos objectAtIndex:1]; // NAME
                
                aCvsEntry = [[CvsEntry alloc] initWithFilename:aFilename
                                                   inDirectory:aDirectory];
                if ( aCvsEntry != nil ) {
                    if ( [[cvsEntryInfos objectAtIndex:0] isEqual:@"D"] ) {
                        // This entry is a directory.
                        [aCvsEntry setIsADirectory:[NSNumber numberWithBool:YES]];
                        aCvsEntryDirectory = [aCvsEntry path];
                        aTag = [CvsTag getStringTagForDirectory:aCvsEntryDirectory];
                        [aCvsEntry setStickyTag:aTag];
                        aDate = [CvsTag getDateTagForDirectory:aCvsEntryDirectory];
                        [aCvsEntry setStickyDate:aDate];                                        
                    } else {
                        // This entry is NOT a directory.
                        [aCvsEntry setIsADirectory:[NSNumber numberWithBool:NO]];
                        aRevision = [cvsEntryInfos objectAtIndex:2];
                        if ( isNotEmpty(aRevision) ) {
                            // Note: if the revision number has a minus in front of
                            // it then it means that this file has been marked for
                            // removal.                            
                            firstCharacter = [aRevision substringToIndex:1];
                            if ( [firstCharacter isEqualToString:@"-"] == YES ) {
                                [aCvsEntry setMarkedForRemovalAsANumber:
                                    [NSNumber numberWithBool:YES]];
                                aRevision = [aRevision substringFromIndex:1];
                            } else {
                                [aCvsEntry setMarkedForRemovalAsANumber:
                                    [NSNumber numberWithBool:NO]];
                            }
                            // Note: if the revision number is zero
                            // it then it means that this file has been marked for
                            // addition.                            
                            if ( [aRevision intValue] == 0 ) {
                                [aCvsEntry setMarkedForAdditionAsANumber:
                                    [NSNumber numberWithBool:YES]];
                            } else {
                                [aCvsEntry setMarkedForAdditionAsANumber:
                                    [NSNumber numberWithBool:NO]];
                            }
                            //
                            [aCvsEntry setRevisionInWorkArea:aRevision];
                        }
                        [aCvsEntry setDateOfLastCheckout:[cvsEntryInfos objectAtIndex:3]];
                        [aCvsEntry setStickyOptions:[cvsEntryInfos objectAtIndex:4]];
                        aStickyDateOrTag = [cvsEntryInfos objectAtIndex:5];
                        if ( isNotEmpty(aStickyDateOrTag) ) {
                            aTag = [self getStringTagFromString:aStickyDateOrTag 
                                                 branchTagEnabled:isMyDirectoryABranch];
                            [aCvsEntry setStickyTag:aTag];
                            aDate = [CvsTag getDateTagFromString:aStickyDateOrTag];
                            [aCvsEntry setStickyDate:aDate];                    
                        }                    
                    }
                    [someCvsEntries addObject:aCvsEntry];
                }
            }
        }
    }
    return someCvsEntries;
}

+ (NSString *) mergeContentsOfEntriesLog:(NSString *)aCvsEntriesLogString intoEntries:(NSString *)aCvsEntriesString forDirectory:(NSString *)aDirectory
    /*" This method returns the merged contents of the two strings given as
        arguments (i.e. aCvsEntriesLogString and aCvsEntriesString). The
        format of a line in aCvsEntriesLogString is a single character command 
        followed by a space followed by a line in the format specified for a 
        line in aCvsEntriesString. The single character command is "A" to 
        indicate that the line should be added to aCvsEntriesString. An "R" to 
        indicate that the the line should be removed from aCvsEntriesString.
        The argument aDirectory is passed to this method so it can be used in
        reporting errors.
    "*/
{
    NSMutableString *aNewCvsEntriesString = nil;
    NSArray         *lines = nil;
    NSString        *aLine = nil;
    NSString        *relevantPartOfLine = nil;
    NSString        *aMsg = nil;
    unsigned int    aLength = 0;
    unsigned int    lineIndex = 0;
    unsigned int    lineCount = 0;
    NSRange         aRange;

    // If the Entries.Log contents is nil or empty just return the Entries 
    // contents
    if ( isNilOrEmpty(aCvsEntriesLogString) ) return aCvsEntriesString;
    
    // If the Entries contents is nil or empty just return the Entries.Log
    // contents
    if ( isNilOrEmpty(aCvsEntriesString) ) {
        // We start the parsing of the Entries.Log content here.

        lines = [aCvsEntriesLogString lines];
        lineCount = [lines count];
        SEN_ASSERT_CONDITION((lineCount > 0));

        aLength = [aCvsEntriesLogString length];
        aNewCvsEntriesString = [NSMutableString stringWithCapacity:aLength];
        
        for( lineIndex = 0; lineIndex < lineCount; lineIndex++ ) {
            aLine = [lines objectAtIndex:lineIndex];
            // Just in case a line is empty skip it.
            if ( isNilOrEmpty(aLine) ) continue;
            // Ignore all lines with less than 3 characters. Must be corrupted
            // or some new feature of CVS.
            if ( [aLine length] < 3 ) {
                // First write out errors to console.
                aMsg = [NSString stringWithFormat:
                    @"This line \"%@\" had less than 3 characters. Must be corrupted or some new feature of CVS. CVL is ignoring it. Occurred in the Entries.Log file in the directory \"%@\". The Entries.Log was:\n\n%@\n",
                    aLine, aDirectory, aCvsEntriesLogString];
                [[CVLConsoleController sharedConsoleController] outputError:aMsg];
                continue;
            }            
            // If the line begins with an "A" and a space 
            // then use the rest of it.
            if ( [aLine hasPrefix:@"A "] ) {
                // Add line to new entries string.
                relevantPartOfLine = [aLine substringFromIndex:2];
                [aNewCvsEntriesString appendString:relevantPartOfLine];
                // Add a newline.
                [aNewCvsEntriesString appendString:@"\n"];
                continue;
            }
            // Ignore all other lines.
            aMsg = [NSString stringWithFormat:
                @"This line \"%@\" does not start with an A. Must be corrupted or some new feature of CVS. CVL is ignoring it. Occurred in the Entries.Log file in the directory %@. In this case the Entries file DOES NOT exists. The Entries.Log was:\n\n%@\n",
                aLine, aDirectory, aCvsEntriesLogString];
            [[CVLConsoleController sharedConsoleController] outputError:aMsg];            
        }
        return aNewCvsEntriesString;
    }
    
    // If we get this far then we have both Entries and Entries.Log content.
    lines = [aCvsEntriesLogString lines];
    lineCount = [lines count];
    SEN_ASSERT_CONDITION((lineCount > 0));
    
    // Put the Entries content in a new mutable string.
    aNewCvsEntriesString = [NSMutableString stringWithString:aCvsEntriesString];

	// Just in case the old entries file does not end with a newline; we are
	// adding one here.
	[aNewCvsEntriesString appendString:@"\n"];

    // We now start parsing the Entries.Log content.
    for( lineIndex = 0; lineIndex < lineCount; lineIndex++ ) {
        aLine = [lines objectAtIndex:lineIndex];
        // Just in case a line is empty skip it.
        if ( isNilOrEmpty(aLine) ) continue;
        // Ignore all lines with less than 3 characters. Must be corrupted
        // or some new feature of CVS.
        if ( [aLine length] < 3 ) {
            // First write out errors to console.
            aMsg = [NSString stringWithFormat:
                @"This line \"%@\" had less than 3 characters. Must be corrupted or some new feature of CVS. CVL is ignoring it. Occurred in the Entries.Log file in the directory \"%@\". The Entries.Log was:\n\n%@\n",
                aLine, aDirectory, aCvsEntriesLogString];
            [[CVLConsoleController sharedConsoleController] outputError:aMsg];
            continue;
        }
        
        // If the line begins with an "A" and a space 
        // then use the rest of it.
        if ( [aLine hasPrefix:@"A "] ) {
            // Add the line to the new entries string.
            relevantPartOfLine = [aLine substringFromIndex:2];
            [aNewCvsEntriesString appendString:relevantPartOfLine];
            // Add a newline.
            [aNewCvsEntriesString appendString:@"\n"];
            
        // If the line begins with an "R" and a space 
        // then use the rest of it.
        } else if ( [aLine hasPrefix:@"R "] ) {
            // Remove the line from the new entries string.
            relevantPartOfLine = [aLine substringFromIndex:2];
            aRange = [aNewCvsEntriesString rangeOfString:relevantPartOfLine];
            if ( aRange.location != NSNotFound ) {
                [aNewCvsEntriesString deleteCharactersInRange:aRange];
            }

        // Ignore all other lines.
        } else {
            aMsg = [NSString stringWithFormat:
            @"This line \"%@\" does not start with an A or an R. Must be corrupted or some new feature of CVS. CVL is ignoring it. Occurred in the Entries.Log file in the directory \"%@\". In this case the Entries file DOES exists. The Entries.Log was:\n\n%@\n",
                aLine, aDirectory, aCvsEntriesLogString];
            [[CVLConsoleController sharedConsoleController] outputError:aMsg];
        }      
    }
    //NSLog(@"aNewCvsEntriesString = %@",aNewCvsEntriesString);

    return aNewCvsEntriesString;
}

+ (BOOL) deleteEntriesLogForDirectory:(NSString *)aDirectory
    /*" This method returns YES if it was able to delete the CVS/Entries.Log 
        file. The directory path is given in the argument aDirectory. NO is 
        returned if this method was not successful. An exception is raised if 
        aDirectory is nil, empty or does not exists.
    "*/
{
    NSString        *cvsDirectory = nil;
    NSString        *cvsDirectoryStandardized = nil;
    NSString        *cvsEntriesLogPath = nil;
    NSFileManager   *fileManager = nil;
    BOOL            results = NO;
        
    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    fileManager = [NSFileManager defaultManager];
    SEN_ASSERT_CONDITION(([fileManager senDirectoryExistsAtPath:aDirectory] == YES));
    
    cvsDirectory = [aDirectory stringByAppendingPathComponent:@"CVS"];    
    cvsDirectoryStandardized = [cvsDirectory stringByStandardizingPath];    
    if ( [fileManager senDirectoryExistsAtPath:cvsDirectoryStandardized] == YES ) {
        cvsEntriesLogPath = [self cvsEntriesLogPathForDirectory:aDirectory];
        if ([fileManager senFileExistsAtPath:cvsEntriesLogPath] == YES) {
            if ([fileManager isDeletableFileAtPath:cvsEntriesLogPath] == YES) {
                // Delete Entries.Log file here.
                results = [fileManager removeFileAtPath:cvsEntriesLogPath handler:nil];
            }
        }
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

+ (NSString *) getStringTagFromString:(NSString *)aString branchTagEnabled:(BOOL)branchTagEnabledState
    /*" This method returns a string tag from the string given in the argument
        aString. If aString is nil or empty then nil is returned.

        The string in aString is of the form of a code letter in the first 
        column and a string tag or date tag starting in the second column and 
        running until the end of the line. The code letters are a single letter
        indicating the type of tag: T for branch tag or for non-branch tag and 
        D for date. To distinguish between branch tags and non-branch tags we 
        check to see if the branchTagEnabledState is enabled. If it is then we
        know that a T code is in fact a branch tag; otherwise we assume that the 
        T code is a non-branch tag. If this is a branch tag then the string 
        "branch: " is inserted before the tag string and then the whole string
        is enclosed in parenthesis.
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
                if ( branchTagEnabledState == YES) {
                    aTag = [NSString stringWithFormat:@"(branch: %@)", aTagOrDate];
                } else {
                    aTag = aTagOrDate;
                }
                break;
            case 'D': // date tag
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

+ (void) removeCvsEntryWithFilename:(NSString *)aFilename fromDirectory:(NSString *)aDirectory
    /*" This method removes the entry in the CVS/Entries file for the file 
		specified by aFilename in aDirectory.

		See also #{-removeCvsEntry}
    "*/
{
	CvsEntry *aCvsEntry = nil;
	
	aCvsEntry = [[CvsEntry alloc] initWithFilename:aFilename 
									   inDirectory:aDirectory];
	[aCvsEntry removeCvsEntry];
}

- (id) init
    /*" This method should not be called. It will raise an exception named
        SenNotDesignatedInitializerException if it is. The designated 
        initializer for this class is #{-initWithFilename:inDirectory:}.
    "*/
{
    SEN_NOT_DESIGNATED_INITIALIZER(@"-initWithFilename:inDirectory:");
    
    return nil;
}

+ (BOOL) doesDirectoryContainAnyCVSFiles:(NSString *)aDirectory
    /*" This method returns YES if a directory whose path is given in the 
        argument aDirectory contains any files under CVS control. Otherwise NO 
        is returned. Note that directories are not under CVS control so a 
        directory may be labeled empty even though it has sub-directories.

        See also #{-checkTheTagsForViewer:} in class CvsTag.
    "*/
{
    NSArray	*cvsEntries = nil;
    NSEnumerator *anEnumerator = nil;
    CvsEntry *aCvsEntry = nil;

    if ( isNilOrEmpty(aDirectory) ) return NO;
    
    cvsEntries = [self getCvsEntriesForDirectory:aDirectory];
    if ( isNotEmpty(cvsEntries) ) {
        anEnumerator = [cvsEntries objectEnumerator];
        while ( (aCvsEntry = [anEnumerator nextObject]) ) {
            if ( [[aCvsEntry isADirectory] boolValue] == NO ) {
                return YES;
            }
        }
    }
    return NO;
}

- (id) initWithFilename:(NSString *)aFilename inDirectory:(NSString *)aDirectory
    /*" This method initializes an instance of the CvsEntry class with the name
        of a file or directory given in aFilename and the location of this file
        or directory in the directory given in aDirectory. If  aFilename
        is nil or empty then an exception by the name of
        SenAssertConditionException is raised. If aDirectory is nil, empty, does
        not exists or is not a directory then an exception by the name of 
        SenAssertConditionException is raised.
    
        This is the designated initializer for this class. 
    "*/
{
    NSFileManager   *fileManager = nil;
    NSString        *aPath = nil;
    NSString        *aPathStandardized = nil;
    
    // Lets check to make sure aDirectory is not empty and exists and is a directory.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    fileManager = [NSFileManager defaultManager];
    SEN_ASSERT_CONDITION(([fileManager senDirectoryExistsAtPath:aDirectory] == YES));
    
    // Lets check to make sure aPath is not empty.
    SEN_ASSERT_NOT_EMPTY(aFilename);
    
    // Lets check to see if aPath exists.
    aPath = [aDirectory stringByAppendingPathComponent:aFilename];
    aPathStandardized = [aPath stringByStandardizingPath];
    if( [fileManager senFileExistsAtPath:aPathStandardized] == NO ) {
        // This would be a deleted file that has not been committed.
        [self setDoesNotExistsInWorkArea:[NSNumber numberWithBool:YES]];
    } else {
        [self setDoesNotExistsInWorkArea:[NSNumber numberWithBool:NO]];
    }
    
    if ( (self = [super init]) ) {
        ASSIGN(filename, aFilename);
        ASSIGN(inDirectory, aDirectory);
        ASSIGN(isADirectory, [NSNumber numberWithBool:NO]);
    }
    return self;
}

- (void) dealloc
{    
    RELEASE(doesNotExistsInWorkArea);
    RELEASE(markedForRemovalAsANumber);
    RELEASE(isADirectory);
    RELEASE(filename);
    RELEASE(inDirectory);
    RELEASE(dateOfLastCheckout);
    RELEASE(revisionInWorkArea);
    RELEASE(stickyOptions);
    RELEASE(stickyTag);
    RELEASE(stickyDate);
    
    [super dealloc];
}


- (NSNumber *) doesNotExistsInWorkArea
    /*" This is the get method for the doesNotExistsInWorkArea state expressed 
        as a NSNumber (1 is YES and 0 is NO). 

        See also #{-setDoesNotExistsInWorkArea:}
    "*/
{
	return doesNotExistsInWorkArea;
}

- (void) setDoesNotExistsInWorkArea:(NSNumber *)newDoesNotExistsInWorkArea
    /*" This is the set method for the doesNotExistsInWorkArea state expressed 
        as a NSNumber (1 is YES and 0 is NO).

        See also #{-doesNotExistsInWorkArea}
    "*/
{
    ASSIGN(doesNotExistsInWorkArea, newDoesNotExistsInWorkArea);
}

- (NSNumber *) markedForRemovalAsANumber
    /*" This is the get method for the markedForRemovalAsANumber state expressed 
        as a NSNumber (1 is YES and 0 is NO). This variable means that the file
        in question has had the CVS remove command run on it. This is indicated
        in the CVS/entries file by having a minus sign preceeding the revision
        number. This file will need a CVS commit command run on it to actually
        change the repository and remove this entry from the CVS/entries file.
        Note: If this CVS Entry points to a directory then this instance 
        variable is not set (i.e. it is nil).

        See also #{-setMarkedForRemovalAsANumber:}
    "*/
{
	return markedForRemovalAsANumber;
}

- (void) setMarkedForRemovalAsANumber:(NSNumber *)newMarkedForRemovalAsANumber
    /*" This is the set method for the markedForRemovalAsANumber state expressed 
        as a NSNumber (1 is YES and 0 is NO).

        See also #{-markedForRemovalAsANumber}
    "*/
{
    ASSIGN(markedForRemovalAsANumber, newMarkedForRemovalAsANumber);
}

- (NSNumber *) markedForAdditionAsANumber
    /*" This is the get method for the markedForAdditionAsANumber state expressed 
        as a NSNumber (1 is YES and 0 is NO). This variable means that the file
        in question has had the CVS add command run on it. This is indicated
        in the CVS/entries file by having a zero as the revision
        number. This file will need a CVS commit command run on it to actually
        change the repository and remove this entry from the CVS/entries file.
        Note: If this CVS Entry points to a directory then this instance 
        variable is not set (i.e. it is nil).

        See also #{-setMarkedForAdditionAsANumber:}
    "*/
{
	return markedForAdditionAsANumber;
}

- (void) setMarkedForAdditionAsANumber:(NSNumber *)newMarkedForAdditionAsANumber
    /*" This is the set method for the markedForAdditionAsANumber state expressed 
        as a NSNumber (1 is YES and 0 is NO).

        See also #{-markedForAdditionAsANumber}
    "*/
{
    ASSIGN(markedForAdditionAsANumber, newMarkedForAdditionAsANumber);
}

- (NSNumber *) isADirectory
    /*" This is the get method for the isADirectory state expressed as a 
        NSNumber (1 is on and 0 is off). 

        See also #{-setIsADirectory:}
    "*/
{
	return isADirectory;
}

- (void) setIsADirectory:(NSNumber *)newIsADirectory
    /*" This is the set method for the isADirectory state expressed as a 
        NSNumber (1 is on and 0 is off).
    
        See also #{-isADirectory}
    "*/
{
    ASSIGN(isADirectory, newIsADirectory);
}

- (NSString *) filename
    /*" This is the get method for the filename.

        See also #{-setFilename:}
    "*/
{
	return filename;
}

- (void) setFilename:(NSString *)newFilename
    /*" This is the set method for the filename.

        See also #{-filename}
    "*/
{
    ASSIGN(filename, newFilename);
}

- (NSString *) inDirectory
    /*" This is the get method for the inDirectory. This is the directory that
        the filename is contained in.

        See also #{-setInDirectory:}
    "*/
{
	return inDirectory;
}

- (void) setInDirectory:(NSString *)newInDirectory
    /*" This is the set method for the inDirectory.

        See also #{-inDirectory}
    "*/
{
    NSString *newInDirectoryStandardized = nil;
    
    newInDirectoryStandardized = [newInDirectory stringByStandardizingPath];
    ASSIGN(inDirectory, newInDirectoryStandardized);
}

- (NSCalendarDate *) dateOfLastCheckout
    /*" This is the get method for the dateOfLastCheckout. 

        See also #{-setDateOfLastCheckout:}
    "*/
{
	return dateOfLastCheckout;
}

- (void) setDateOfLastCheckout:(NSCalendarDate *)newDateOfLastCheckout
    /*" This is the set method for the dateOfLastCheckout.

        See also #{-dateOfLastCheckout}
    "*/
{
    ASSIGN(dateOfLastCheckout, newDateOfLastCheckout);
}

- (NSString *) revisionInWorkArea
    /*" This is the get method for the revisionInWorkArea. 

        See also #{-setRevisionInWorkArea:}
    "*/
{
	return revisionInWorkArea;
}

- (void) setRevisionInWorkArea:(NSString *)newRevisionInWorkArea
    /*" This is the set method for the revisionInWorkArea.

        See also #{-revisionInWorkArea}
    "*/
{
    ASSIGN(revisionInWorkArea, newRevisionInWorkArea);
}

- (NSString *) stickyOptions
    /*" This is the get method for the stickyOptions. 

        See also #{-stickyOptions:}
    "*/
{
	return stickyOptions;
}

- (void) setStickyOptions:(NSString *)newStickyOptions
    /*" This is the set method for the stickyOptions.

        See also #{-stickyOptions}
    "*/
{
    ASSIGN(stickyOptions, newStickyOptions);
}

- (NSString *) stickyTag
    /*" This is the get method for the stickyTag. 

        See also #{-stickyTag:}
    "*/
{
	return stickyTag;
}

- (void) setStickyTag:(NSString *)newStickyTag
    /*" This is the set method for the stickyTag.

        See also #{-stickyTag}
    "*/
{
    ASSIGN(stickyTag, newStickyTag);
}

- (NSCalendarDate *) stickyDate
    /*" This is the get method for the stickyDate. 

        See also #{-setStickyDate:}
    "*/
{
	return stickyDate;
}

- (void) setStickyDate:(NSCalendarDate *)newStickyDate
    /*" This is the set method for the stickyDate.

        See also #{-stickyDate}
    "*/
{
    ASSIGN(stickyDate, newStickyDate);
}



- (NSString *) path
    /*" This method returns the path to file or directory that this entry points
        to (i.e. filename appended to inDirectory).

        See also #{-filename and -inDirectory}
    "*/
{
    NSString *filePath = nil;
    NSString *filePathStandardized = nil;
    
    filePath = [[self inDirectory] stringByAppendingPathComponent:[self filename]];
    filePathStandardized = [filePath stringByStandardizingPath];
    
    return filePathStandardized;
}

- (NSString *) description
    /*" This method overrides supers implementation. Here we return the 
        is a Directory, filename, in directory, date of last checkout, revision
        in the workarea, the sticky tag and the sticky date.
    "*/
{
    return [NSString stringWithFormat:
        @"isADirectory = %@, filename = %@, inDirectory = %@, dateOfLastCheckout = %@, revisionInWorkArea = %@, stickyOptions = %@, stickyTag = %@, stickyDate = %@", 
        isADirectory, filename, inDirectory, dateOfLastCheckout, 
        revisionInWorkArea, stickyOptions, stickyTag, stickyDate];
}

- (void) deleteTheMarkedForRemovalFlag
    /*" This method will delete the marked for removal flag found in the 
        CVS/Entries file for this CVSEntry object. To be precise, the minus sign
        in front of the revsison tag in the CVS/Entries file for this entry will
        be remove.
    "*/
{
    NSMutableArray  *someCvsEntries = nil;
    NSString        *aDirectory = nil;
    NSString        *cvsEntriesString = nil;
    NSMutableString *aNewCvsEntriesString = nil;
    NSArray         *lines = nil;
    NSString        *aLine = nil;
    NSArray         *cvsEntryInfos = nil;
    NSMutableArray  *aNewCvsEntryInfos = nil;
    NSString        *aFilename = nil;
    NSString        *myFilename = nil;
    NSString        *aNewRevision = nil;
    NSString        *aRevision = nil;
    NSString        *firstCharacter = nil;
    unsigned int    lineCount = 0;
    unsigned int    lineIndex = 0;
    unsigned int    aCapacity = 0;
    BOOL            thereAreChanges = NO;
    BOOL            success = NO;
    
    aDirectory = [self inDirectory];
    // Lets check to make sure aDirectory is not empty.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    cvsEntriesString = [CvsEntry readCvsEntriesAndEntriesLogForDirectory:aDirectory];
    
    if( isNotEmpty(cvsEntriesString) ) {
        lines = [cvsEntriesString lines];
        lineCount = [lines count];

        SEN_ASSERT_CONDITION((lineCount > 0));
        
        aCapacity = [cvsEntriesString length];
        aNewCvsEntriesString = [NSMutableString stringWithCapacity:aCapacity];
        someCvsEntries = [NSMutableArray arrayWithCapacity:lineCount];
        for( lineIndex = 0; lineIndex < lineCount; lineIndex++ ) {
            aLine = [lines objectAtIndex:lineIndex];
            cvsEntryInfos = [aLine componentsSeparatedByString:@"/"];
            
            myFilename = [self filename];
            if([cvsEntryInfos count] >= 6){
                aFilename = [cvsEntryInfos objectAtIndex:1]; // NAME
                if ( [aFilename isEqualToString:myFilename] ) {
                    //Change this line.
                    if ( [[cvsEntryInfos objectAtIndex:0] isEqual:@"D"] ) {
                        // This entry is a directory; nothing to do.
                        thereAreChanges = NO;
                    } else {
                        // This entry is NOT a directory.
                        aRevision = [cvsEntryInfos objectAtIndex:2];
                        if ( isNotEmpty(aRevision) ) {
                            firstCharacter = [aRevision substringToIndex:1];
                            if ( [firstCharacter isEqualToString:@"-"] == YES ) {
                                thereAreChanges = YES;
                                // Get the revision without the minus sign.
                                aNewRevision = [aRevision substringFromIndex:1];
                                // Build a new array.
                                aNewCvsEntryInfos = [NSMutableArray 
                                                    arrayWithArray:cvsEntryInfos];
                                [aNewCvsEntryInfos replaceObjectAtIndex:2 
                                                             withObject:aNewRevision];
                                // Build a new line;
                                aLine = [aNewCvsEntryInfos
                                                componentsJoinedByString:@"/"];
                            }             
                        }                    
                    }
                    if ( thereAreChanges == NO ) {
                        // No need to write the file back.
                        // No need to continue looping since we have found the
                        // entry that matches self.
                        break;
                    }
                }
            }
            // Append this line to a new string.
            [aNewCvsEntriesString appendFormat:@"%@\n", aLine];
        }
        if ( thereAreChanges == YES ) {
            // Need to write the file back.
            success = [CvsEntry writeCvsEntriesForDirectory:aDirectory 
                                                 withString:aNewCvsEntriesString];
            if( success == NO ) {
                // Could not write the CVS/Entries file.
                NSString *aTitle = nil;
                NSString *aMessage = nil;
                
                aTitle = [NSString stringWithFormat:@"CVL Warning"];
                aMessage = [NSString stringWithFormat:
                    @"Could not write a new CVS Entries file at \"%@\".",
                    [self cvsEntriesPath]];
                (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
            }            
        }      
    }
}

- (NSString *) cvsEntriesPath
    /*" This method returns the path to the CVS/Entries file that was used to
        create this CvsEntry object.
    "*/
{
    NSString        *aDirectory = nil;
    NSString        *cvsEntriesPath = nil;

    aDirectory = [self inDirectory];
    cvsEntriesPath = [CvsEntry cvsEntriesPathForDirectory:aDirectory];
    
    return cvsEntriesPath;
}

- (BOOL) markedForRemoval
    /*" This is a cover method for the method -markedForRemovalAsANumber. This
        method interperts the return value of the method 
        -markedForRemovalAsANumber and returns either YES or NO based whether 
        the returned value is non-zero or not. If this return value is nil then
        this method returns NO.

        See also #{-markedForRemovalAsANumber} in the class CvsEntry.
    "*/
{
    NSNumber *aBooleanNumber = nil;
    BOOL thisEntryHasBeenMarked = NO;
    
    aBooleanNumber = [self markedForRemovalAsANumber];
    if ( aBooleanNumber != nil ) {
        thisEntryHasBeenMarked = [aBooleanNumber boolValue];
    }
    
    return thisEntryHasBeenMarked;
}

- (BOOL) markedForAddition
    /*" This is a cover method for the method -markedForAdditionAsANumber. This
        method interperts the return value of the method 
        -markedForAdditionAsANumber and returns either YES or NO based whether 
        the returned value is non-zero or not. If this return value is nil then
        this method returns NO.

        See also #{-markedForAdditionAsANumber} in the class CvsEntry.
    "*/
{
    NSNumber *aBooleanNumber = nil;
    BOOL thisEntryHasBeenMarked = NO;
    
    aBooleanNumber = [self markedForAdditionAsANumber];
    if ( aBooleanNumber != nil ) {
        thisEntryHasBeenMarked = [aBooleanNumber boolValue];
    }
    
    return thisEntryHasBeenMarked;
}

- (void) removeCvsEntry
    /*" This method removes the entry in the CVS/Entries file for the file 
		specified by self.

		See also #{-removeCvsEntryWithFilename:fromDirectory:}
    "*/
{
    NSMutableArray  *someCvsEntries = nil;
    NSString        *aDirectory = nil;
    NSString        *cvsEntriesString = nil;
    NSMutableString *aNewCvsEntriesString = nil;
    NSArray         *lines = nil;
    NSString        *aLine = nil;
    NSArray         *cvsEntryInfos = nil;
    NSString        *aFilename = nil;
    NSString        *myFilename = nil;
    unsigned int    lineCount = 0;
    unsigned int    lineIndex = 0;
    unsigned int    aCapacity = 0;
    BOOL            thereAreChanges = NO;
    BOOL            success = NO;
    
    aDirectory = [self inDirectory];
	myFilename = [self filename];

    // Lets check to make sure aDirectory is not empty.
    SEN_ASSERT_NOT_EMPTY(aDirectory);
    
    cvsEntriesString = [CvsEntry readCvsEntriesAndEntriesLogForDirectory:aDirectory];
    
    if( isNotEmpty(cvsEntriesString) ) {
        lines = [cvsEntriesString lines];
        lineCount = [lines count];
		
        SEN_ASSERT_CONDITION((lineCount > 0));
        
        aCapacity = [cvsEntriesString length];
        aNewCvsEntriesString = [NSMutableString stringWithCapacity:aCapacity];
        someCvsEntries = [NSMutableArray arrayWithCapacity:lineCount];

        for( lineIndex = 0; lineIndex < lineCount; lineIndex++ ) {
            aLine = [lines objectAtIndex:lineIndex];
            cvsEntryInfos = [aLine componentsSeparatedByString:@"/"];
			if( [cvsEntryInfos count] >= 2 ){
                aFilename = [cvsEntryInfos objectAtIndex:1]; // NAME
                if ( [aFilename isEqualToString:myFilename] ) {
                    // Do not write out this line.
					thereAreChanges = YES;
					continue;
                }
            }
            // Append this line to a new string.
            [aNewCvsEntriesString appendFormat:@"%@\n", aLine];
        }
        if ( thereAreChanges == YES ) {
            // Need to write the file back.
            success = [CvsEntry writeCvsEntriesForDirectory:aDirectory 
                                                 withString:aNewCvsEntriesString];
            if( success == NO ) {
                // Could not write the CVS/Entries file.
                NSString *aTitle = nil;
                NSString *aMessage = nil;
                
                aTitle = [NSString stringWithFormat:@"CVL Warning"];
                aMessage = [NSString stringWithFormat:
                    @"Could not write a new CVS Entries file at \"%@\".",
                    [self cvsEntriesPath]];
                (void)NSRunAlertPanel(aTitle, aMessage, nil, nil, nil);    
            }            
        }      
    }
}

@end
