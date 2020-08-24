#import <AppKit/AppKit.h>

@interface ADSlave:NSObject
{
	id	adCtrl;
	id	tvCtrl;
	id	backCtrl;
	id	windowBuffer;
	NSString *directory;
}

- (id)init:(id)sender with:(id)controller dir:(NSString *)path;
- (void)dealloc;
- (void)cancelFullScreen;
- donext: sender;
- dostep: sender;

@end
