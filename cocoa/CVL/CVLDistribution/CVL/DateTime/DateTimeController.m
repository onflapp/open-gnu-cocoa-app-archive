//
//  DateTimeController.m
//  CVL
//
//  Created by William Swats on 11/18/2004.
//  Copyright 2004 Sente SA. All rights reserved.
//

/*" This class is used to present the user with a GUI to enter a date and time 
	via of a NSDrawer. We are using a drawer instead of a panel so that it can
	be used with modal windows. Otherwise even though a panel can accept key 
	events while a modal window is up, the panel is in a lower level class of
	windows. Hence is will be behind the modal window. This can lead to a 
	situation where the panel is hidden behind the modal window and it will
	appear to the user that nothing has happen when clicking on a button that is
	suppose to activate this panel.
"*/


#import "DateTimeController.h"
#import "WBCalendarControl.h"
#import "WBTimeControl.h"

/*" Informal protocol for parent controllers of the DateTimeController.
"*/
@interface NSObject (DateTimeParentController)

- (void)setDateTime:(NSCalendarDate *)aDateTime;

@end


@implementation DateTimeController

- (void) awakeFromNib
	/*" Here we are setting up the ...
	"*/
{
    NSUserDefaults * defaults;
	NSCalendarDate * aCalendarDate;

	// Set window so that it is able to receive keyboard and mouse events even 
	// when some other window is being run modally
	[(NSPanel *)[self window] setWorksWhenModal:YES];
	
    defaults=[NSUserDefaults standardUserDefaults];
    monthNameArray=[[defaults arrayForKey:NSMonthNameArray] retain];
    aCalendarDate=[NSCalendarDate calendarDate];
    
    [yearTextField setStringValue:[NSString stringWithFormat:@"%d",[aCalendarDate yearOfCommonEra]]];
    [monthTextField setStringValue:[monthNameArray objectAtIndex:[aCalendarDate monthOfYear]-1]];
	[calendarControl setDate:aCalendarDate];
    [dateTimeTextField setStringValue:[aCalendarDate description]];
	
	// Setup for time.
	[timeControl setDelegate:self];
    [timeControl setEnabled:YES];
	[timeControl setDate:aCalendarDate]; // Synchronize
}

- (void) addMonths:(int) inMonths andYears:(int) inYears
{
	NSCalendarDate * aCalendarDate;

	aCalendarDate = [calendarControl date];
    aCalendarDate = [aCalendarDate dateByAddingYears:inYears
											  months:inMonths 
												days:0 
											   hours:0
											 minutes:0 
											 seconds:0];
    
    [yearTextField setStringValue:[NSString stringWithFormat:@"%d",[aCalendarDate yearOfCommonEra]]];
    [monthTextField setStringValue:[monthNameArray objectAtIndex:[aCalendarDate monthOfYear]-1]];
    
    [calendarControl setDate:aCalendarDate];
	[timeControl setDate:aCalendarDate]; // Synchronize

    [dateTimeTextField setStringValue:[aCalendarDate description]];
}

- (IBAction)decreaseMonth:(id)sender
{
    int addYear=0;
    int addMonth=-1;
    
    if ([[calendarControl date] monthOfYear]==1) {
        addMonth=11;
        addYear=-1;
    }
    [self addMonths:addMonth andYears:addYear];
}

- (IBAction)decreaseYear:(id)sender
{
    int addYear=-1;
    int addMonth=0;
    
    [self addMonths:addMonth andYears:addYear];
}

- (IBAction)increaseMonth:(id)sender
{
    int addYear=0;
    int addMonth=1;
    
    if ([[calendarControl date] monthOfYear]==12) {
        addMonth=-11;
        addYear=1;
    }
    [self addMonths:addMonth andYears:addYear];
}

- (IBAction)increaseYear:(id)sender
{
    int addYear=1;
    int addMonth=0;
    
    [self addMonths:addMonth andYears:addYear];
}

- (IBAction)setDay:(id)sender
{    
    [dateTimeTextField setStringValue:[[calendarControl date] description]];
	[timeControl setDate:[calendarControl date]]; // Synchronize
}

- (IBAction)done:(id)sender
{
	SEN_ASSERT_NOT_NIL(parentController);
	
	[parentController setDateTime:[calendarControl date]];
	[dateTimeDrawer close];
}

- (NSDrawer *)dateTimeDrawer
{
    return dateTimeDrawer; 
}

- (void)setDateTimeDrawer:(NSDrawer *)newDateTimeDrawer
{
    if (dateTimeDrawer != newDateTimeDrawer) {
        [newDateTimeDrawer retain];
        [dateTimeDrawer release];
        dateTimeDrawer = newDateTimeDrawer;
    }
}


- (id)parentController
{
    return parentController; 
}

- (void)setParentController:(id)newParentController
{
    if (parentController != newParentController) {
        [newParentController retain];
        [parentController release];
        parentController = newParentController;
    }
}

// Time control below

- (IBAction) setValue:(id) sender
{
    switch([timeControl selected]) {
        case 0:
            [timeControl setHour:[sender intValue]];
            break;
        case 1:
            [timeControl setMinute:[sender intValue]];
            break;
        case 2:
            [timeControl setSecond:[sender intValue]];
            break;
    }
    [calendarControl setDate:[timeControl date]]; // Synchronize
    [dateTimeTextField setStringValue:[[timeControl date] description]];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    // Clock value potentially changed
    
    [dateTimeTextField setStringValue:[[timeControl date] description]];
	[calendarControl setDate:[timeControl date]]; // Synchronize
}

@end
