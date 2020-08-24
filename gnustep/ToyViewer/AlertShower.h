#import  <Foundation/NSObject.h>

@class NSString, NSWindow;

@interface AlertShower: NSObject
{
	NSString	*title;
}

+ (void)setTimedAlert:(BOOL)flag;
+ (void)setSuppress:(BOOL)flag;
- (id)initWithTitle:(NSString *)str;
- (void)runAlert:(NSString *)fname :(int)err;
- (void)runAlertSheet:(NSWindow *)win doc:(NSString *)fname :(int)err;
@end


/* Global */
extern AlertShower *ErrAlert, *WarnAlert;
