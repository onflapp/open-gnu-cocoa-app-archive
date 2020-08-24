// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "BrowserController.h"
#import "ResultsRepository.h"
#import "RightSizeColumn.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <SenFoundation/SenFoundation.h>
#import <SenBrowserCell.h>
#import <SenBrowserTextCell.h>
#import <CvsRepository.h>
#import "NSArray.SenUtilities.h"

#define BROWSER_COLUMN_MIN_WIDTH	@"160"
#define BROWSER_MIN_COL						2

#define FRAME_NAME 	"Browser"
#define FILE_MENUITEM_TAG	(123654)

static int browserColumnWidth;
static int browserMinColumnCount;

static int browserColumnCount;
static int browserMinColumnWidth;

static int browserResizeBehavior;
static NSArray *statusImagesArray=nil;
static NSArray *watchedImagesArray=nil;
static NSString *browserColumnWidthKey=@"BrowserColumnWidth";
static NSString *browserMinColumnCountKey=@"BrowserMinColumnCount";
static NSString *browserColumnCountKey=@"BrowserColumnCount";
static NSString *browserMinColumnWidthKey=@"BrowserMinColumnWidth";
static NSString *browserResizeBehaviorKey=@"BrowserResizeBehavior";
static BOOL cvsEditorsAndWatchersEnabled = NO;
//-------------------------------------------------------------------------------------


#if !defined(MACOSX)
// On MOXS only, NSBrowser does not support key navigation; this Q&D fix corrects this,
// but not when navigating from a branch to its empty content.

@interface NSBrowser_CVLFix : NSBrowser
{
}
@end

@implementation NSBrowser_CVLFix

+ (void) load
{
    [NSBrowser_CVLFix poseAsClass:[NSBrowser class]];
}

- (void) doClick:(id)sender
// Private method in NSBrowser
{
    [super doClick:sender];
    [[self window] makeFirstResponder:self];
}

@end
#endif

// Patch for bug 1000208: Inspector out of sync after a Select All
// Browser does not receive the selectAll: message, it is taken by the matrix
// and browser does not notify that selection changed!
@interface CVLBrowserMatrix:NSMatrix
{
}
@end

@implementation CVLBrowserMatrix

- (void)selectAll:fp12
{
    [super selectAll:fp12];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CVLBrowserSelectionDidChangeNotification" object:[[self enclosingScrollView] superview]];
}

@end

@interface BrowserController (Private)

- (void) browserResultChanged: (NSNotification *)notification;
- (void) browserResized: (NSNotification *)notification;
- (void) startUpdate;
- (void) endUpdate;
+ (void)preferencesChanged:(NSNotification *)notification;
#if 0
- (void)columnSizeChanged:(NSNotification *)aNotification;
#endif
- (int) columnForPath: (NSString*) aPath;
- (int) columnForFile: (CVLFile *) aFile;
- (NSBrowserCell *)cellForFile:(CVLFile *)aFile inColumn:(int)column;
- (int)cellRowForFile:(CVLFile *)aFile inColumn:(int)column;
@end

//-------------------------------------------------------------------------------------

@interface BrowserController(BrowserDelegate)
- updateCell:(SenBrowserCell *)aCell forFile:(CVLFile *)aFile;
@end

//-------------------------------------------------------------------------------------

@implementation BrowserController

+ (void)initialize
{
    NSBundle *aBundle = nil;
    NSString *aPath = nil;
    NSDictionary *theStatusImageNamesDictionary = nil;
    NSDictionary *theWatchImageNamesDictionary = nil;
    
    
    if ([self class] == [BrowserController class]) {
        // Get the status image names.
        aBundle = [NSBundle bundleForClass:[self class]];
        SEN_ASSERT_NOT_NIL(aBundle);
        aPath = [aBundle pathForResource:@"statusImages" ofType:@"table"];
        SEN_ASSERT_NOT_EMPTY(aPath);
        theStatusImageNamesDictionary = [[NSDictionary alloc] 
                                            initWithContentsOfFile:aPath];
        SEN_ASSERT_NOT_EMPTY(theStatusImageNamesDictionary);
        [theStatusImageNamesDictionary autorelease];
        statusImagesArray = [theStatusImageNamesDictionary objectForKey:@"defaults"];
        SEN_ASSERT_NOT_EMPTY(statusImagesArray);
        [statusImagesArray retain];
        
        // Get the watch image names.
        aBundle = [NSBundle bundleForClass:[self class]];
        SEN_ASSERT_NOT_NIL(aBundle);
        aPath = [aBundle pathForResource:@"watchImages" ofType:@"table"];
        SEN_ASSERT_NOT_EMPTY(aPath);
        theWatchImageNamesDictionary = [[NSDictionary alloc] 
                                            initWithContentsOfFile:aPath];
        SEN_ASSERT_NOT_EMPTY(theWatchImageNamesDictionary);
        [theWatchImageNamesDictionary autorelease];
        watchedImagesArray = [theWatchImageNamesDictionary objectForKey:@"defaults"];
        SEN_ASSERT_NOT_EMPTY(watchedImagesArray);
        [watchedImagesArray retain];
        
//        [[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:BROWSER_COLUMN_MIN_WIDTH, browserColumnWidthKey, nil]];
// (120) unuseful here, code moved to [CVLDelegate initialize]
        cvsEditorsAndWatchersEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CvsEditorsAndWatchersEnabled"];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesChanged:) name:@"PreferencesChanged" object:nil];
        [self preferencesChanged:nil];
    }
}

+ (void)preferencesChanged:(NSNotification *)notification
{
    browserColumnWidth=[[NSUserDefaults standardUserDefaults] integerForKey:browserColumnWidthKey];
    browserMinColumnCount=[[NSUserDefaults standardUserDefaults] integerForKey:browserMinColumnCountKey];
    
    browserColumnCount=[[NSUserDefaults standardUserDefaults] integerForKey:browserColumnCountKey];
    browserMinColumnWidth=[[NSUserDefaults standardUserDefaults] integerForKey:browserMinColumnWidthKey];
    
    browserResizeBehavior=[[NSUserDefaults standardUserDefaults] integerForKey:browserResizeBehaviorKey];
#if 0
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ColumnSizeChanged" object:self];
#endif
}

