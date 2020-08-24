@interface PasteGraphicsChange : GraphicsChange
{
}

- initGraphicView:aGraphicView graphics:theGraphics;
- (NSString *)changeName;
- (void)saveBeforeChange;
- (Class)changeDetailClass;

@end
