/*
 * vhfMath.h
 *
 * Copyright (C) 1993-2003 by vhf interservice GmbH
 * Authors:  Georg Fleischmann
 *           Martin Dietterle
 *
 * created:  1993-06-27
 * modified: 1993-07-16 2002-06-29
 *
 * This file is part of the vhf Shared Library.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the vhf Public License as
 * published by the vhf interservice GmbH. Among other things,
 * the License requires that the copyright notices and this notice
 * be preserved on all copies.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the vhf Public License for more details.
 *
 * You should have received a copy of the vhf Public License along
 * with this library; see the file LICENSE. If not, write to vhf.
 *
 * If you want to link this library to your proprietary software,
 * or for other uses which are not covered by the definitions
 * laid down in the vhf Public License, vhf also offers a proprietary
 * license scheme. See the vhf internet pages or ask for details.
 *
 * vhf interservice GmbH, Im Marxle 3, 72119 Altingen, Germany
 * eMail: info@vhf.de
 * http://www.vhf.de
 */

#ifndef VHF_H_MATH
#define VHF_H_MATH

/* purpose:   solve a polynomial up to 5th degree
 *            a*x^6 + b*x^5 + c*x^4 + d*x^3 + e*x^2 + f*x + g = 0
 * parameter: a, b, c, d, e, f, g
 *            pSolutions (array of solutions)
 * return:    number of solutions
 */
int svPolynomial2( double a, double b, double c, double *pSolutions);
int svPolynomial3( double a, double b, double c, double d, double *pSolutions);

/* purpose:   calculate extrema of a polynomial up to 6th degree
 *            a*x^6 + b*x^5 + c*x^4 + d*x^3 + e*x^2 + f*x + g = 0
 * parameter: a, b, c, d, e, f, g
 *            pSolutions (array of solutions)
 * return:    number of solutions
 */
int svExtrema2( double a, double b, double *pSolutions);
int svExtrema3( double a, double b, double c, double *pSolutions);

/* purpose:   solve an equation of 3rd degree
 * parameter: M (matrix)
 *            AIn
 *            AOut
 * return:    TRUE on success
 */
char solveEquation3(double m[3][3], double aIn[3], double aOut[3]);
char solveEquationN(double m[6][6], double aIn[6], double aOut[6], int cnt);
char solveEquationNM(double m[10][10], double *aIn, double *aOut, int yCnt, int xCnt);

#endif // VHF_H_MATH
