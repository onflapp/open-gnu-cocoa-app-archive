/*$Id: SenPathUtilities.m,v 1.9 2005/02/23 14:43:54 william Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenPathUtilities.h"
#import "NSFileManager_SenAdditions.h"

#if !defined(GNUSTEP) && !defined(RHAPSODY) && defined(AVAILABLE_MAC_OS_X_VERSION_10_2_AND_LATER)
NSString *FolderManagerException = @"FolderManagerException";
NSString *CFURLException = @"CFURLException";


// see Folders.h for parameter constants
// /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/Headers/Folders.h

// value for vRefNum
// enum {
//     kOnSystemDisk                 = -32768L, /* previously was 0x8000 but that is an unsigned value whereas vRefNum is signed*/
//     kOnAppropriateDisk            = -32767, /* Generally, the same as kOnSystemDisk, but it's clearer that this isn't always the 'boot' disk.*/
     /* Folder Domains - Carbon only.  The constants above can continue to be used, but the folder/volume returned will*/
     /* be from one of the domains below.*/
//     kSystemDomain                 = -32766, /* Read-only system hierarchy.*/
//     kLocalDomain                  = -32765, /* All users of a single machine have access to these resources.*/
//     kNetworkDomain                = -32764, /* All users configured to use a common network server has access to these resources.*/
//     kUserDomain                   = -32763, /* Read/write. Resources that are private to the user.*/
//     kClassicDomain                = -32762 /* Domain referring to the currently configured Classic System Folder*/
// };

NSString *SenSearchPathForDirectoriesInDomains(OSType folderType, short vRefNum)
{
    OSErr err;
    FSRef folderRef;
    //UInt8 localPath[4096] = "";
    CFURLRef anURL;
    CFStringRef aPath;

    err = FSFindFolder (vRefNum, folderType, kDontCreateFolder, &folderRef);
    if (err != 0) {
        [NSException raise: FolderManagerException format: @"Folder Manager error (%d)", err];
    }
    anURL = CFURLCreateFromFSRef (kCFAllocatorSystemDefault, &folderRef);
    //err = FSRefMakePath (&folderRef, localPath, 4096);
    if (anURL == NULL) {
        [NSException raise: CFURLException format: @"CFURLCreateFromFSRef"];
    }
    aPath = CFURLCopyFileSystemPath (anURL, kCFURLPOSIXPathStyle);
    CFRelease (anURL);
    return [(NSString *)aPath autorelease];
}

#endif

@implementation NSString (SenPathUtilities)
+ (NSString *) temporaryPathWithName:(NSString *) aName forApplicationIdentifier:(NSString *) anApplicationIdentifier
{
	NSArray *temporaryPath = [NSArray arrayWithObjects:
		NSTemporaryDirectory(),
		anApplicationIdentifier,
		aName,
		nil];

	return [NSString pathWithComponents:temporaryPath];
}


+ (NSString*) uniqueTemporaryPathWithName:(NSString *) aName forApplicationIdentifier:(NSString *) anApplicationIdentifier
{
	return [[self temporaryPathWithName:aName forApplicationIdentifier:anApplicationIdentifier] stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
}

+ (NSString*) uniqueFilenameWithPrefix:(NSString *)aName inDirectory:(NSString *)aDirectory
	/*" This method will return a filename of the form aName-N that is not in 
		use in the directory given in the argument aDirectory. The filename is
		made up of the prefix given by the argument aName and a number seperated 
		by a dash. This method first tries just the prefix itself without a 
		number. If that is in use then it tries the prefix with the number 1, 
		then the number 2 and so on until a filename is found that is not being
		used in this directory. As an example if aName is "tmp" then the 
		filename returned would be one of the names "tmp, tmp-1, tmp-2, etc".
		This method will stop after trying the first 10,000 numbers. In this 
		case it will return nil.

		If aName has an extension then the attempts at naming are positioned 
		before the extension. For example if aName is "tmp.tiff" then the 
		filename returned would be one of the names "tmp.tiff, tmp-1.tiff, 
		tmp-2.tiff, etc".
	"*/
{	
	NSString *aFilename = nil;
	NSString *anExtension = nil;
	NSString *aFilenameWithoutExt = nil;
	NSString *aFilenamePlusExt = nil;
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	NSArray *theDirectoryContents = nil;
	unsigned int numberOfTries = 0;
	
	aFilenamePlusExt = aName;
	anExtension = [aName pathExtension];
	aFilenameWithoutExt = [aName stringByDeletingPathExtension];	
	theDirectoryContents = [fileManager directoryContentsAtPath:aDirectory];
	
	// Cycle thru names such as tmp, tmp-1, tmp-2
	// etc until we find one that does not exist. Return that one.
	// But give up after 10000 tries.
	while ( ([theDirectoryContents containsObject:aFilenamePlusExt] == YES) && 
			(numberOfTries < 10000) ) {
		numberOfTries++;
		aFilename = [aFilenameWithoutExt stringByAppendingFormat:@"-%d", 
						numberOfTries];
		if ( isNotEmpty(anExtension) ) {
			aFilenamePlusExt = [aFilename stringByAppendingPathExtension:anExtension];
		} else {
			aFilenamePlusExt = aFilename;
		}
	}
	if ( numberOfTries >= 10000 ) {
        aFilenamePlusExt = nil;
	} else {
		aFilenamePlusExt = [[aFilenamePlusExt retain] autorelease];
	}
    return aFilenamePlusExt;
}

@end