#if 0
- (void)columnSizeChanged:(NSNotification *)aNotification
{
    [delegate viewerFrameSizeChanged:self];
}
#endif

+ setImageDict:(NSArray *)dict
{
    ASSIGN(statusImagesArray, dict);

  return self;
}


+ (BrowserController*) browserForPath: (NSString*) aPath
{
  return [[[BrowserController alloc] initForPath: aPath] autorelease];
}

- init
{
  return [self initForPath: NSHomeDirectory()];
} // init


- initForPath: (NSString*) pathString;
{
  self= [super init];
    ASSIGN(resultsRepository, [ResultsRepository sharedResultsRepository]);
  ASSIGN(rootFile, [CVLFile treeAtPath:pathString]);
  rightSizeArray = [[NSMutableArray alloc] initWithCapacity:10];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(browserResultChanged:)
                                               name:@"ResultsChanged"
                                             object:nil];
#if 0
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(columnSizeChanged:)
                                               name:@"ColumnSizeChanged"
                                             object:nil];
#endif
  return self;
} // initForPath:

- (void) dealloc
{
    int	i;
    
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(resultsRepository);
  RELEASE(rootFile);
  RELEASE(filters);
  RELEASE(filterProvider);
  for (i=0;i<=ECInvalidFile;i++) {
    RELEASE(cellPrototypes[i]);
      cellPrototypes[i] = nil;
  }
  RELEASE(browser);
  //    [blackCellPrototype release];
  //    [grayCellPrototype release];
  RELEASE(cvsRepository);

  [super dealloc];
} // dealloc


- (void)awakeFromNib
{
	SenBrowserCell *aSenBrowserCell = nil;
    SenBrowserTextCell *aSubcell;
    SenBrowserTextCell *aWatchersCell;
    int i;
    unsigned int indexOfName = 0;
  
	aSenBrowserCell = [[SenBrowserCell cell] retain];
	cellPrototypes[ECCVSFile] = aSenBrowserCell;

  aWatchersCell=[[SenBrowserTextCell alloc] init];
  [aWatchersCell setAlignment:NSRightTextAlignment];
  [aWatchersCell autorelease];  
  [aSenBrowserCell setLeaf:YES];
  if ( cvsEditorsAndWatchersEnabled ) {  
      [aSenBrowserCell addTabWithFixedWidth:15]; // status
      [aSenBrowserCell addTabWithFixedWidth:15]; // Edit icon
      [aSenBrowserCell addTabWithFixedWidth:20]; // Number of watchers
      [aSenBrowserCell addTabWithProportionalWidth:100]; // Name
      [aSenBrowserCell setSubcell:[[[NSImageCell alloc] init] autorelease] atIndex:0];
      [aSenBrowserCell setSubcell:[[[NSImageCell alloc] init] autorelease] atIndex:1];
      [aSenBrowserCell setSubcell:aWatchersCell atIndex:2];
      indexOfName = 3;
  } else {
      [aSenBrowserCell addTabWithFixedWidth:15]; // status
      [aSenBrowserCell addTabWithProportionalWidth:100]; // Name
      [aSenBrowserCell setSubcell:[[[NSImageCell alloc] init] autorelease] atIndex:0];
      indexOfName = 1;
  }
  [aSenBrowserCell setNamePosition:indexOfName];
  aSubcell=[[SenBrowserTextCell alloc] init];
  [aSenBrowserCell setSubcell:aSubcell atIndex:indexOfName];
  [aSubcell setDrawsBackground:NO];
  [aSubcell release];
  
  [browser setMatrixClass:[CVLBrowserMatrix class]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(select:)
                                               name:@"CVLBrowserSelectionDidChangeNotification"
                                             object:browser];

  for (i=1;i<=ECInvalidFile;i++) {
    cellPrototypes[i]=[aSenBrowserCell copy];
  }

  aSubcell=[[SenBrowserTextCell alloc] init];
  [cellPrototypes[ECLocalFile] setSubcell:aSubcell atIndex:indexOfName];
  [aSubcell setDrawsBackground:NO];
  [aSubcell release];

  aSubcell=[[SenBrowserTextCell alloc] init];
  [cellPrototypes[ECAbsentFile] setSubcell:aSubcell atIndex:indexOfName];
  [aSubcell setTextColor:[NSColor darkGrayColor]];
  [aSubcell release];

  aSubcell=[[SenBrowserTextCell alloc] init];
  [cellPrototypes[ECInactiveFile] setSubcell:aSubcell atIndex:indexOfName];
  [aSubcell setTextColor:[NSColor darkGrayColor]];
  [aSubcell release];

  aSubcell=[[SenBrowserTextCell alloc] init];
  [cellPrototypes[ECInvalidFile] setSubcell:aSubcell atIndex:indexOfName];
  {
      static NSColor	*myRedColor = nil;

      if(!myRedColor)
          ASSIGN(myRedColor, [NSColor colorWithCalibratedRed:0.74 green:0.0 blue:0.0 alpha:1.0]);
      [aSubcell setTextColor:myRedColor];
  }
  [aSubcell release];

  filters=[[NSMutableArray alloc] init];
  [browser retain]; // to avoid releasing it by someone else
  [[browser window] release];
  [browser setCellPrototype: aSenBrowserCell];
  //    [browser setPath: @""];
//  [browser loadColumnZero];
  [browser setDoubleAction: @selector(doubleSelect:)];
  [browser setAcceptsArrowKeys:YES];
  [browser setSendsActionOnArrowKeys:YES];
  [browser sendAction];		// perform a select: action

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(browserResized:)
                                               name:NSViewFrameDidChangeNotification
                                               object:browser];
} // awakeFromNib

- (void)setDelegate:(id)aDelegate
{
    delegate=aDelegate;
}

- (void)setFilterProvider:(id)value
{
    ASSIGN(filterProvider, value);
    [browser loadColumnZero];
}

- (void) reloadData
{
    [browser loadColumnZero];
}

- (void)select:(id)sender
{
  if ([[browser window] isKeyWindow]){
      [[NSNotificationCenter defaultCenter] postNotificationName:@"PathSelected" object: [self selectedPaths]];
  }
} // select:

