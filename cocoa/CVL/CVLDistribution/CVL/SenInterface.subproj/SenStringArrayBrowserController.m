/* SenStringArrayBrowserController.m created by ja on Thu 21-Aug-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenStringArrayBrowserController.h"
#import <AppKit/AppKit.h>
#import <SenFoundation/SenFoundation.h>

@interface SenStringArrayBrowserController (Private)
- (void) reloadContent;
@end

@implementation SenStringArrayBrowserController
- init
{
    self= [super init];
    if (self) {
        value=[[NSMutableArray alloc] init];
    }

    return self;
} // init

- (void)awakeFromNib
{
    [browser setDelegate:self];
    [browser setTarget:self];
    [browser setAction:@selector(select:)];
    [textField setTarget:self];
    [textField setAction:@selector(changeString:)];
}

- (void)dealloc
{
    RELEASE(value);
    [super dealloc];
} //free

- select: sender
{
    if (sender == browser) {
        [textField setObjectValue:[[browser selectedCell] stringValue]];
    }
    return self;
} // select:

- changeString:sender
{
    if (sender == textField) {
        int row;
        if ([browser selectedCell]) {
            row=[browser selectedRowInColumn:0];
            [value replaceObjectAtIndex:row withObject:[textField objectValue]];
        } else {
            row=[value count];
            [value addObject:[textField objectValue]];
        }
        [browser reloadColumn:0];
        [browser selectRow:row inColumn:0];
    }
    return self;
}

- (void) setStringArrayValue:(NSArray *)anArray
{
    [value setArray:anArray];
    [self reloadContent];
    [browser setNeedsDisplay: YES];
}

- (NSArray *)stringArrayValue
{
    return [NSArray arrayWithArray:value];
}

- (void) reloadContent
{
    [browser reloadColumn:0];
} // reloadContent

- (void)moveUp:(id)sender
{
    int row;
    NSString *a,*b;

    if ([browser selectedCell]) {
       row=[browser selectedRowInColumn:0];
        if (row>0) {
            a=[value objectAtIndex:row-1];
            b=[value objectAtIndex:row];
            [value replaceObjectAtIndex:row withObject:a];
            [value replaceObjectAtIndex:row-1 withObject:b];
            [browser reloadColumn:0];
            [browser selectRow:row-1 inColumn:0];
            [self select:browser];
        }
    }
}

- (void)moveDown:(id)sender
{
    int row;
    NSString *a,*b;

    if ([browser selectedCell]) {
        row=[browser selectedRowInColumn:0];
        if (row < (int)[value count]-1) {
            a=[value objectAtIndex:row];
            b=[value objectAtIndex:row+1];
            [value replaceObjectAtIndex:row+1 withObject:a];
            [value replaceObjectAtIndex:row withObject:b];
            [browser reloadColumn:0];
            [browser selectRow:row+1 inColumn:0];
            [self select:browser];
        }
    }
}

- (void)newEntry:(id)sender
{
    int row;
    if ([browser selectedCell]) {
        row=[browser selectedRowInColumn:0]+1;
    } else {
        row=[value count];
    }

    [value insertObject:@"" atIndex:row];

    [browser reloadColumn:0];
    [browser selectRow:row inColumn:0];
    [self select:browser];
}

- (void)removeEntry:(id)sender
{
    int row;
    if ([browser selectedCell]) {
        row=[browser selectedRowInColumn:0];
        [value removeObjectAtIndex:row];
        [browser reloadColumn:0];
        if (row < (int)[value count]) {
            [browser selectRow:row inColumn:0];
            [self select:browser];
        } else {
            if (row>1) {
                [browser selectRow:row-1 inColumn:0];
                [self select:browser];
            }
        }
    }
}

- (NSString *)selectedEntry
{
    return [[browser selectedCell] stringValue];
}

@end

@implementation SenStringArrayBrowserController(BrowserDelegate)
- updateCell:aCell forName:(NSString *)aString
{
    [aCell setLoaded: YES];
    [aCell setLeaf: YES];
    [aCell setStringValue:aString];
    [aCell setEnabled:YES];
    return self;
} // updateCell:forName:


- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column
{
    if (![cell isLoaded])
      {
        if (row < (int)[value count])
          {
            [self updateCell: cell forName: [value objectAtIndex: row]];
          }
      }
} //  browser:loadCell:atRow:inColumn:column

- (void)browser:(NSBrowser *)sender createRowsForColumn:(int)column inMatrix:(NSMatrix *)matrix
{
    NSString* component= nil;
    id enumerator;
    int count= 0;

    enumerator=[value objectEnumerator];
    while ( (component=[enumerator nextObject]) ) {
        [matrix addRow];
        [self updateCell:[matrix cellAtRow:count column:0] forName:component];
        count++;
    }
    [matrix sizeToCells];
} // browser:fillMatrix:inColumn:

@end

