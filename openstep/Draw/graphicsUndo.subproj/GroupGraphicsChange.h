@interface GroupGraphicsChange : GraphicsChange
{
    id		group;
}

- (NSString *)changeName;
- (void)saveBeforeChange;
- (Class)changeDetailClass;
- (void)noteGroup:aGroup;

@end