- (void)doubleSelect:(id)sender
{
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ViewerDoubleSelect" object: self];
} // doubleSelect:


- view
{
  if (!browser) {
    [NSBundle loadNibNamed:@"EasyCVSBrowser.nib" owner:self];
  }
  return browser;
} //view

- (NSString*) rootPath
{
  return [rootFile path];
}

-(NSArray *)relativeSelectedPaths
    /*" This method returns an array of relative paths as NSStrings. These 
        relative paths have been extracted from the selected files in the 
        current browser. All of these paths are relative to current root path.

        See also#{-rootPath}
    "*/
{
    NSArray *selectedCells;

    selectedCells=[browser selectedCells];

    if ([selectedCells count]) {
        NSMutableArray *result;
        NSString *path;
        id enumerator;
        NSBrowserCell *cell;

        path=[browser pathToColumn:[browser selectedColumn]];
        if ([path length]>1) {
            path=[path substringFromIndex:1];
        } else {
            path=@"";
        }
        result=[NSMutableArray array];
        enumerator=[selectedCells objectEnumerator];

        while ( (cell=[enumerator nextObject]) ) {
            [result addObject:[path stringByAppendingPathComponent:[cell stringValue]]];
        }

        return result;
    } else {
        return nil;
    }
}

- (NSArray *) relativePathsFromSelectedCVLFilesUnrolled
    /*" This method returns an array of relative paths as NSStrings. These 
        relative paths have been extracted from the selected CVLFiles that have
        been unrolled. All of these paths are relative
        to current root path.

        See also #{-selectedCVLFilesUnrolled} and 
        #{-relativePathsFromCVLFiles:}
    "*/
{
    NSArray         *mySelectedCVLFiles = nil;
    NSArray         *myRelativeSelectedPaths = nil;
    
    mySelectedCVLFiles = [self selectedCVLFilesUnrolled];
    if ( isNotEmpty(mySelectedCVLFiles) ) {
        myRelativeSelectedPaths = [self relativePathsFromCVLFiles:mySelectedCVLFiles];
    }
    return myRelativeSelectedPaths;    
}

- (NSArray *) relativePathsFromSelectedCVLFilesUnrolledAndFiltered
    /*" This method returns an array of relative paths as NSStrings. These 
        relative paths have been extracted from the selected CVLFiles that have
        been first unrolled and then filtered. All of these paths are relative
        to current root path.
    
        See also #{-selectedCVLFilesUnrolledAndFiltered} and 
        #{-relativePathsFromCVLFiles:}
    "*/
{
    NSArray         *mySelectedCVLFiles = nil;
    NSArray         *myRelativeSelectedPaths = nil;
    
    mySelectedCVLFiles = [self selectedCVLFilesUnrolledAndFiltered];
    if ( isNotEmpty(mySelectedCVLFiles) ) {
        myRelativeSelectedPaths = [self relativePathsFromCVLFiles:mySelectedCVLFiles];
    }
    return myRelativeSelectedPaths;    
}

- (NSArray *) relativePathsFromCVLFiles:(NSArray *)someCVLFiles
    /*" This method returns an array of relative paths as NSStrings. These 
        relative paths have been extracted from the array of CVLfiles named
        someCVLFiles. All of these paths are relative to current root path.

        See also #{-selectedCVLFilesUnrolledAndFiltered}, 
        #{-relativePathFromCVLFile:}, 
        #{-relativePathsFromSelectedCVLFilesUnrolled} and #{-rootPath}
    "*/
{
    NSMutableArray  *myRelativeSelectedPathsFiltered = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    NSString        *aRelativePath = nil;
    unsigned int    aCount = 0;
    
    if ( isNotEmpty(someCVLFiles) ) {
        aCount = [someCVLFiles count];
        myRelativeSelectedPathsFiltered = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            aRelativePath = [self relativePathFromCVLFile:aCVLFile];
            if ( isNotEmpty(aRelativePath) ) {
                [myRelativeSelectedPathsFiltered addObject:aRelativePath];
            }
        }
    }
    return myRelativeSelectedPathsFiltered;    
}

- (NSString *) relativePathFromCVLFile:(CVLFile *)aCVLFile
    /*" This method returns a relative path as an NSString. This
        relative path have been extracted from aCVLFile. This path is relative
        to current root path.

        See also #{-relativePathFromPath:}. 
    "*/
{
    NSString        *anAbsolutePath = nil;
    NSString        *aRelativePath = nil;
    
    if ( aCVLFile != nil ) {
        anAbsolutePath = [aCVLFile path];
        aRelativePath = [self relativePathFromPath:anAbsolutePath];
    }
    return aRelativePath;    
}

- (NSString *) relativePathFromPath:(NSString *)aPath
    /*" This method returns a relative path as an NSString. This relative path 
        have been extracted from the absolute path given in the argument aPtah. 
        The path return is relative to current root path.

        See also #{-relativePathFromCVLFile:}. 
    "*/
{
    NSString        *myRootPath = nil;
    NSString        *aRelativePath = nil;
    NSString        *aCommonPrefix = nil;
    NSString        *aPossibleSlash = nil;
    NSString        *aNewRelativePath = nil;
    unsigned int    anIndex = 0;
    
    if ( isNotEmpty(aPath) ) {
        myRootPath = [self rootPath];
        aCommonPrefix = [aPath commonPrefixWithString:myRootPath options:0];
        anIndex = [aCommonPrefix length];
        aRelativePath = [aPath substringFromIndex:anIndex];
        // Strip off the slash in front if any is found,
        aPossibleSlash = [aRelativePath commonPrefixWithString:@"/" options:0];
        if ( isNotEmpty(aPossibleSlash) ) {
            anIndex = [aPossibleSlash length];
            aNewRelativePath = [aRelativePath substringFromIndex:anIndex];
        } else {
            aNewRelativePath = aRelativePath;
        }
    }
    return aNewRelativePath;    
}

