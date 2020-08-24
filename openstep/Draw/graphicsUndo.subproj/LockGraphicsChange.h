@interface LockGraphicsChange : GraphicsChange
{
}

- (NSString *)changeName;
- (void)undoChange;
- (Class)changeDetailClass;

@end
