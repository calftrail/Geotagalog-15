/*
** libproj -- library of cartographic projections
**
** Copyright (c) 2003, 2006   Gerald I. Evenden
*/
static const char
LIBPROJ_ID[] = "$Id: proj_eqc.c,v 3.1 2006/01/11 01:38:18 gie Exp $";
/*
** Permission is hereby granted, free of charge, to any person obtaining
** a copy of this software and associated documentation files (the
** "Software"), to deal in the Software without restriction, including
** without limitation the rights to use, copy, modify, merge, publish,
** distribute, sublicense, and/or sell copies of the Software, and to
** permit persons to whom the Software is furnished to do so, subject to
** the following conditions:
**
** The above copyright notice and this permission notice shall be
** included in all copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
** EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
** MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
** IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
** CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
** TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
** SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
#define PROJ_PARMS__ \
	double rc;
#define PROJ_LIB__
# include	<lib_proj.h>
PROJ_HEAD(eqc, "Equidistant Cylindrical (Plate Caree)")
	"\n\tCyl, Sph\n\tlat_ts=(0)";
FORWARD(s_forward); /* spheroid */
	xy.x = P->rc * lp.lam;
	xy.y = lp.phi;
	return (xy);
}
INVERSE(s_inverse); /* spheroid */
	lp.phi = xy.y;
	lp.lam = xy.x / P->rc;
	return (lp);
}
FREEUP; if (P) free(P); }
ENTRY0(eqc)
	P->rc = proj_param(P->params, "tlat_ts").i ?
		proj_param(P->params, "rlat_ts").f :
		P->phi0;
	if ((P->rc = cos(P->rc)) <= 0.) E_ERROR(-24);
	P->inv = s_inverse;
	P->fwd = s_forward;
	P->es = 0.;
ENDENTRY(P)
/*
** $Log: proj_eqc.c,v $
** Revision 3.1  2006/01/11 01:38:18  gie
** Initial
**
*/