-(NSArray *)selectedPaths
    /*" This method returns an array of paths as NSStrings. These paths have 
        been extracted from the selected files in the current browser.
    "*/
{
  NSArray *selectedCells;
    
  selectedCells=[browser selectedCells];

  if ([selectedCells count]) {
    NSMutableArray *result;
    NSString *path;
    id enumerator;
    NSBrowserCell *cell;
    NSString *theRootPath = nil;
    NSString *aPathComponent = nil;

    theRootPath = [self rootPath];
    aPathComponent = [browser pathToColumn:[browser selectedColumn]];
    path=[theRootPath stringByAppendingPathComponent:aPathComponent];
    result=[NSMutableArray array];
    enumerator=[selectedCells objectEnumerator];

    while ( (cell=[enumerator nextObject]) ) {
      [result addObject:[path stringByAppendingPathComponent:[cell stringValue]]];
    }

    return result;
  } else {
      return nil; //    return [NSArray arrayWithObject:rootPath];
  }
}

- (NSArray *) selectedCVLFiles
    /*" This method returns an array of CVLFiles that have been selected in the 
        CVL Browser. If none are selected then nil is returned. CVLFiles that
        are ignored are not included. If no CVLFiles are to be returned due to
        being ignored then nil is returned instead of an empty array.
    "*/
{
    NSString		*aFilePath = nil;
    NSEnumerator	*aSelectedPathsEnumerator = nil;
    CVLFile         *aCVLFile = nil;
    NSArray         *theSelectedPaths = nil;
    NSMutableArray  *mySelectedCVLFiles = nil;
    unsigned int    aCount = 0;
    
    theSelectedPaths = [self selectedPaths];
    if ( isNotEmpty(theSelectedPaths) ) {
        aCount = [theSelectedPaths count];
        mySelectedCVLFiles = [NSMutableArray arrayWithCapacity:aCount];
        aSelectedPathsEnumerator = [[self selectedPaths] objectEnumerator];
        while( (aFilePath = [aSelectedPathsEnumerator nextObject]) ) {
            aCVLFile = (CVLFile *)[CVLFile treeAtPath:aFilePath];
            if ( (aCVLFile != nil) &&
                 ([aCVLFile isIgnored] == NO) ) {
                [mySelectedCVLFiles addObject:aCVLFile];
            }
        }        
        if ( isNilOrEmpty(mySelectedCVLFiles) ) {
            mySelectedCVLFiles = nil;
        }        
    }
    return mySelectedCVLFiles;
}

- (CVLFile *) selectedCVLFile
    /*" This method returns the one CVLFile that has been selected in the 
        CVL Browser. If none are selected then nil is returned. If more than one
        is selected then nil is also returned.
    "*/
{
    NSArray     *mySelectedCVLFiles = nil;
    CVLFile     *mySelectedCVLFile = nil;
    
    mySelectedCVLFiles = [self selectedCVLFiles];
    if ( (mySelectedCVLFiles != nil) &&
         ([mySelectedCVLFiles count] == 1) ) {
        mySelectedCVLFile = [mySelectedCVLFiles objectAtIndex:0];
    }
    return mySelectedCVLFile;
}

- (NSArray *) selectedCVLFilesUnrolled
    /*" This method returns an array of CVLFiles that have been selected in the 
        CVL Browser and then unrolled. Unrolled means that directories are
        replaced by their contents and any directories in these contents are
        also replaced by their contents and so on. All CVLFiles that are ignored
        are omitted. If no files are selected then nil is returned. If all
        selected files are to be ignored then nil is also returned.
    "*/
{
    NSArray *mySelectedCVLFiles = nil;
    NSArray *mySelectedCVLFilesUnrolled = nil;
    
    mySelectedCVLFiles = [self selectedCVLFiles];
    if ( isNotEmpty(mySelectedCVLFiles) ) {
        mySelectedCVLFilesUnrolled = [self unrollCVLFiles:mySelectedCVLFiles];
    }
    return mySelectedCVLFilesUnrolled;
}

- (NSArray *) unrollCVLFiles:(NSArray *)someCVLFiles
    /*" This method returns an array of CVLFiles that are contained in the array
        someCVLFiles and then unrolled. Unrolled means that directories are
        replaced by their contents and any directories in these contents are
        also replaced by their contents and so on. All CVLFiles that are ignored
        are omitted. If someCVLFiles is nil or empty then nil is returned. If all
        the files in someCVLFiles are to be ignored then nil is also returned.
    "*/
{
    NSMutableArray  *someCVLFilesUnrolled = nil;
    CVLFile         *aCVLFile = nil;
    NSArray         *aCVLFilesChilren = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCount = 0;
    
    if ( isNotEmpty(someCVLFiles) ) {
        aCount = [someCVLFiles count];
        someCVLFilesUnrolled = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile isRealDirectory] == YES ) {
                aCVLFilesChilren = [aCVLFile unrolled];
                if ( isNotEmpty(aCVLFilesChilren)  ) {
                    [someCVLFilesUnrolled addObjectsFromArray:aCVLFilesChilren];
                }
            } else if ( [aCVLFile isIgnored] == NO ) {
                [someCVLFilesUnrolled addObject:aCVLFile];
            }
        }
        if ( isNilOrEmpty(someCVLFilesUnrolled) ) {
            someCVLFilesUnrolled = nil;
        }
    }
    return someCVLFilesUnrolled;
}

- (NSArray *)directoriesInCVLFiles:(NSArray *)someCVLFiles unrolled:(BOOL)isUnrolled
    /*" This method returns an array of CVLFiles that represent directories that
        are contained in the array someCVLFiles. The directoris that are 
        contained in the array someCVLFiles are also unrolled if the argument 
        isUnrolled is YES. Unrolled means that the contents of the directories 
        are added to the CVLFiles that are examined and any directories in these
        contents are also added and so on. All CVLFiles that are ignored
        are omitted. If someCVLFiles is nil or empty then nil is returned. If all
        the files in someCVLFiles are to be ignored then nil is also returned.
    "*/
{
    NSMutableArray  *theDirectoriesInCVLFiles = nil;
    CVLFile         *aCVLFile = nil;
    NSArray         *aCVLFilesChilren = nil;
    NSArray         *theDirectoriesInTheChilren = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCount = 0;
    
    if ( isNotEmpty(someCVLFiles) ) {
        aCount = [someCVLFiles count];
        theDirectoriesInCVLFiles = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( [aCVLFile isRealDirectory] == YES ) {
                if ( [aCVLFile isIgnored] == NO ) {
                    [theDirectoriesInCVLFiles addObject:aCVLFile];
                    if ( isUnrolled == YES ) {
                        aCVLFilesChilren = [aCVLFile loadedChildren];
                        if ( isNotEmpty(aCVLFilesChilren)  ) {
                            theDirectoriesInTheChilren = [self 
                                        directoriesInCVLFiles:aCVLFilesChilren 
                                                     unrolled:isUnrolled];
                            if ( isNotEmpty(theDirectoriesInTheChilren) ) {
                                [theDirectoriesInCVLFiles 
                                addObjectsFromArray:theDirectoriesInTheChilren];
                            }
                        }                    
                    }                    
                }
            }
        }
        if ( isNilOrEmpty(theDirectoriesInCVLFiles) ) {
            theDirectoriesInCVLFiles = nil;
        }
    }
    return theDirectoriesInCVLFiles;
}

