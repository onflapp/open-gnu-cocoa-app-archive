/*
 * Please refer to external documentation about Draw
 * with Undo for information about what SimpleGraphicsChange 
 * is and where it fits in.
 */

@interface SimpleGraphicsChange : GraphicsChange
{
}

- (void)saveBeforeChange;
- (BOOL)subsumeChange:change;

@end
