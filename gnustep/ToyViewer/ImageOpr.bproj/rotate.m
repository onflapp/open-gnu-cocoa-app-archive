#import  <objc/objc.h>
#import  <Foundation/NSString.h>
#import  <Foundation/NSBundle.h>	/* LocalizedString */
//#import  <libc.h> //Linux only
#import  <math.h>
#import  "../common.h"
#import  "../imfunc.h"
#import  "../getpixel.h"
#import  "../WaitMessageCtr.h"


static double cosine, sine;
static int xdiff, ydiff;

void rotate_size(float angle, const commonInfo *cinf, commonInfo *newinf)
{
	// angle = (int)(angle * 16.0) / 16.0;
	// ... angle should be round like this
	if (angle == 90.0 || angle == 270.0) {
		newinf->width = cinf->height;
		newinf->height = cinf->width;
	}else if (angle == 0.0 || angle == 180.0) {
		newinf->width = cinf->width;
		newinf->height = cinf->height;
	}else {
		double th = ((double)angle * 3.14159265) / 180.0;
		double co = cos(th);
		double si = sin(th);
		if (co < 0) co = -co;
		if (si < 0) si = -si;
		newinf->width = cinf->width * co + cinf->height * si + 0.5;
		newinf->height = cinf->width * si + cinf->height * co + 0.5;
		if (angle > 270.0) {
			xdiff = cinf->height * si - 0.5;
			ydiff = 0.0;
		}else if (angle > 180.0) {
			xdiff = newinf->width - 1;
			ydiff = cinf->height * co - 0.5;
		}else if (angle > 90.0) {
			xdiff = cinf->width * co - 0.5;
			ydiff = newinf->height - 1;
		}else {
			xdiff = 0.0;
			ydiff = cinf->width * si - 0.5;
		}
		cosine = cos(th);
		sine = sin(th);
	}
}


int sub_rotate(int op, float angle, const commonInfo *cinf, commonInfo *newinf,
		int idx[], unsigned char **working)
{
	int	x, y;
	int	i, pidx, ptr;
	int	pix[MAXPLANE];

	if (op == Horizontal) {
		for (y = 0; y < newinf->height; y++) {
			ptr = y * newinf->width;
			for (x = newinf->width - 1; x >= 0; x--) {
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}
		}
	}else if (op == Vertical) {
		for (y = newinf->height - 1; y >= 0; y--) {
			ptr = y * newinf->width;
			for (x = 0; x < newinf->width; x++) {
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}
		}
	}else if (angle == 90.0) {
		for (x = 0; x < newinf->width; x++) {
			for (y = newinf->height - 1; y >= 0; y--) {
				ptr = y * newinf->width;
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}
		}
	}else if (angle == 270.0) {
		for (x = newinf->width - 1; x >= 0; x--) {
			for (y = 0; y < newinf->height; y++) {
				ptr = y * newinf->width;
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}
		}
	}else if (angle == 180.0) {
		for (y = newinf->height - 1; y >= 0; y--) {
			ptr = y * newinf->width;
			for (x = newinf->width - 1; x >= 0; x--) {
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					working[pidx][ptr + x] = pix[i];
				}
			}
		}
	}else /* any */ {
		unsigned char *tmp[MAXPLANE];
		int pl = cinf->numcolors;
		if (newinf->alpha) pl++;
		if (allocImage(tmp, cinf->width, cinf->height, 8, pl))
			return Err_MEMORY;
		[theWaitMsg messageDisplay:
			NSLocalizedString(@"Rotating...", Rotating)];
		for (y = 0; y < cinf->height; y++) {
			ptr = y * cinf->width;
			for (x = 0; x < cinf->width; x++) {
				getPixelA(pix);
				for (i = 0; i <= ALPHA; i++) {
					if ((pidx = idx[i]) < 0) continue;
					tmp[pidx][ptr + x] = pix[i];
				}
			}
		}
		[theWaitMsg setProgress:(newinf->height - 1)];
		if (op == SmoothRotation) {
		    for (y = 0; y < newinf->height; y++) {
			int yy, ox, oy, pty;
			double dx, dy, rx, ry;
			int val[MAXPLANE];

			[theWaitMsg progress: y];
			yy = y - ydiff;
			ptr = y * newinf->width;
			for (x = 0; x < newinf->width; x++) {
			    for (i = 0; i < pl; i++)
				val[i] = 0;
			    for (rx = 0.0; rx < 1.0; rx += 0.5) {
				dx = x - xdiff + rx;
				for (ry = 0.0; ry < 1.0; ry += 0.5) {
				    dy = yy + ry;
				    ox = dx * cosine - dy * sine + 0.5;
				    oy = dx * sine + dy * cosine + 0.5;
				    if (ox < 0 || ox >= cinf->width
					|| oy < 0 || oy >= cinf->height) {
					for (i = 0; i < pl; i++)
					    val[i] += 255;
				    }else {
					pty = oy * cinf->width + ox;
					for (i = 0; i < pl; i++)
					    val[i] += tmp[i][pty];
				    }
				}
			    }
			    for (i = 0; i < pl; i++)
				working[i][ptr + x] = val[i] / 4;
			}
		    }
		}else {
		    for (y = 0; y < newinf->height; y++) {
			int dx, dy, ox, oy, pty;

			[theWaitMsg progress: y];
			dy = y - ydiff;
			ptr = y * newinf->width;
			for (x = 0; x < newinf->width; x++) {
				dx = x - xdiff;
				ox = dx * cosine - dy * sine + 0.5;
				oy = dx * sine + dy * cosine + 0.5;
				if (ox < 0 || ox >= cinf->width
				 || oy < 0 || oy >= cinf->height) {
				    for (i = 0; i < pl; i++)
					working[i][ptr + x] = 0;
				}else {
				    pty = oy * cinf->width + ox;
				    for (i = 0; i < pl; i++)
					working[i][ptr + x] = tmp[i][pty];
				}
			}
		    }
		}
		free((void *)tmp[0]);
		[theWaitMsg resetProgress];
		[theWaitMsg messageDisplay:nil];
	}
	return 0;
}
