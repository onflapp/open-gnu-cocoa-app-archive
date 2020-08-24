//
//  RestoreRetrieveController.h
//  CVL
//
//  Created by William Swats on Wed May 05 2004.
//  Copyright (c) 2004 Sente SA. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CvsVerboseStatusRequestForWorkArea;
@class CVLWaitController;
@class DateTimeController;


@interface RestoreRetrieveController : NSObject
{
    IBOutlet NSPanel        *versionPanel;
    IBOutlet NSButton       *actionButton;
    IBOutlet NSTextField    *dateTextField;
    IBOutlet NSTextField    *tagTitleTextField;
    IBOutlet NSPopUpButton  *tagTitlePopUpButton;
    IBOutlet NSMatrix		*selectionMatrix;
    NSMutableDictionary     *tagsDictionary;
	DateTimeController		*dateTimeController;

    int                     modalResult;
}

/*" Creation Methods "*/
- (id)initWithNibNamed:(NSString *)aNibName;

/*" Action Methods "*/
- (IBAction)show:(id)sender;
- (IBAction)hide:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)resultsChanged:(id)sender;
- (IBAction)tagSelectedFromPullDownButton:(id)sender;
- (IBAction)selectionMatrixChanged:(id)sender;
- (IBAction)getDateTime:(id)sender;


/*" Accessor Methods "*/
- (NSMutableDictionary *)tagsDictionary;
- (void)setTagsDictionary:(NSDictionary *)newTagsDictionary;

    /*" Other Methods "*/
- (void)updateGuiForTag:(int)aTag;


- (void) runModalWithTags;
- (void) setupModalLoop;
- (void) cleanupAfterModalLoop;

- (NSString *)tagTitleFromTextField;
- (NSString *)dateStringFromTextField;
- (BOOL)isTagTitleABranchTag:(NSString *)aTagTitle;
- (void)setDateTime:(NSCalendarDate *)aDateTime;

- (void)updateGuiWithWorkAreaTags;


@end
