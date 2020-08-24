#import "drawundo.h"

@interface GridChange(PrivateMethods)

@end

@implementation GridChange

- initGraphicView:aGraphicView
{
    [super init];
    graphicView = aGraphicView;

    return self;
}

- (NSString *)changeName
{
    return GRID_OP;
}

- (void)saveBeforeChange
{
    oldSpacing = [graphicView gridSpacing];
    oldGray = [graphicView gridGray];
    oldVisible = [graphicView gridIsVisible];
    oldEnabled = [graphicView gridIsEnabled]; 
}

- (void)undoChange
{
    newSpacing = [graphicView gridSpacing];
    newGray = [graphicView gridGray];
    newVisible = [graphicView gridIsVisible];
    newEnabled = [graphicView gridIsEnabled];

    [[self changeManager] disableChanges:self];
	[graphicView setGridSpacing:oldSpacing andGray:oldGray];
	[graphicView setGridVisible:oldVisible];
	[graphicView setGridEnabled:oldEnabled];
    [[self changeManager] enableChanges:self];
    [super undoChange]; 
}

- (void)redoChange
{
    [[self changeManager] disableChanges:self];
	[graphicView setGridSpacing:newSpacing andGray:newGray];
	[graphicView setGridVisible:newVisible];
	[graphicView setGridEnabled:newEnabled];
    [[self changeManager] enableChanges:self];
    [super redoChange]; 
}

- (BOOL)subsumeChange:change
/*
 * ChangeManager will call subsumeChange: when we are the last 
 * completed change and a new change has just begun. We override
 * the subsumeChange: because we want to consolidate multiple
 * grid changes into a single change. For example, if the user
 * selects the menu item "Show Grid" and then selects the menu
 * item "Turn Grid On", we'll only leave a single GridChange in
 * the ChangeManager's list of changes.Both changes can then be
 * be undone and redone in one action.
 */
{
    if ([change isKindOfClass:[GridChange class]]) {
        [self saveBeforeChange];
        return YES;
    } else {
        return NO;
    }
}

@end
