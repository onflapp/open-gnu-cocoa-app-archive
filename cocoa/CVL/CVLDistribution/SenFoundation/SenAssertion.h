/*$Id: SenAssertion.h,v 1.9 2004/01/29 14:40:01 william Exp $*/

// Copyright (c) 1997-2003, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the license in OpenSourceLicense.html
// found in this distribution and at http://www.sente.ch/software/ ,  where the
// original version of this source code can also be found.
// This notice may not be removed from this file.

/*" These macros raise exceptions if the condition in "x" is false.
The reason for using NSExceptions here instead of NSAsserts are so
that we have more control over when and what is outputed to the
standard error. For example the NSAssert function writes to the
standard error using its own format even if we would like to do
it ourselves.

NOT_YET_IMPLEMENTED
This macro will raise an exception whenever a method is called
and the method has not been implemented yet.

SUBCLASS_RESPONSIBILITY
Use this macro when you want to raise an exception in a method
in an abstract superclass where the method must be overridden by a subclass.
"*/

#import <Foundation/NSString.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>

#import "SenEmptiness.h"
#import "SenCheckpoint.h"

// Defines precondition, postcondition and invariant macros in addition to assert.
// Each type of condition can be blocked individually.

// FIXME: blocks would be nice...

#ifndef NS_BLOCK_ASSERTIONS
#define senassert(condition)	        NSAssert1(condition,@"Assertion failed: %s", #condition);

// senprecondition
#ifndef SEN_BLOCK_PRECONDITIONS
#define senprecondition(condition)      NSAssert1(condition,@"Broken precondition: %s", #condition);
#else
#define senprecondition(condition)
#endif

// senpostcondition
#ifndef SEN_BLOCK_POSTCONDITIONS
#define senpostcondition(condition)     NSAssert1(condition,@"Broken postcondition: %s", #condition);
#else
#define senpostcondition(condition)
#endif

// seninvariant
#ifndef SEN_BLOCK_INVARIANTS
#define seninvariant(condition)	        NSAssert1(condition,@"Broken invariant: %s", #condition);
#else
#define seninvariant(condition)
#endif


// SEN_NOT_YET_IMPLEMENTED
#define SEN_NOT_YET_IMPLEMENTED do {   \
    [NSException raise:@"SenImplementationException" format: \
    @"This method is not yet implemented. Occurred in file %s:%d in method [%@ %@].", \
        __FILE__, __LINE__, NSStringFromClass([self class]), \
        NSStringFromSelector(_cmd)]; } \
while(0)

// SEN_SUBCLASS_RESPONSIBILITY
#define SEN_SUBCLASS_RESPONSIBILITY do {   \
    [NSException raise:@"SenImplementationException" format: \
    @"This method must be overridden by a subclass. Occurred in file %s:%d in method [%@ %@].", \
        __FILE__, __LINE__, NSStringFromClass([self class]), \
        NSStringFromSelector(_cmd)]; } \
while(0)

// SEN_ASSERT_CONDITION
#define SEN_ASSERT_CONDITION(x) do { if ( (x) == NO ) {  \
    [NSException raise:@"SenAssertConditionException" format: \
    @"\"%s\" should be true but it is not! Occurred in file %s:%d in method [%@ %@].", \
#x, __FILE__, __LINE__, NSStringFromClass([self class]), \
        NSStringFromSelector(_cmd)]; } } \
while(0)

// SEN_ASSERT_CONDITION_MSG
#define SEN_ASSERT_CONDITION_MSG(x, msg) do { if ( (x) == NO ) {  \
    [NSException raise:@"SenAssertConditionException" format: \
  @"%@\n\nActual Error: \"%s\" should be true but it is not! Occurred in file %s:%d in method [%@ %@].", \
        (msg), #x, __FILE__, __LINE__, NSStringFromClass([self class]), \
        NSStringFromSelector(_cmd)]; } } \
while(0)

// SEN_ASSERT_CONDITION_OBJ
#define SEN_ASSERT_CONDITION_OBJ(x, obj) do { if ( (x) == NO ) {  \
    NSString *msg = [NSString stringWithFormat:@"anObject = (%@) <%p> Attributes: %@", \
        [obj entityName], obj, [obj userPresentableDescription]]; \
            [NSException raise:@"SenAssertConditionException" format: \
    @"\"%s\" should be true but it is not! Occurred in file %s:%d in method [%@ %@].\n%@", \
#x, __FILE__, __LINE__, NSStringFromClass([self class]), \
                NSStringFromSelector(_cmd), (msg)]; } } \
