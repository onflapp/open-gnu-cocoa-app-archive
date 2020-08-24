
// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.


#import "WorkAreaListViewer.h"
#import "ResultsRepository.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <SenBrowserCell.h>
#import <SenFoundation/SenFoundation.h>
#import <CvsStatusRequest.h>



//-------------------------------------------------------------------------------------

@interface WorkAreaListViewer (Private)

//- (void) browserResultChanged: (NSNotification *)notification;
- (void) startUpdate;
- (void) endUpdate;

@end

//-------------------------------------------------------------------------------------

@implementation WorkAreaListViewer

+ (WorkAreaListViewer*) listViewerForPath: (NSString*) aPath
{
  WorkAreaListViewer* newViewer= [[self alloc] initForPath: aPath];

  return [newViewer autorelease];
}

- init
{
  return [self initForPath: NSHomeDirectory()];
} // init


- initForPath: (NSString*) aPath;
{
  self= [super init];
  ASSIGN(rootPath, aPath);
  return self;
} // initForPath:


- (void) dealloc
{
  RELEASE(rootPath);
  RELEASE(browser);
  [super dealloc];
} // dealloc


- (void)awakeFromNib
{
  [browser retain];  // to avoid releasing it by someone else
} // awakeFromNib


- view
{
  if (!browser)
  {
    [NSBundle loadNibNamed:@"EasyCVSListViewer" owner:self];
  }
  return browser;
}


- (NSString*) rootPath
{
  return rootPath;
}


-(NSArray *)selectedPaths
{
  NSArray *selectedCells;

  selectedCells=[browser selectedCells];

  if ([selectedCells count]) {
    NSMutableArray *result;
    NSString *path;
    id enumerator;
    NSBrowserCell *cell;

    path=[rootPath stringByAppendingPathComponent:[browser pathToColumn:[browser selectedColumn]]];
    result=[NSMutableArray array];
    enumerator=[selectedCells objectEnumerator];

    while ( (cell=[enumerator nextObject]) ) {
      [result addObject:[path stringByAppendingPathComponent:[cell stringValue]]];
    }

    return result;
  } else {
    return [NSArray arrayWithObject:rootPath];
  }
}


@end


//-------------------------------------------------------------------------------------

@implementation WorkAreaListViewer (Private)

- (void) startUpdate
{
    updateCount++;
}


- (void) endUpdate
{
  updateCount--;
}

@end

//-------------------------------------------------------------------------------------

@implementation WorkAreaListViewer (BrowserDelegate)

#if 0

#warning(120) almost same code as in BrowserController

- updateCell:aCell forName:(NSString *)aString inDir:(NSString *)aPath
{
  NSString *absolutePath;
  NSString *imageName;
  NSString *status;

  [self startUpdate];
  [resultsRepository startUpdate];
  absolutePath= [aPath stringByAppendingPathComponent:aString];

  [aCell setLoaded:YES];
  [aCell setLeaf: YES];
  [aCell setStringValue: absolutePath];
  if (![[resultsRepository dirForPath:aPath] containsObject:aString]) {
    [aCell useTemplate:(SenBrowserCell *)grayCellPrototype];
  }

  if (!(status=(NSString *)[resultsRepository resultForPath:absolutePath andKey:CVS_STATUS_KEYWORD])) {
    status=@"none";
  }
  if (!(imageName=[statusImagesDictionary objectForKey:status])) {
    imageName=[statusImagesDictionary objectForKey:@"none"];
  }
  [aCell setObjectValue:[NSImage imageNamed:imageName] atIndex:0];

  [aCell setEnabled:YES];
  [resultsRepository endUpdate];
  [self endUpdate];

  return self;
} // updateCell:forName:


- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
  [self startUpdate];
  [resultsRepository startUpdate];

  if (![cell isLoaded]) {
    NSString *fullPath;
    NSArray* contentArray;

    fullPath=[rootPath stringByAppendingPathComponent:[browser pathToColumn:column]];
    contentArray= [resultsRepository completedDirForPath:fullPath ];
    //printf("### load cell at col %d row %d, path %s\n", column, row, [fullPath cString]);
    [self updateCell:cell forName:[contentArray objectAtIndex:row] inDir:fullPath];
  }

  [resultsRepository endUpdate];
  [self endUpdate];
} //  browser:loadCell:atRow:inColumn:column


- (void)browser:(NSBrowser *)sender createRowsForColumn:(int)column inMatrix:(NSMatrix *)matrix
{
  NSString *fullPath;
  NSArray *contentArray;		
  id enumerator;
  int count= 0;
  NSString *name;

  if (![[sender cellPrototype] isKindOfClass:[SenBrowserCell class]]) {	
    // this happens when the browser display itself and before awakeFromNib is called !
    return;
  }

  [self startUpdate];
  [resultsRepository startUpdate];

  fullPath=[rootPath stringByAppendingPathComponent:[browser pathToColumn:column]];
  contentArray= [resultsRepository completedDirForPath: fullPath];
  enumerator=[contentArray objectEnumerator];
  while (name=[enumerator nextObject]) {
    [matrix addRow];
    //printf("### fill matrix col %d row %d, path %s\n", column, count, [fullPath cString]);
    [self updateCell:[matrix cellAtRow:count column:0] forName:name inDir:fullPath];
    count++;
  }
  [matrix sizeToCells];

  [resultsRepository endUpdate];
  [self endUpdate];
} // browser:fillMatrix:inColumn:
#endif

@end


//-------------------------------------------------------------------------------------