- (NSArray *) selectedCVLFilesUnrolledAndFiltered
    /*" This method returns an array of CVLFiles that have been selected in the 
        CVL Browser and then unrolled and then filtered. 

        See also #{-filteredCVLFiles:} and #{-selectedCVLFilesUnrolled}
    "*/
{
    return [self filteredCVLFiles:[self selectedCVLFilesUnrolled]];
}

- (NSArray *) filteredCVLFiles:(NSArray *)someCVLFiles
    /*" This method returns an array of CVLFiles each of which are included in
        the argument array named someCVLFiles and are neither ignored nor a
        wrapped directory.
    "*/
{
    NSMutableArray  *myFilteredCVLFiles = nil;
    CVLFile         *aCVLFile = nil;
    NSEnumerator    *anEnumerator = nil;
    unsigned int    aCount = 0;
    
    if ( isNotEmpty(someCVLFiles) ) {
        aCount = [someCVLFiles count];
        myFilteredCVLFiles = [NSMutableArray arrayWithCapacity:aCount];
        anEnumerator = [someCVLFiles objectEnumerator];
        while ( (aCVLFile = [anEnumerator nextObject]) ) {
            if ( ([aCVLFile isRealWrapper] == NO) &&
                 ([aCVLFile isIgnored] == NO) ) {
                [myFilteredCVLFiles addObject:aCVLFile];
            }
        }
    }
    return myFilteredCVLFiles;
}

- (void)selectFiles:(NSSet *)someFiles
    /*" NB: someFiles is a set of CVLFiles.
    "*/
{
    NSMutableArray *filePath;
    int column;
    CVLFile *lastColumnSelection;
    CVLFile *columnSelection;
    CVLFile *aFile;
    id enumerator;

    filePath=[NSMutableArray array];
    lastColumnSelection=[someFiles anyObject];
    while ((lastColumnSelection) && (lastColumnSelection!=rootFile)) {
        [filePath insertObject:lastColumnSelection atIndex:0];
        lastColumnSelection=[lastColumnSelection parent];
    }

    if (!lastColumnSelection) return;

    if ([filePath count]) {
        column=0;
        lastColumnSelection=rootFile;

        [filePath removeLastObject];

        enumerator=[filePath objectEnumerator];
        while ( (columnSelection=[enumerator nextObject]) ) {
            [browser selectRow:[self cellRowForFile:columnSelection inColumn:column] inColumn:column];
            lastColumnSelection=columnSelection;
            column++;
        }

        // now select all files in last column
        enumerator=[someFiles objectEnumerator];
        while ( (aFile=[enumerator nextObject]) ) {
            if ([aFile parent]==lastColumnSelection) {
                [browser selectRow:[self cellRowForFile:aFile inColumn:column] inColumn:column];
            }
        }
    } else {
        [browser selectRow:-1 inColumn:-1];
        // unselect all
    }
    [self select:self];
}

-(BOOL)selectionIsOneDir
{
	NSArray *theSelectedCells = nil;
	NSBrowser *aBrowserCell = nil;

	theSelectedCells = [browser selectedCells];
	if ( [theSelectedCells count] == 1 ) {
		aBrowserCell = [theSelectedCells objectAtIndex:0];
		if ( [aBrowserCell isLeaf] == NO ) {
			return YES;
		}
	}
	return NO;
}

- (NSSize) viewerWillResizetoSize: (NSSize) frameSize
{
    int newColumnCount = 0;
    int minWidth = 0;
    
    if ( (browserResizeBehavior == 2) ) {
        // A fixed number of columns with each column having a minimum size.
        minWidth = browserColumnCount*(4+browserMinColumnWidth)-4;
        if ( minWidth > frameSize.width ) {
            frameSize.width = minWidth;
        }        
    } else {
        // A fixed column size with a minimum number of columns.
        minWidth = browserMinColumnCount*(4+browserColumnWidth)-4;
        if ( minWidth > frameSize.width ) {
            frameSize.width = minWidth;
        }
        newColumnCount=(int) (((float)(4+frameSize.width)) / (float)(4+browserColumnWidth)+0.5);	

        frameSize.width= newColumnCount*(4+browserColumnWidth)-4;
    }
    requestedBrowserSize=frameSize;
    
    return frameSize;
} // viewerWillResizetoSize:

- (void) browserResized: (NSNotification *)notification
{
    // Invoked ONLY if browser size changed!
    if ( (browserResizeBehavior == 2) ) {
        // A fixed number of columns with each column having a minimum size.
        [browser setMaxVisibleColumns:browserColumnCount];
    } else {
        // A fixed column size with a minimum number of columns.
        int newColumnCount;

        newColumnCount= (4+[browser frame].size.width) / (4+browserColumnWidth);
        //    [browser setMinColumnWidth:browserColumnWidth];
        [browser setMaxVisibleColumns: newColumnCount];
    }
}

- (int)cellRowForFile:(CVLFile *)aFile inColumn:(int)column
{
    NSMatrix *matrix=[browser matrixInColumn:column];
    NSBrowserCell *cell = nil;
    int anIndex=0 ,count=[matrix numberOfRows];

    while (anIndex<count) {
        cell=(NSBrowserCell *)[matrix cellAtRow:anIndex column:0];
        if ([aFile isEqual:[cell representedObject]]) {
            break;
        }
        anIndex++;
    }
    
    if (cell) {
        return anIndex;
    } else {
        return -1;
    }
}

