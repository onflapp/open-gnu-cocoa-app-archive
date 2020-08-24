#include "../getpixel.h"

#define CJPEG		"cjpeg"
#define PBM_JBIG	"pbmtojbg"
#define PNM_J2K		"jasper"
#define PAO_PNG		"pao2png"
#define PXO_GIF		"pxo2gif"
#define PXO_BMP		"pxo2bmp"
#define NEWICON		"newicon"

typedef const char *const *arglist;

FILE *openWPipe(FILE *, arglist, int *);
int ppmwrite(FILE *, const commonInfo *, unsigned char **);
int jpgwrite(FILE *, const commonInfo *, const char *, int, BOOL);
int j2kwrite(FILE *, const commonInfo *, const char *, int, float, int);
int jbigwrite(FILE *, const commonInfo *, const char *, const char *);
int pngwrite(FILE *, const commonInfo *, const char *, BOOL);
int gifwrite(FILE *, const commonInfo *, const char *, BOOL);
int bmpwrite(FILE *, const commonInfo *, const char *, unsigned char **);
const char *key_comm(const commonInfo *);

unsigned char *allocBilevelMap(const commonInfo *);
int customIconWrite(const commonInfo *cinf, unsigned char *map[],
	const char *dir, const char *target);
int customIconRemove(const char *dir, const char *target);
