@interface ResizeGraphicsChange : GraphicsChange
{
    Graphic 	*graphic;
    NSSize	oldSize;
    NSSize	newSize;
}

- initGraphicView:aGraphicView graphic:aGraphic;
- (NSString *)changeName;
- (void)saveBeforeChange;
- (Class)changeDetailClass;

@end