- (NSBrowserCell *)cellForFile:(CVLFile *)aFile inColumn:(int)column
{
    NSMatrix *matrix=[browser matrixInColumn:column];
    NSBrowserCell *cell;
    int anIndex=0 ,count=[matrix numberOfRows];

    while (anIndex<count) {
        cell=(NSBrowserCell *)[matrix cellAtRow:anIndex column:0];
        if ([aFile isEqual:[cell representedObject]]) {
            return cell;
        }
        anIndex++;
    }
    return nil;
}

- (NSBrowserCell *)cellForName:(NSString *)aName inColumn:(int)column
{
  NSMatrix *matrix=[browser matrixInColumn:column];
  NSBrowserCell *cell;
  int anIndex=0 ,count=[matrix numberOfRows];

  while (anIndex<count) {
    cell=(NSBrowserCell *)[matrix cellAtRow:anIndex column:0];
    if ([aName isEqual:[cell stringValue]]) {
      return cell;
    }
    anIndex++;
  }
  return nil;
}

- (int) columnForFile: (CVLFile *) aFile
// Move this into a NSBrowser category
{
    return [self columnForPath:[aFile path]];
}

- (int) columnForPath: (NSString*) aPath
// Move this into a NSBrowser category
{	// return column which is displaying 'aPath' or -1 if not found
  NSArray *pathComponents=[aPath pathComponents];
  NSArray *rootPathComponents=[[self rootPath] pathComponents];
  NSArray *localPathArray;
  NSString *pathComponent;
  NSRange localRange;
  id enumerator;
  int count=0;

  localRange.location=0;
  localRange.length=[rootPathComponents count];

  if ([pathComponents count]<localRange.length) {
    return -1;
  }
  localPathArray=[pathComponents subarrayWithRange:localRange];
  if (![localPathArray isEqual:rootPathComponents]) {
    return -1;
  }

  localRange.location=0+localRange.length;
  localRange.length=[pathComponents count]-localRange.length;

  if ([browser selectedColumn]+1 < (int)localRange.length) {
    return -1;
  }

  localPathArray=[pathComponents subarrayWithRange:localRange];
  enumerator=[localPathArray objectEnumerator];

  while ( (pathComponent=[enumerator nextObject]) ) {
    if (![[[browser selectedCellInColumn:count] stringValue] isEqual:pathComponent]) {
      return -1;
    } else {
      count++;
    }
  }

  return count;
} //columnForPath:

- (void) filteredContentsChanged:(NSNotification *)notification
{
    int column;

    column=[filters indexOfObject:[notification object]];
    [browser reloadColumn: column];
    [self select:self];
}

- (void) browserResultChanged: (NSNotification *)notification
{
    id fileEnum;
    NSBrowserCell *cell;
    NSString *name;
    int column;
    CVLFile *file,*directory;
    ECFileAttributeGroups changes;

    if (!updateCount) {
        if ((resultsRepository == [notification object]) && ([resultsRepository hasChanged])) {	
            [self startUpdate];
            //[[browser window] disableFlushWindow];

            //reloadedPaths=[NSMutableSet set];
            //columnsToDisplay=[NSMutableSet set];
            fileEnum=[[resultsRepository changedFiles] objectEnumerator];

            while ( (file= [fileEnum nextObject]) ) {
                directory=[file parent];
                column=[self columnForFile:directory];
                if (column>=0 || file == rootFile) {
                    changes=[file changes];
                    if (changes.status || 
                        changes.quickStatus ||
                        changes.cvsEditorsFetchedFlag || 
                        changes.cvsWatchersFetchedFlag) {
                        //if (![reloadedPaths containsObject: directory]) {
                        if(file != rootFile){
                            name=[[file path] lastPathComponent];
                            if  ( (cell=[self cellForFile:file inColumn:column]) ) {
                                [cell setLoaded:NO];
                                [browser setNeedsDisplay:YES];
                                //[self updateCell:cell forName:name inDir:dir];
                                //[columnsToDisplay addNewObject:[NSNumber numberWithInt:column]];
                            }
                        }
                        else{
                            (void)[file status]; // In order to have root directory behave like any other dir, we NEED to ask it for its status!!!
                        }
                        //}
                    }
                }
            }

            /*enumerator=[columnsToDisplay objectEnumerator];
            while (columnNumber=[enumerator nextObject]) {
                [browser displayColumn:[columnNumber intValue]];
            }*/

            //                [[browser window] enableFlushWindow];
            [self endUpdate];
        }
    }
} // browserResultChanged:


- (void) startUpdate
{
    updateCount++;
}


- (void) endUpdate
{
  updateCount--;
}

- (NSString *)cvsFullRepositoryPath
    /*" This method returns the full repository path that represents the
        repository that is tied to the workarea that this browser is displaying.

        For more information see also: #{-cvsFullRepositoryPathForDirectory:}
        in the CvsRepository class.
    "*/
{
    NSString *myRootPath = nil;
    NSString *myCvsFullRepositoryPath = nil;
    
    myRootPath = [self rootPath];
    myCvsFullRepositoryPath = [CvsRepository cvsFullRepositoryPathForDirectory:myRootPath];
    
    return myCvsFullRepositoryPath;
}

- (CvsRepository *)cvsRepository
	/*" This method returns the CvsRepository that handles this browser's
		workarea.
	"*/
{
	if ( cvsRepository == nil ) {
		NSString *myRootPath = nil;
		NSString *myCvsRootPath = nil;
		
		myRootPath = [self rootPath];
		myCvsRootPath = [CvsRepository cvsRootPathForDirectory:myRootPath];
		cvsRepository = [CvsRepository repositoryWithRoot:myCvsRootPath];
		[cvsRepository retain];		
	}
	return cvsRepository;
}


@end

//-------------------------------------------------------------------------------------

@implementation BrowserController(BrowserDelegate)

