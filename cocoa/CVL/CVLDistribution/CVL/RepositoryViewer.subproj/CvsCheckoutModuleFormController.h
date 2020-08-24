//
//  CvsCheckoutModuleFormController.h
//  CVL
//
//  Created by William Swats on Wed Jul 30 2003.
//  Copyright (c) 2003 Sente SA. All rights reserved.
//

#import "SenFormController.h"

@class DateTimeController;


@interface CvsCheckoutModuleFormController : SenFormController
{
	DateTimeController *dateTimeController;
}

- (IBAction)resultsChanged:(id)sender;
- (IBAction)selectionMatrixChanged:(id)sender;
- (IBAction)getDateTime:(id)sender;

- (void)setDateTime:(NSCalendarDate *)aDateTime;

@end
