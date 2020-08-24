#import "undochange.h"

@implementation MultipleChange

- (void)_setName:(NSString *) newString {
    if (!newString || ![name isEqual:newString]) {
        [name autorelease];
	name = [newString copyWithZone:(NSZone *)[self zone]];
    }
}

- (id)init
{
    [super init];
    lastChange = nil;
    changes = [[NSMutableArray alloc] init];
    name = nil;

    return self;
}

- initChangeName:(NSString *)changeName
{
    [self init];
    [self _setName:changeName];
    return self;
}

- (void)dealloc
{
    [changes removeAllObjects];
    [changes release];
    [self _setName:nil];
    
    [super dealloc];
}

- (NSString *)changeName
{
    if (name)
        return name;

    if (lastChange != nil)
	return [lastChange changeName];

    return(@"");
}

- (void)undoChange
{
    int i;

    for (i = [changes count] - 1; i >= 0; i--) {
	[[changes objectAtIndex:i] undoChange];
    }

    [super undoChange]; 
}

- (void)redoChange
{
    int i, count;

    count = [changes count];
    for (i = 0; i < count; i++) {
	[[changes objectAtIndex:i] redoChange];
    }

    [super redoChange]; 
}

- (BOOL)subsumeChange:change
{
    if (lastChange != nil) {
	return [lastChange subsumeChange:change];
    } else {
	return NO;
    }
}

- (BOOL)incorporateChange:change
{
    if (lastChange != nil && [lastChange incorporateChange:change]) {
	return YES;
    }

    [changes addObject:change];
    lastChange = change;
    return YES;
}

- (void)finishChange
{
    if (lastChange != nil) {
	[lastChange finishChange];
    } 
}

@end
