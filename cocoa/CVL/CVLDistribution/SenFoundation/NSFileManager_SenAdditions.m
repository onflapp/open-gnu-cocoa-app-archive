//
//  NSFileManager_SenAdditions.m
//  CVL
//
//  Created by William Swats on Thu Oct 23 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import "NSFileManager_SenAdditions.h"

#import <SenFoundation/SenFoundation.h>


@implementation NSFileManager (SenAdditions)


- (BOOL) senFileExistsAtPath:(NSString *)aPath isDirectory:(BOOL *)isADirectory
    /*" This checks to see if the file path in the argument aPath points to an 
        existing file or directory. If it does then this method returns YES; 
        otherwise NO is returned (i.e. aPath is nil, empty or does not exists). 
        This method follows links.
    
        We are using this method in place of #{-fileExistsAtPath:isDirectory:} in 
        NSFileManager since that method does not follow links.
    "*/
{
    NSFileManager   *fileManager = nil;
    NSDictionary    *fileAttributes = nil;
    NSString        *aFileType = nil;
    BOOL            theFileExists = NO;
    
    SEN_ASSERT_CONDITION((isADirectory != NULL));
    
    if ( isNotEmpty(aPath) ) {
        fileManager = [NSFileManager defaultManager];
        fileAttributes = [fileManager fileAttributesAtPath:aPath 
                                                    traverseLink:YES];
        if ( fileAttributes != nil ) {
            theFileExists = YES;
            aFileType = [fileAttributes objectForKey:NSFileType];
            if ( (aFileType != nil) && (aFileType == NSFileTypeDirectory) ) {
                *isADirectory = YES;
            } else {
                *isADirectory = NO;
            }
        }        
    }
    return theFileExists;
}

- (BOOL) senDirectoryExistsAtPath:(NSString *)aPath
    /*" This checks to see if the file path in the argument aPath points to an 
        existing directory. If it does then this method returns YES; otherwise NO is
        returned (i.e. aPath is nil, empty, does not exists or is not a directory). 
        This method follows links.
            
        See also #{-senFileExistsAtPath:isDirectory:} for more information.
    "*/
{
    BOOL            theFileExists = NO;
    BOOL            isAdirectory = NO;

    if ( isNotEmpty(aPath) ) {
        theFileExists = [self senFileExistsAtPath:aPath
                                      isDirectory:&isAdirectory];
        if ( theFileExists && isAdirectory ) {
            return YES;
        }
    }
    return NO;
}


- (BOOL) senFileExistsAtPath:(NSString *)aPath
    /*" This checks to see if the file path in the argument aPath points to an 
        existing file or directory. If it does then this method returns YES; 
        otherwise NO is returned (i.e. aPath is nil, empty or does not exists).
        This method follows links.
    
        We are using this method in place of #{-fileExistsAtPath:} in 
        NSFileManager since that method does not follow links even though the
        documentation says it does. This was the case with Xcode on Jaguar says
        William Swats as of 22-Oct-2003.
    "*/
{
    NSFileManager   *fileManager = nil;
    NSDictionary    *fileAttributes = nil;
    
    if ( isNotEmpty(aPath) ) {
        fileManager = [NSFileManager defaultManager];
        fileAttributes = [fileManager fileAttributesAtPath:aPath 
                                                    traverseLink:YES];
        if ( fileAttributes != nil ) {
            return YES;
		}
    }
    return NO;
}

- (BOOL) senLinkExistsAtPath:(NSString *)aPath
    /*" This checks to see if the file path in the argument aPath is an 
		existing link. If it does then this method returns YES; 
		otherwise NO is returned (i.e. aPath is not a link, is nil, is empty or 
		does not exists). This method follows links. Note; this method returns 
		YES even if the link is broken (i.e. the link exists but points to a 
		nonexistent file or directory). 
    "*/
{
    NSFileManager   *fileManager = nil;
    NSDictionary    *fileAttributes = nil;
	NSString		*aFileType = nil;
    
    if ( isNotEmpty(aPath) ) {
        fileManager = [NSFileManager defaultManager];
        fileAttributes = [fileManager fileAttributesAtPath:aPath 
											  traverseLink:YES];
        if ( fileAttributes != nil ) {
			aFileType = [fileAttributes objectForKey:NSFileType];
			if ( (aFileType != nil) && 
				 ([aFileType isEqualToString:NSFileTypeSymbolicLink]) ) {
				return YES;
			}
        } else {
			// aPath could be a link to a nonexistent file; so let's check
			// for that case.
			fileAttributes = [fileManager fileAttributesAtPath:aPath 
												  traverseLink:NO];
			if ( fileAttributes != nil ) {
				aFileType = [fileAttributes objectForKey:NSFileType];
				if ( (aFileType != nil) && 
					 ([aFileType isEqualToString:NSFileTypeSymbolicLink]) ) {
					// Yes; this is a link to a nonexistent file; so return YES.
					return YES;
				}
			}
		}
    }
    return NO;
}

- (BOOL) senFileOrLinkExistsAtPath:(NSString *)aPath
	/*" This method returns YES if the file, link or directory at aPath exists. 
		Note; this method returns YES even if the link is broken (i.e. the link 
		exists but points to a nonexistent file or directory). Otherwise NO is 
		returned.
	"*/
{    
    if ( isNotEmpty(aPath) ) {
		if ( ([self senFileExistsAtPath:aPath] == YES) ||
			 ([self senLinkExistsAtPath:aPath] == YES) ) {
			return YES;
		}
    }
	return NO;
}

- (BOOL) createAllDirectoriesAtPath:(NSString *)path attributes:(NSDictionary *)attributes
	/*" This method creates all the directories in the path if they do not 
	already exists.
	"*/
{
	if (path)
	{
		NSArray* pathComponents= [path pathComponents];
		NSString* subPath= @"";
		int i= 0;
		int maxCount= [pathComponents count];
		BOOL allOk= YES;
		
		if (i < maxCount) // (120) in test !
		{ // to avoid first component problem under NT (120)
			subPath= [subPath stringByAppendingPathComponent: [pathComponents objectAtIndex: i++]];
		}
		while (allOk && (i < maxCount))
		{
			subPath= [subPath stringByAppendingPathComponent: [pathComponents objectAtIndex: i++]];
			if(![self senDirectoryExistsAtPath:subPath]){
#ifdef CVL_NFS_BUG
				if(![self createDirectoryAtPath: subPath attributes: attributes]) {
					NSString *aMsg = [NSString stringWithFormat:
						@"??? Unable to create directory at path %@ (attributes: %@) ???", 
						subPath, attributes];
					SEN_LOG(aMsg);        
				}
#else
				allOk= [self createDirectoryAtPath: subPath attributes: attributes];
#endif
			}
		}
		return allOk;
	}
	else
		return NO;
}

@end
