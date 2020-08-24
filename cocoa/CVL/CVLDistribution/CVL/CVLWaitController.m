/* CVLWaitController.m created by stephane on Thu 21-Oct-1999 */

// Copyright (c) 1997-2000, Sen:te Ltd.  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

#import "CVLWaitController.h"
#import <AppKit/AppKit.h>


NSString	*CVLWaitConditionMetNotification = @"CVLWaitConditionMetNotification";


@interface CVLWaitController(Private)
- (void) setTarget:(id)aTarget selector:(SEL)aSelector userInfo:(NSDictionary *)aUserInfo;
- (void) setCancellable:(BOOL)canBeCancelled;
- (void) wait;
- (void) waiting;
- (void) endWait;
@end

@implementation CVLWaitController

static NSTimeInterval	_defaultGranularity = 0.1;
static NSTimeInterval	_displayThresholdDelay = 0.5;

+ (void) setGranularity:(NSTimeInterval)aGranularity
    /*" This is the set method for the class variable named _defaultGranularity. 
        The granularity specifies how often the -waiting method is called 
        (i.e. how often the progress bar is animated). The default value is one
        tenth of a second.
    "*/
{
    NSParameterAssert(aGranularity > 0.0);
    _defaultGranularity = aGranularity;
}

+ (NSTimeInterval) granularity
    /*" This is the get method for the class variable named _defaultGranularity. 
        The granularity specifies how often the -waiting method is called 
        (i.e. how often the progress bar is animated). The default value is one
        tenth of a second.
    "*/
{
    return _defaultGranularity;
}

+ (void) setDisplayThresholdDelay:(NSTimeInterval)aDelay
    /*" This is the set method for the class variable named _displayThresholdDelay. 
        The display threshold delay specifies how long to wait before displaying 
        the progress window. The default value is one half of a second.
    "*/
{
    NSParameterAssert(aDelay >= 0);
    _displayThresholdDelay = aDelay;
}

+ (NSTimeInterval) displayThresholdDelay
    /*" This is the get method for the class variable named _displayThresholdDelay. 
        The display threshold delay specifies how long to wait before displaying 
        the progress window. The default value is one half of a second.
    "*/
{
    return _displayThresholdDelay;
}

+ (CVLWaitController *) waitForConditionTarget:(id)aTarget selector:(SEL)aSelector cancellable:(BOOL)canBeCancelled userInfo:(NSDictionary *)aUserInfo
    /*" This is the method to use to create the CVL Wait Controller. The 
        arguments aTarget and aSelector are used to determine when the wait 
        should be ended. In particular aSelector is repeatedly called on aTarget
        until the returned value is non nil. While waiting a window with a
        progress bar is displayed which is animated every tenth of a second. 
        This is the default granularity. This wait window will only get 
        displayed if the condition above (i.e. the return value of aSelector is
        non nil) does not occur within a half of a second. This the default
        display threshold delay. It can be set to any non-zero value. If the
        argument canBeCancelled is set to YES then a cancel button is added to 
        the progress window. The argument aUserInfo can be used by the developer
        to pass extra data to and from the CVL Wait Controller. The CVL Wait 
        Controller is autreleased, so it should be retained by the user until no 
        longer needed.
    "*/
{
    CVLWaitController	*aController = [[self alloc] init];

    [aController setTarget:aTarget selector:aSelector userInfo:aUserInfo];
    [aController setCancellable:canBeCancelled];
    [aController wait];

    return [aController autorelease];
}

- (id) init
    /*" This method should not be called directly. It will be called by the 
        method -waitForConditionTarget:selector:cancellable:userInfo:. Use that
        method instead. This method sets the message in the progress window to
        an empty string. The repeat granularity and the display threshold delay
        values are set to this class's defaults.
    "*/
{
	if ( (self = [super init]) ) {
        waitMessage = @"";
        granularity = [[self class] granularity];
        displayThresholdDelay = [[self class] displayThresholdDelay];
        isPanelDisplayed= NO;
	}

	return self;
}

- (void) dealloc
{
    [waitMessage release];
    [target release];
    RELEASE(userInfo);
    [waitPanel release];
    [timer invalidate];
    [timer release];
    
    [super dealloc];
}

- (void) setTarget:(id)aTarget selector:(SEL)aSelector userInfo:(NSDictionary *)aUserInfo
    /*" This is the method to use to initialize the CVL Wait Controller. It is
        called by the method waitForConditionTarget:selector:cancellable:userInfo:. 
        The arguments aTarget and aSelector are used to determine when the wait 
        should be ended. In particular aSelector is repeatedly called on aTarget
        until the returned value is non nil. While waiting a window with a
        progress bar is displayed which is animated every tenth of a second. 
        This is the default granularity. This wait window will only get 
        displayed if the condition above (i.e. the return value of aSelector is
        non nil) does not occur within a half of a second. This the default
        display threshold delay. It can be set to any non-zero value. The 
        argument aUserInfo can be used by the developer
        to pass extra data to and from the CVL Wait Controller.
    "*/
{
    NSParameterAssert(aTarget != nil);
    NSParameterAssert(aSelector != NULL);
    NSParameterAssert([aTarget respondsToSelector:aSelector]);
    
    target = [aTarget retain];
    selector = aSelector;
    [self setUserInfo:aUserInfo];
}

