// Donated by Jesse Tayler <jtayler@tmade.com>

// Well, here are the categories I put together. They don't set the
// year, and they cause a warning that I haven't fixed but they work.

#import <misckit/MiscClockView.h>

@class NSCalendarDate;

@interface MiscClockView(MiscClockViewExtensions)

- setTimeFromNSDate:(NSCalendarDate *)thedate;

@end