- updateCell:(SenBrowserCell *)aCell forFile:(CVLFile *)aFile
{
    NSString *absolutePath = nil;
    NSString *imageName = nil;
    NSString *myCvsEditImageName = nil;
    NSArray *cvsEditorsForAFile = nil;
    NSImage *anIconImage = nil;
    NSNumber *aCountNumber = nil;
    ECStatus status;
    ECFileFlags fileFlags;
    unsigned int anEditorsCount = 0;
    unsigned int aWatchersCount = 0;

  [self startUpdate];
  [resultsRepository startUpdate];
  absolutePath= [aFile path];

  fileFlags=[aFile flags];

  [aCell setRepresentedObject:aFile];
  [aCell setLeaf:[aFile isLeaf]];
  [aCell setStringValue:[aFile name]];
  [aCell useTemplate:cellPrototypes[fileFlags.type]];

  status=[aFile status];
  if (!(imageName=[statusImagesArray objectAtIndex:status.statusType])) {
      imageName=[statusImagesArray objectAtIndex:0];
  }
  [aCell setObjectValue:[NSImage imageNamed:imageName] atIndex:0];

  if ( cvsEditorsAndWatchersEnabled ) {
      cvsEditorsForAFile = [aFile cvsEditors];
      if ( isNotEmpty(cvsEditorsForAFile) ) {
          anEditorsCount = [cvsEditorsForAFile count];
          if ( [aFile cvsEditorForCurrentUser] != nil ) {
              // We come here if the current user is an editor of this file.
              if ( anEditorsCount > 1 ) {
                  myCvsEditImageName = @"PencilBarredRed";
              } else {
                  myCvsEditImageName = @"Pencil";
              }
          } else {
              // We come here if the current user is NOT an editor of this file.
              myCvsEditImageName = @"PencilBarred";
          }
      } else {
          // We come here if here are no editors for this file.
          // We display an eye if the current user watches this file and
          // there are no other editors for it.
          if ( [aFile cvsWatcherForCurrentUser] != nil ) {
              myCvsEditImageName = @"Eye";
          }          
      }
      if ( isNilOrEmpty(myCvsEditImageName) ) {
          myCvsEditImageName = [watchedImagesArray objectAtIndex:0];
      }   
      anIconImage = [NSImage imageNamed:myCvsEditImageName];
      SEN_ASSERT_NOT_NIL(anIconImage);
      [aCell setObjectValue:anIconImage atIndex:1];
      
      aWatchersCount = [[aFile cvsWatchers] count];
      if ( aWatchersCount > 0 ) {
          aCountNumber = [NSNumber numberWithUnsignedInt:aWatchersCount];
          [aCell setObjectValue:aCountNumber atIndex:2];
      } else {
          // Use an empty string if the count is zero so we do not have a whole
          // bunch of zeroes cluttering up the interface.
          [aCell setObjectValue:@"" atIndex:2];
      }      
  }
  
  // Default system font can not have italic trait!
  if ( ([aFile hasStickyTagOrDate] == YES) &&
       ([aFile isABranch] == NO) ) {
      [aCell setFont:[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:[NSFont smallSystemFontSize]] toHaveTrait:NSItalicFontMask]];
  } else {
      [aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
  }

    // If this is a branch file then color it blue (unless it is an invalid file
    // which is already colored red.
    if ( [aFile isABranch] == YES ) {
        if ( fileFlags.type != ECInvalidFile ) {
            unsigned int theNamePosition = 0;
			SenBrowserTextCell *aTextCell = nil;
			
			theNamePosition = [aCell namePosition];
			aTextCell = (SenBrowserTextCell *)[aCell subcellAtIndex:theNamePosition];
            [aTextCell setTextColor:[NSColor blueColor]];
        }
    }    
  
  [aCell setEnabled:YES];
  [aCell setLoaded:YES];
  [resultsRepository endUpdate];
  [self endUpdate];

  return self;
}

- (void)browser:(NSBrowser *)aBrowser willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
	CVLFile         *aCVLFile = nil;

	// Only for the browser equal to the instance variable browser.
	if ( aBrowser != browser ) return;

  [self startUpdate];
  [resultsRepository startUpdate];

  if (![cell isLoaded]) {
    NSArray* contentArray;

    contentArray= [[filters objectAtIndex:column] filteredContents];
    if (row < (int)[contentArray count]) {
		aCVLFile = [contentArray objectAtIndex:row];
        [self updateCell:cell forFile:aCVLFile];
    } 
  }

  [resultsRepository endUpdate];
  [self endUpdate];
}

- (void)browser:(NSBrowser *)aBrowser createRowsForColumn:(int)column inMatrix:(NSMatrix *)matrix
{
  NSString *fullPath;
  NSArray *contentArray;		
  id enumerator;
  int count= 0;
  CVLFile *file;
  DirectoryContentsFilter *filter;
		
  // Only for the browser equal to the instance variable browser.
  if ( aBrowser != browser ) return;

  if (![[aBrowser cellPrototype] isKindOfClass:[SenBrowserCell class]]) {	
    // this happens when the browser display itself and before awakeFromNib is called !
    return;
  }
  
  [self startUpdate];
  [resultsRepository startUpdate];

  fullPath=[[self rootPath] stringByAppendingPathComponent:[browser pathToColumn:column]];

  // set up filter if needed
  if (filterProvider) {
      if ((int)[filters count] <= column) {
          filter=[filterProvider filterForDirectory:fullPath];
          [filters addObject:filter];
          [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filteredContentsChanged:)
                                                       name:@"FilteredContentsChanged"
                                                     object:filter];
      } else if (![[(filter=[filters objectAtIndex:column]) filteredDirectoryPath] isEqual:fullPath]) {
          [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:filter];
          filter=[filterProvider filterForDirectory:fullPath];
          [filters replaceObjectAtIndex:column withObject:filter];
          [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(filteredContentsChanged:)
                                                       name:@"FilteredContentsChanged"
                                                     object:filter];
      }
      contentArray= [filter filteredContents];
  } else {
      contentArray=nil;
  }
  
  enumerator=[contentArray objectEnumerator];
  while ( (file=[enumerator nextObject]) ) {
    [matrix addRow];
      [self updateCell:[matrix cellAtRow:count column:0] forFile:file];
    count++;
  }
  [matrix sizeToCells];

  [resultsRepository endUpdate];
  [self endUpdate];

  // Add contextual menu: use File menu
  if(![matrix menu])
      [matrix setMenu:[[[[[[NSApplication sharedApplication] mainMenu] itemWithTag:FILE_MENUITEM_TAG] submenu] copy] autorelease]];
}

