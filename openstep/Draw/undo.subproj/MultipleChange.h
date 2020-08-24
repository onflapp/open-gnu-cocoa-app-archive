@interface MultipleChange : Change
{
    Change *lastChange;		/* the last incorporated change */
    NSMutableArray *changes;		/* the list of incorporated changes */
    NSString *name;		/* the change name to put in the undo menu */
}

- (id)init;
- initChangeName:(NSString *)changeName;
- (NSString *)changeName;
- (void)undoChange;
- (void)redoChange;
- (BOOL)subsumeChange:change;
- (BOOL)incorporateChange:change;
- (void)finishChange;

@end
