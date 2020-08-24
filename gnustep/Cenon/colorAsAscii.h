#define COLORSTRINGLENGTH 1024

extern void convertColorToString (NSColor * color, char *str);
extern BOOL getColorFromString (const char *str, NSColor *color);

extern void writeColorToDefaults (NSColor * color, const char *defaultName);
extern BOOL readColorFromDefaults (const char *defaultName, NSColor *color);