- (void) setCancellable:(BOOL)canBeCancelled
    /*" This is the set method for the instance variable named cancellable. If 
        the argument canBeCancelled is set to NO then the cancel button is 
        removed from the progress window.
    "*/
{
    cancellable = canBeCancelled;
    if(!cancellable){
        [cancelButton removeFromSuperview];
        cancelButton = nil;
    }
}

- (NSDictionary *)userInfo
    /*" This is the get method for the instance variable named userInfo. This 
        instance variable is used to retain information pretaining to the wait 
        condition that this wait controller is representing.

        See also #{setUserInfo:}.
    "*/
{
	return userInfo;
}

- (void)setUserInfo:(NSDictionary *)newUserInfo
    /*" This is the set method for the instance variable named userInfo. This 
        instance variable is used to retain information pretaining to the wait 
        condition that this wait controller is representing.

        See also #{userInfo}.
    "*/
{
    ASSIGN(userInfo, newUserInfo);
}

- (void) displayPanelIfNeeded
    /*" This method displays the progress window if it has not already been 
        displayed and if the display threshold delay value has been exceeded. 
        Otherwise it does nothing.
    "*/
{
    BOOL isBundleLoadedSuccessfully = NO;
    
    if( (isPanelDisplayed == NO ) && (displayThresholdDelay < 0.0) ){
        isBundleLoadedSuccessfully = [NSBundle loadNibNamed:@"CVLWait" 
                                                      owner:self];
        SEN_ASSERT_CONDITION_MSG((isBundleLoadedSuccessfully), 
             ([NSString stringWithFormat:@"Unable to load nib named CVLWait"]));

        [messageTextField setStringValue:waitMessage];
        [[messageTextField cell] setWraps:YES];
        [waitPanel center];
        [waitPanel makeKeyAndOrderFront:nil];
        isPanelDisplayed = YES;
        
        SEN_ASSERT_NOT_NIL(progressIndicator);
        SEN_ASSERT_CONDITION([progressIndicator isIndeterminate]);
        SEN_ASSERT_CONDITION(([progressIndicator style] == NSProgressIndicatorBarStyle));
    }
}

- (void) wait
    /*" This method is called at the end of the method 
        -waitForConditionTarget:selector:cancellable:userInfo:. It sets up the
        timer. The timer will then make repeated calls to this instance's method 
        named -waiting. This method is only called once. If it is called more 
        than once then an exception named SenAssertConditionException is raised.
    "*/
{
    SEN_ASSERT_CONDITION_MSG((timer == nil), ([NSString stringWithFormat:
        @"-[CVLWaitController wait] has already been called once."]));

    displayThresholdDelay -= granularity;
    [self displayPanelIfNeeded];
    timer = [[NSTimer scheduledTimerWithTimeInterval:granularity target:self selector:@selector(waiting) userInfo:nil repeats:YES] retain];
}

- (void) waiting
    /*" This method is called repeatedly by the timer that was created in the 
        -wait method above. This method first checks to see if a non nil value 
        has been returned from the target and selector specified in the class 
        method -waitForConditionTarget:selector:cancellable:userInfo:. If it has
        then the method -endWait is called which stops the progress bar and 
        removes the progress window. If not then this method will animate the 
        progress bar in the progress window. Also this method makes a call to 
        -displayPanelIfNeeded to see if the progress window needs to be 
        displayed.
    "*/
{
    if([target performSelector:selector] != nil) {
        [self endWait];
        return;
    } else {
        displayThresholdDelay -= granularity;
        [self displayPanelIfNeeded];
    }
    [progressIndicator animate:self];
    [waitPanel displayIfNeeded];
}

- (void) endWait
    /*" This method stops the timer which stops the progress bar. It then
        removes the progress window. Also a CVLWaitConditionMetNotification is 
        posted.
    "*/
{
    NSNotificationCenter *theNotificationCenter = nil;
        
    [waitPanel orderOut:self];

    // It might happen that the only retainer on self is the timer, 
    // so let's retain ourself before invalidating timer...
    [self retain];
    
    [timer invalidate];
    theNotificationCenter = [NSNotificationCenter defaultCenter];
    [theNotificationCenter postNotificationName:CVLWaitConditionMetNotification
                                         object:self 
                                       userInfo:userInfo];
    [timer release];
    timer = nil;
    [self autorelease];
}

- (void) setWaitMessage:(NSString *)aMessage
    /*" This is the set method for the instance variable named waitMessage. This 
        message is displayed at the top of the progress window.
    "*/
{
    if( aMessage != nil ){
        [waitMessage autorelease];
        waitMessage = [aMessage retain];
    } else {
        waitMessage = @"";
    }
    [messageTextField setStringValue:waitMessage];
}

- (IBAction) cancelWaiting:(id)sender
    /*" This is the action method that is called by the Cancel button in the 
        progress window. The Cancel button only is displayed in the progress 
        window if the instance variable cancellable is set to YES. This method 
        calls the method -endWait which stops the progress bar and removes the 
        progress window. Also the instance variable waitCancelled is set to YES.
    "*/
{
    waitCancelled = YES;
    [self endWait];
}

- (BOOL) waitCancelled
    /*" This is the get method for the instance variable named waitCancelled. 
        This method returns YES if the user has clicked on the Cancel button in 
        the progress window, otherwise NO is returned.
    "*/
{
    return waitCancelled;
}

@end
