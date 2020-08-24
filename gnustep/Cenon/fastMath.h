/*
 * fastMath.h
 *
 * Copyright 1995-2000 by vhf computer GmbH
 * Author:   Georg Fleischmann
 *
 * created:  07.12.95
 * modified: 
 *
 * you can choose between the fast and precise functions with setFast(0 or 1)
 *
 */

/* select usage of fast or precise functions
 * 1 = fast (default)
 */
void setFast(int flag);

/* call these functions as trig functions
 * these functions use degrees (DEG) instead of RAD
 * the functions allow usage of both fast and precise calculation with the setFast() function
 */

/* atan
 */
unsigned short *buildFastAtanTab(void);
double fastAtan(double v);

/* sin, cos
 */
unsigned short *buildFastSinTab(void);
double fastSin(double a);
double fastCos(double a);
