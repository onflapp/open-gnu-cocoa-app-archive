@interface PerformTextGraphicsChange : Change
{
    TextGraphic *graphic;	/* graphic to be modified */
    Editor2DView *graphicView;	/* where the graphic is drawn */
    Change *textChange;		/* actual text change */
    NXStream *stream;		/* rtf stream */
}

- initGraphic:graphic view:graphicView;
- (NSString *)changeName;
- (void)undoChange;
- (void)redoChange;
- (BOOL)incorporateChange:change;
- (void)loadGraphic;
- (void)unloadGraphic;
- (NSText *)editText;

@end
