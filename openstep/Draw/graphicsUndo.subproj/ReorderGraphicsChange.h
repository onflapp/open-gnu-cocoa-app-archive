@interface ReorderGraphicsChange : GraphicsChange
{
}

- (void)saveBeforeChange;
- (Class)changeDetailClass;

@end
