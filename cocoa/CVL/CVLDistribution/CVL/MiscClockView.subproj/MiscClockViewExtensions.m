// Donated by Jesse Tayler <jtayler@tmade.com>

#import "MiscClockViewExtensions.h"
#import <Foundation/NSDate.h>

@implementation MiscClockView(MiscClockViewExtensions)

- setTimeFromNSDate:(NSCalendarDate *)thedate
{
	int i;

	[self setYear:[thedate yearOfCommonEra] - 1900];
	[self setMonth:(([thedate monthOfYear]) -1)];
	[self setWeekday:[thedate dayOfWeek]];
	i = [thedate hourOfDay];
	[self setHours:i];
	[self setMinutes:[thedate minuteOfHour]];
	[self setDate:[thedate dayOfMonth]];
	return self;
}

@end

