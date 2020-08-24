/*

The following two functions let you convert
between a color and an ASCII string suitable
for writing to defaults or storing in text documents.

Call convertColorToString() with a color and a
string at least COLORSTRINGLENGTH long. Later
call getColorFromString() with a string obtained
from convertColorToString() and a pointer to a
color; if the function returns YES a color was
successfully parsed from the string.

 void convertColorToString (NXColor color, char *str)
 BOOL getColorFromString (const char *str, NXColor *color)

The following two functions let you read/write colors
in the defaults database of the application.

 void writeColorToDefaults (NXColor color, const char *defaultName)
 BOOL readColorFromDefaults (const char *defaultName, NXColor *color)

Written by Ali Ozer, 5/29/92.

You may freely copy, distribute and reuse the code in this example.
NeXT disclaims any warranty of any kind, expressed or implied,
as to its fitness for any particular use.

*/

#import <AppKit/AppKit.h>

#import "colorAsAscii.h"

void writeColorToDefaults (NSColor * color, const char *defaultName)
{
    char str[1024];
    convertColorToString(color, str);
#warning DefaultsConversion: [<NSUserDefaults> setObject:...forKey:...] used to be NXWriteDefault([[[NSProcessInfo processInfo] processName] cString], defaultName, str). Defaults will be synchronized within 30 seconds after this change.  For immediate synchronization, call '-synchronize'. Also note that the first argument of NXWriteDefault is now ignored; to write into a domain other than the apps default, see the NSUserDefaults API.
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:str] forKey:[NSString stringWithCString:defaultName]];
}

BOOL readColorFromDefaults (const char *defaultName, NSColor *color)
{
    const char *tmp = [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithCString:defaultName]] cString];
    return (tmp && getColorFromString (tmp, color)) ? YES : NO;
}

void convertColorToString (NSColor * color, char *str)
{
    static const char hexDigits[16] = "0123456789ABCDEF";
    NSData *colorStream = [[NSMutableData alloc] init];
#error ArchiverConversion: '[[NSUnarchiver alloc] init...]' used to be 'NXOpenTypedStream(...)'; colorStream should be converted to 'NSMutableData *'.
    NSArchiver *ts = colorStream ? [[NSArchiver alloc] initForWritingWithMutableData:colorStream] : NULL;
    
    if (ts) {
	int i, pos;
	[ts encodeObject:color];
#warning ArchiverConvesion: [ts release] was NXCloseTypedStream(ts); ts has been converted to an NSArchiver instance (was NXTypedStream); if ts was opened with NXOpenTypedStreamForFile(<filename>, NX_WRITEONLY) contents of ts must be explicitly written to <filename>; a warning will have appeared if this is the case
	[ts release];
#error StreamConversion: NXTell should be converted to an NSData method
	pos = NXTell(colorStream);
#error StreamConversion: NXSeek should be converted to an NSData method
    	NXSeek(colorStream, 0, NX_FROMSTART);
	i = 0;
	while (i++ < pos) {
#error StreamConversion: NXGetc should be converted to an NSData method
	    unsigned char ch = NXGetc(colorStream);
	    *str++ = hexDigits[(ch>>4) & 0xF];
	    *str++ = hexDigits[ch & 0xF];
        }
    }
    *str = 0;
    if (colorStream) [colorStream release];
}

#define BAD 255
#define HEX(c) (((c)>='A' && (c)<='F') ? ((c)-'A'+10): (((c)>='0'&&(c)<='9') ? ((c)-'0') : BAD))

BOOL getColorFromString (const char *str, NSColor *color)
{
    unsigned char binaryBuffer[COLORSTRINGLENGTH];
    NSData *stream;
    NSArchiver *ts;
    int len = 0;
    BOOL success = NO;
    
    while (*str) {
	unsigned char first = HEX(str[0]), second = HEX(str[1]);
	if (first == BAD || second == BAD) return NO;	
	binaryBuffer[len] = (first << 4) + second;
	str += 2;
	len++;
    }
    
    if (len &&
	(stream = [[NSData alloc] initWithBytes:binaryBuffer length:len]) &&
#error ArchiverConversion: '[[NSUnarchiver alloc] init...]' used to be 'NXOpenTypedStream(...)'; stream should be converted to 'NSData *'.
    	(ts = [[NSUnarchiver alloc] initForReadingWithData:stream])) {
	NS_DURING
#warning ColorConversion: [[ts decodeNXColor] retain] used to be NXReadColor(ts).  Use 'decodeNXColor' to read old style colors, but use 'decodeObject' to read OpenStep colors.
	    *color = [[ts decodeNXColor] retain];
	    success = YES;
	NS_HANDLER
	NS_ENDHANDLER	 
    }
#warning ArchiverConvesion: [ts release] was NXCloseTypedStream(ts); ts has been converted to an NSArchiver instance (was NXTypedStream); if ts was opened with NXOpenTypedStreamForFile(<filename>, NX_WRITEONLY) contents of ts must be explicitly written to <filename>; a warning will have appeared if this is the case
    if (ts) [ts release];
#error StreamConversion: NXCloseMemory should be converted to an NSData method
    if (stream) NXCloseMemory(stream, NX_SAVEBUFFER);

    return success;
}

