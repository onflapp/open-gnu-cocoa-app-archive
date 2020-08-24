#import <Foundation/NSObject.h>

@interface IntervalTimer:NSObject
{
	id	theLock;
	int	status;
	float	intv;
}

- (id)init;
- (void)setInterval:(float)interval;
- (void)startThread;
- (void)stopThread;
- (BOOL)check;

@end
