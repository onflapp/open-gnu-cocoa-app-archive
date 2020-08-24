/* VLDiffInspector.m created by vincent on Mon 08-Dec-1997 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "VLDiffInspector.h"

#import <ResultsRepository.h>
#import <Foundation/Foundation.h>
#import "CVLFile.h"

@implementation VLDiffInspector

+ (void) initialize
{
    [super initialize];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"3", @"DiffContext", nil]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"0", @"DiffOutputFormat", nil]];
}

- (void) updateDiffParameters
{
    int	outputFormat = [[NSUserDefaults standardUserDefaults] integerForKey:@"DiffOutputFormat"];

    if(outputFormat == 0){
        [contextFormCell setIntValue:0];
        [contextFormCell setEnabled:NO];
    }
    else{
        [contextFormCell setEnabled:YES];
        [contextFormCell setIntValue:[[NSUserDefaults standardUserDefaults] integerForKey:@"DiffContext"]];
    }
    [outputFormatPopup selectItemAtIndex:outputFormat];
}

- (id) init
{
    static float LargeNumberForText= 1.0e7; // most code below comes from TextSizing Dev Example
    NSTextView* diffView= nil;
    NSTextContainer* diffContainer= nil;

    self= [super init];
    diffView= [diffScrollView documentView];
    diffContainer= [diffView textContainer];

   // [diffScrollView setHasHorizontalScroller:YES];
    [diffScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    [diffContainer setWidthTracksTextView:NO];
    [diffContainer setHeightTracksTextView:NO];
    [diffContainer setContainerSize: NSMakeSize(LargeNumberForText, LargeNumberForText)];

    [diffView setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
    [diffView setHorizontallyResizable:YES];
    [diffView setVerticallyResizable:YES];
    [diffView setAutoresizingMask:NSViewNotSizable];
    [diffView setSelectable:YES];

    [self updateDiffParameters];

    return self;
}


- (void) update
{
    NSString* element= [[self inspected] objectAtIndex: 0];
    NSString* newDiff;

    [self updateDiffParameters];
    newDiff= [(CVLFile *)[CVLFile treeAtPath:element] differencesWithContext:[contextFormCell intValue] outputFormat:[outputFormatPopup indexOfSelectedItem]];
    if ([newDiff isKindOfClass: [NSString class]] && [newDiff length])
      {
        [diffScrollView setHasHorizontalScroller: YES];
      }
    else
      {
        newDiff = @"";
        [diffScrollView setHasHorizontalScroller: NO];
      }

    [[diffScrollView documentView] setString:[[newDiff copy] autorelease]];
    
        // [diffScrollView setNeedsDisplay: YES];
    [diffScrollView display];
}

- (IBAction) setOutputFormat:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[outputFormatPopup indexOfSelectedItem] forKey:@"DiffOutputFormat"];
    [self update];
}

- (IBAction) setContextLineNumber:(id)sender
{
    NSNumber	*newValue = [contextFormCell objectValue];

    if(newValue)
        [[NSUserDefaults standardUserDefaults] setInteger:[newValue intValue] forKey:@"DiffContext"];
    else
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DiffContext"];
    [self update];
}

@end
