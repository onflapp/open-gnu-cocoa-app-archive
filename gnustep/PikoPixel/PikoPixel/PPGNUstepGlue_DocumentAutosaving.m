/*
    PPGNUstepGlue_DocumentAutosaving.m

    Copyright 2014-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

// 1) Workaround for GNUstep autosave-file-naming conflict: When creating the filename for
// for a new autosave file, GNUstep doesn't check whether the filename is already in use by
// another document, which can allow two documents to share the same autosave file location,
// losing the autosave contents of whichever is less-recently saved; Fixed by patching
// -[PPDocument autosavedContentsFileURL] to use a private local method,
// ppGSGlue_UniqueAutosaveURL, which checks whether a file already exists at the URL's
// location - if so, it tries different filenames until an unused name is found (or until a
// maximum number of renaming attempts is reached).
// 2) Autosave files now use the same naming & locating scheme as OS X:
// ppGSGlue_UniqueAutosaveURL method returns URLs with the same filename as the document (with
// an " (Autosaved)" suffix appended), and in the document's directory.

#ifdef GNUSTEP

#import <Cocoa/Cocoa.h>
#import "NSObject_PPUtilities.h"
#import "PPAppBootUtilities.h"
#import "PPDocument.h"
#import "PPUserFolderPaths.h"


#define kAutosaveFolderName             @"Autosave"
#define kAutosaveFilenameSuffix         @" (Autosaved)"

#define kMaxAutosaveFileRenameAttempts  100


static NSString *DefaultAutosaveDirectory(void);

static bool gIsAutosavingDocument = NO;


@interface PPDocument (PPGNUstepGlue_DocumentAutosavingUtilities)

- (NSURL *) ppGSGlue_UniqueAutosaveURL;

@end

@implementation NSObject (PPGNUstepGlue_DocumentAutosaving)

+ (void) ppGSGlue_DocumentAutosaving_InstallPatches
{
    macroSwizzleInstanceMethod(PPDocument,
                                autosaveDocumentWithDelegate:didAutosaveSelector:
                                    contextInfo:,
                                ppGSPatch_AutosaveDocumentWithDelegate:didAutosaveSelector:
                                    contextInfo:);

    macroSwizzleInstanceMethod(PPDocument, autosavedContentsFileURL,
                                ppGSPatch_AutosavedContentsFileURL);
}

+ (void) load
{
    macroPerformNSObjectSelectorAfterAppLoads(ppGSGlue_DocumentAutosaving_InstallPatches);
}

@end

@implementation PPDocument (PPGNUstepGlue_DocumentAutosaving)

- (void) ppGSPatch_AutosaveDocumentWithDelegate: (id) delegate
            didAutosaveSelector: (SEL) didAutosaveSelector
            contextInfo: (void *) context
{
    gIsAutosavingDocument = YES;

    [self ppGSPatch_AutosaveDocumentWithDelegate: delegate
            didAutosaveSelector: didAutosaveSelector
            contextInfo: context];

    gIsAutosavingDocument = NO;
}

- (NSURL *) ppGSPatch_AutosavedContentsFileURL
{
    NSURL *autosaveFileURL = [self ppGSPatch_AutosavedContentsFileURL];

    if (!autosaveFileURL && gIsAutosavingDocument)
    {
        autosaveFileURL = [self ppGSGlue_UniqueAutosaveURL];
    }

    return autosaveFileURL;
}

- (NSURL *) ppGSGlue_UniqueAutosaveURL
{
    NSFileManager *fileManager;
    NSString *documentPath, *autosaveRootFilename, *autosaveFileDirectory, *autosavingFileType,
                *autosaveFileExtension, *workingFilename, *autosavePath;
    int numRenameAttempts;

    fileManager = [NSFileManager defaultManager];

    documentPath = [self fileName];

    if ([documentPath length])
    {
        autosaveRootFilename = [[documentPath lastPathComponent] stringByDeletingPathExtension];

        autosaveFileDirectory = [documentPath stringByDeletingLastPathComponent];

        if (![autosaveFileDirectory length]
            || ![fileManager isWritableFileAtPath: autosaveFileDirectory])
        {
            autosaveFileDirectory = nil;
        }
    }
    else
    {
        autosaveRootFilename = nil;
        autosaveFileDirectory = nil;
    }

    if (!autosaveFileDirectory)
    {
        static NSString *defaultAutosaveDirectory = nil;

        if (!defaultAutosaveDirectory)
        {
            defaultAutosaveDirectory = [DefaultAutosaveDirectory() retain];

            if (!defaultAutosaveDirectory)
                goto ERROR;
        }

        autosaveFileDirectory = defaultAutosaveDirectory;
    }

    if (![autosaveRootFilename length])
    {
        autosaveRootFilename = [self displayName];

        if (![autosaveRootFilename length])
        {
            goto ERROR;
        }
    }

    autosaveRootFilename =
                    [autosaveRootFilename stringByAppendingString: kAutosaveFilenameSuffix];

    if (!autosaveRootFilename)
        goto ERROR;

    autosavingFileType = [self autosavingFileType];

    if (!autosavingFileType)
        goto ERROR;

    autosaveFileExtension = [self fileNameExtensionForType: autosavingFileType
                                    saveOperation: NSAutosaveOperation];

    if (![autosaveFileExtension length])
    {
        goto ERROR;
    }

    workingFilename =
                [autosaveRootFilename stringByAppendingPathExtension: autosaveFileExtension];

    if (!workingFilename)
        goto ERROR;

    autosavePath = [autosaveFileDirectory stringByAppendingPathComponent: workingFilename];
    numRenameAttempts = 0;

    while (autosavePath && [fileManager fileExistsAtPath: autosavePath])
    {
        autosavePath = nil;
        numRenameAttempts++;

        if (numRenameAttempts < kMaxAutosaveFileRenameAttempts)
        {
            workingFilename =
                [[NSString stringWithFormat: @"%@-%d", autosaveRootFilename, numRenameAttempts]
                            stringByAppendingPathExtension: autosaveFileExtension];

            if (!workingFilename)
                goto ERROR;

            autosavePath =
                    [autosaveFileDirectory stringByAppendingPathComponent: workingFilename];
        }
    }

    if (!autosavePath)
        goto ERROR;

    return [NSURL fileURLWithPath: autosavePath];

ERROR:
    return nil;
}

@end

static NSString *DefaultAutosaveDirectory(void)
{
    static bool didFailPreviously = NO;
    NSString *defaultAutosaveDirectory;
    NSFileManager *fileManager;
    BOOL isDirectory;

    if (didFailPreviously)
        goto ERROR;

    defaultAutosaveDirectory =
        [PPUserFolderPaths_ApplicationSupport() stringByAppendingPathComponent:
                                                                        kAutosaveFolderName];

    if (![defaultAutosaveDirectory length])
    {
        goto ERROR;
    }

    fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath: defaultAutosaveDirectory isDirectory: &isDirectory])
    {
        if (![fileManager createDirectoryAtPath: defaultAutosaveDirectory
                            withIntermediateDirectories: YES
                            attributes: nil
                            error: NULL])
        {
            goto ERROR;
        }
    }
    else if (!isDirectory)
    {
        goto ERROR;
    }

    return defaultAutosaveDirectory;

ERROR:
    didFailPreviously = YES;

    return nil;
}

#endif  // GNUSTEP