while(0)

// SEN_ASSERT_NOT_NIL
#define SEN_ASSERT_NOT_NIL(y) SEN_ASSERT_CONDITION( ((y) != nil) )

// SEN_ASSERT_NOT_EMPTY
#define SEN_ASSERT_NOT_EMPTY(y) SEN_ASSERT_CONDITION( isNotEmpty(y) )

// SEN_ASSERT_CLASS
#define SEN_ASSERT_CLASS(x,y) do { \
    if ( ((x) != nil) && ([(x) isKindOfClass:NSClassFromString(y)] == NO) ) {  \
        [NSException raise:@"SenAssertClassException" format: \
    @"\"%@\" should be of class %@ but instead it is of class %@! Occurred in file %s:%d in method [%@ %@].", \
            (x), (y), NSStringFromClass([(x) class]), \
            __FILE__, __LINE__, NSStringFromClass([self class]), \
            NSStringFromSelector(_cmd)]; } } \
while(0)

// SEN_NOT_DESIGNATED_INITIALIZER
#define SEN_NOT_DESIGNATED_INITIALIZER(x) do {  \
    [NSException raise:@"SenNotDesignatedInitializerException" format: \
@"%@ is not the designated initializer for class %@. Use %@ instead. Occurred in file %s:%d", \
        NSStringFromSelector(_cmd), NSStringFromClass([self class]),  \
        (x), __FILE__, __LINE__]; } \
while(0)

// SEN_WARNING_CONDITION
#define SEN_WARNING_CONDITION(x) do { if ( (x) == NO ) {  \
    NSLog( [NSString stringWithFormat: \
    @"Warning! \"%s\" should be true but it is not! Occurred in file %s:%d in method [%@ %@].", \
#x, __FILE__, __LINE__, NSStringFromClass([self class]), \
        NSStringFromSelector(_cmd)] ); } } \
while(0)

// SEN_LOG
#define SEN_LOG(msg) do {  \
    NSLog( [NSString stringWithFormat: \
        @"Message: %@ Occurred in file %s:%d in method [%@ %@].", \
        (msg), __FILE__, __LINE__, NSStringFromClass([self class]), \
        NSStringFromSelector(_cmd)] ); } \
while(0)

// SEN_LOG_CHECKPOINT
#define SEN_LOG_CHECKPOINT() do {  \
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"SenLogCheckpoints"] ) { \
        SenLogCheckpoint( ([NSString stringWithFormat: \
            @"Checkpoint occurred in file %s:%d in method [%@ %@].", \
            __FILE__, __LINE__, NSStringFromClass([self class]), \
            NSStringFromSelector(_cmd)]) ); } } \
while(0)


#else /* NS_BLOCK_ASSERTIONS */


#define senassert(condition)
#define senprecondition(condition)
#define senpostcondition(condition)
#define seninvariant(condition)

#define SEN_NOT_YET_IMPLEMENTED
#define SEN_SUBCLASS_RESPONSIBILITY
#define SEN_ASSERT_CONDITION(x)
#define SEN_ASSERT_CONDITION_MSG(x, msg)
#define SEN_ASSERT_CONDITION_OBJ(x, obj)
#define SEN_ASSERT_NOT_NIL(y)
#define SEN_ASSERT_NOT_EMPTY(y)
#define SEN_ASSERT_CLASS(x,y)
#define SEN_NOT_DESIGNATED_INITIALIZER(x)
#define SEN_WARNING_CONDITION(x)


#endif /* NS_BLOCK_ASSERTIONS */

#ifdef DEBUG
#define SEN_DEBUG_OUT(type,message)	NSLog (@"%@ [%@, %@] %@", (type), self, NSStringFromSelector(_cmd), (message))
#define SEN_DEBUG(message)	        SEN_DEBUG_OUT(@"Debug",(message))
#define SEN_TRACE                   SEN_DEBUG_OUT(@"Trace",@"")
#else
#define SEN_DEBUG(message)
#define SEN_TRACE
#endif