- (float)browser:(NSBrowser *)aBrowser sizeToFitWidthOfColumn:(int)aColumn
	/*" This method is an NSBrowser delegate method. It returns the ideal width 
		for a column. Implementation is for browsers with resize type 
		NSBrowserUserColumnResizing only. This method is used when performing a
		Òright-sizeÓ operation; that is, when sizing a column to the smallest 
		width that contains all the content without clipping or truncating. If 
		aColumn is Ð1, the result is used for a Òright-size-allÓ operation. In 
		that case, you should return a size that can be uniformly applied to all
		columns (that is, every column will be set to this size). It is assumed
		that the implementation may be expensive, so it will be called only when
		necessary.

		Here we get an instance of RightSizeColumn for the column number in
		aColumn from either an array if it has already been instanciated or 
		create a new one if not. This RightSizeColumn will save the previous 
		column width and calculate the right size column width. Then this method 
		will return the right size column width if this is the first time this 
		method has been called for this column. The second time this method is 
		called for this column then the previous column width is returned. The
		third time the right size column width is returned. And so on, each time
		this method alternates between returning the right size column width and
		the previous column width.

		If this column has been manually resized at any time then this method 
		will function as if it has not been called before, except that an 
		instance of RightSizeColumn will already exists. This means it starts 
		over by returning the right size column width first.
	"*/
{
	RightSizeColumn *aRightSizeColumn = nil;
	float aWidth = 0.0;
	float theRightSizeWidth = 0.0;
	float theCurrentWidth = 0.0;
	int aCount = 0;
	int aNewCount = 0;
	int anIndex = 0;
	
	// Only for the browser equal to the instance variable browser.
	if ( aBrowser != browser ) return 100.0;
	
	// The aColumn == -1 is not implemented.
	// In Panther; -1 never seems to be sent to this method.
	if ( aColumn < 0 ) return 100.0;
	
	aCount = [rightSizeArray count];
	if ( aColumn < aCount ) {
		aRightSizeColumn = [rightSizeArray objectAtIndex:aColumn];
	} else {
		aNewCount = aColumn + 1;
		anIndex = aCount;
		while ( anIndex < aNewCount ) {
			aRightSizeColumn = [[RightSizeColumn alloc] initWithBrowser:aBrowser 
															  forColumn:anIndex];
			[rightSizeArray insertObject:aRightSizeColumn atIndex:anIndex];					anIndex++;
		}
	}
	if ( [aRightSizeColumn isRightSizeWidth] == YES ) {
		// Set to previous width.
		aWidth = [aRightSizeColumn previousSizeWidth];
		[aRightSizeColumn setIsRightSizeWidth:NO];
	} else {
		// Calculate and set to right width.
		theCurrentWidth = [aRightSizeColumn calcCurrentWidth];
		[aRightSizeColumn setPreviousSizeWidth:theCurrentWidth];
		theRightSizeWidth = [aRightSizeColumn calcRightSizeWidth];
		[aRightSizeColumn setRightSizeWidth:theRightSizeWidth];
		[aRightSizeColumn setIsRightSizeWidth:YES];
		aWidth = theRightSizeWidth;
	}
	// Set a switch so that a manual column resize will result in the 
	// appropriate RightSizeColumn instance being set back to having a right
	// size of NO.
	isRightSizeColumnJustSet = YES;

	return aWidth;
}

- (void)browserColumnConfigurationDidChange:(NSNotification *)aNotification
	/*" This method is an NSBrowser delegate method. It is used by clients to 
		implement their own column width persistence. Implementation is used for 
		browsers with resize type NSBrowserUserColumnResizing only. It is called
		when the method setWidth:ofColumn: is used to change the width of any 
		browser columns or when the user resizes any columns. If the user 
		resizes more than one column, a single notification is posted when the
		user is finished resizing.

		If a column has been manually resized at any time then this method will 
		cause the method -browser:sizeToFitWidthOfColumn: to function as if it
		has not been called before for the column that has been resized. This 
		means that the method -browser:sizeToFitWidthOfColumn: will start over 
		by returning the right size column width first.
	"*/
{
	NSBrowser *aBrowser = nil;
	RightSizeColumn *aRightSizeColumn = nil;
	float theRightSizeWidth = 0.0;
	float theCurrentWidth = 0.0;
	int aCount = 0;
	int aColumn = 0;
		
	// Only for the browser equal to the instance variable browser.
	aBrowser = [aNotification object];
	if ( aBrowser != browser ) return;

	// No need to do anything if there are no RightSizeColumn instances.
	if ( isNilOrEmpty(rightSizeArray) ) return;
	// This method is always called directly after a call to the delegate method
	// -browser:sizeToFitWidthOfColumn:. So here we just return doing nothing.
	if ( isRightSizeColumnJustSet == YES ) {
		isRightSizeColumnJustSet = NO;
		return;
	}
	
	// Here we need to look at all the RightSizeColumn instances and see which 
	// one has changed. This one is changed so that the boolean isRightSizeWidth is set 
	// to NO. This will force a right size change the next time it is requested 
	// instead of going to the previous width.
	aCount = [rightSizeArray count];
	while ( aColumn < aCount ) {
		aRightSizeColumn = [rightSizeArray objectAtIndex:aColumn];
		// No need to check the ones where isRightSizeWidth is NO.
		if ( [aRightSizeColumn isRightSizeWidth] == YES ) {
			theRightSizeWidth = [aRightSizeColumn rightSizeWidth];
			theCurrentWidth = [aRightSizeColumn calcCurrentWidth];
			if ( abs((theRightSizeWidth - theCurrentWidth)) > 1.1 ) {
				// This column width has changed. Set isRightSizeWidth to NO.
				[aRightSizeColumn setIsRightSizeWidth:NO];
			}
		}
		aColumn++;
	}	
}


@end


//--------------------------------------------------------------------------------
