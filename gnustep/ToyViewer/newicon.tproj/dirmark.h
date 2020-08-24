#include <Carbon/Carbon.h>
#include "custom.h"

#define  DM_SIZE	24
#define  DM_SIZE_L	(DM_SIZE >> 2)
#define  DM_SIZE_S	(DM_SIZE >> 3)

void attachDirMarkToThumb(fourElements *img, unsigned char *mask, int posx, int posy);
void attachDirMarkToLarge(fourElements *img, UInt32 *mask, int posx, int posy);
void attachDirMarkToSmall(fourElements *img, UInt16 *mask, int posx, int posy);
