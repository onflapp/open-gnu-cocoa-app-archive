@interface UnlockGraphicsChange : GraphicsChange
{
}

- (NSString *)changeName;
- (void)saveBeforeChange;
- (void)redoChange;
- (Class)changeDetailClass;

@end
