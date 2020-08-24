/* SenMultiPageController.m created by ja on Thu 26-Feb-1998 */

// Copyright (c) 1997-2001, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "SenMultiPageController.h"
#import <SenFormPanelController.h>
#import <SenPanelFactory.h>
#import <SenFoundation/SenFoundation.h>

@interface SenMultiPageController (Private)
- (void)selectPageAtIndex:(int)anIndex;
@end

@implementation SenMultiPageController
- (id)init
{
    if ( (self=[super init]) ) {
    }
    return self;
}

- (void)dealloc
{
    RELEASE(popup);
//    [currentPageController release];
    RELEASE(pageControllers);
    [super dealloc];
}

- (void)awakeFromNib
{
    id pageEnumerator;
    SenFormPanelController *pageController;
    NSString *panelName;

    pageControllers=[[NSMutableArray alloc] init];
    pageEnumerator=[[popup itemTitles] objectEnumerator];
    while ( (panelName=[pageEnumerator nextObject]) ) {
        if ( (pageController=[[SenPanelFactory sharedPanelFactory] handleOfPanelWithName:panelName]) ) {
            [pageControllers addObject:pageController];
        }
    }
    
    [popup removeAllItems];
    pageEnumerator=[pageControllers objectEnumerator];
    while ( (pageController=[pageEnumerator nextObject]) ) {
        [popup addItemWithTitle:[[pageController panel] title]];
        [[[pageController panel] contentView] retain];
        [[[pageController panel] contentView] removeFromSuperview];
    }
    [self selectPageAtIndex:0];
}

- (void)selectPageAtIndex:(int)anIndex
{
    NSRect frame;
    NSView *superView;
    NSView *newView;

    [popup selectItemAtIndex:anIndex];
    currentPageController=[pageControllers objectAtIndex:anIndex];
    [currentPageController setupAuxiliaryController];
    newView=[[currentPageController panel] contentView];
    frame=[swappableView frame];
    superView=[swappableView superview];
    [swappableView removeFromSuperview];
    [superView addSubview:newView];
    [newView setFrame:frame];
    swappableView=newView;
    [swappableView setNeedsDisplay:YES];
}

- (void)switchPage:(id)sender
{
    [self selectPageAtIndex:[popup indexOfSelectedItem]];
}

- (void)refreshControls
{
    [[currentPageController formController] refreshControls];
}

- (void)refreshControls:(id)sender
{
    [self refreshControls];
}

- (void)takeObjectValuesFromAllControls
{
    [[currentPageController formController] takeObjectValuesFromAllControls];
}

- (void)takeObjectValuesFromAllControls:(id)sender
{
    [self takeObjectValuesFromAllControls];
}

- (NSDictionary *)dictionaryValue
{
    return [currentPageController dictionaryValue];
}

- (void)setDictionaryValue:(NSDictionary *)newValues
{
    [currentPageController setDictionaryValue:newValues];
}

- (void)addValuesFromDictionary:(NSDictionary *)aDictionary
{
    [currentPageController addValuesFromDictionary:aDictionary];
}

- (id)objectValueForKey:(NSString *)aKey
{
    return [currentPageController objectValueForKey:aKey];
}

- (void)setObjectValue:(id)newValue forKey:(NSString *)aKey
{
    [currentPageController setObjectValue:newValue forKey:aKey];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    int		version;

    self = [self init];

    version = [decoder versionForClassName:@"SenMultiPageController"];
    /*
    switch (version) {
    case 0:
        break;
    default:
        break;
    } */
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    //[super encodeWithCoder:coder];

    // Version == 1
}

@end
