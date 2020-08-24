@interface DeleteGraphicsChange : GraphicsChange
{
}

- (NSString *)changeName;
- (void)saveBeforeChange;
- (Class)changeDetailClass;

@end
