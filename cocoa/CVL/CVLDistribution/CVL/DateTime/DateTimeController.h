//
//  DateTimeController.h
//  CVL
//
//  Created by William Swats on 11/18/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WBCalendarControl;
@class WBTimeControl;

@interface DateTimeController : NSWindowController
{	
    IBOutlet WBCalendarControl *calendarControl;
    IBOutlet NSTextField *dateTimeTextField;
    IBOutlet NSTextField *monthTextField;
    IBOutlet NSTextField *yearTextField;
    IBOutlet WBTimeControl *timeControl;
    IBOutlet NSDrawer *dateTimeDrawer;
    NSArray * monthNameArray;
	id parentController;
}

- (void) addMonths:(int) inMonths andYears:(int) inYears;

- (IBAction)decreaseMonth:(id)sender;
- (IBAction)decreaseYear:(id)sender;
- (IBAction)increaseMonth:(id)sender;
- (IBAction)increaseYear:(id)sender;
- (IBAction)setDay:(id)sender;
- (IBAction)done:(id)sender;

- (IBAction) setValue:(id) sender;

- (NSDrawer *)dateTimeDrawer;
- (void)setDateTimeDrawer:(NSDrawer *)newDateTimeDrawer;

- (id)parentController;
- (void)setParentController:(id)newParentController;


@end
