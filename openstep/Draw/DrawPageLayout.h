@interface DrawPageLayout : NSPageLayout
{
    id leftMargin;
    id rightMargin;
    id topMargin;
    id bottomMargin;
}

/* Methods overridden from superclass */

- (void)pickedUnits:(id)sender;
- (void)readPrintInfo;
- (void)writePrintInfo;
- (void)setTopBotForm:anObject;
- (void)setSideForm:anObject;

@end


