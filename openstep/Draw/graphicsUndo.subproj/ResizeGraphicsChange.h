@interface ResizeGraphicsChange : GraphicsChange
{
    Graphic 	*graphic;
    NSRect	oldBounds;
    NSRect	newBounds;
}

- initGraphicView:aGraphicView graphic:aGraphic;
- (NSString *)changeName;
- (void)saveBeforeChange;
- (Class)changeDetailClass;

@end
