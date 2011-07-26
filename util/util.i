
%module(package="astrometry.util") util

%include <typemaps.i>


%{
// numpy.
#include <numpy/arrayobject.h>

#include "log.h"
#include "healpix.h"
#include "healpix-utils.h"
#include "anwcs.h"
#include "sip.h"
#include "fitsioutils.h"
#include "sip-utils.h"
#include "sip_qfits.h"

#include "index.h"
#include "quadfile.h"
#include "codekd.h"
#include "starkd.h"
#include "starutil.h"
	//#include "qidxfile.h"

#define true 1
#define false 0


// For sip.h
static void checkorder(int i, int j) {
	assert(i >= 0);
	assert(i < SIP_MAXORDER);
	assert(j >= 0);
	assert(j < SIP_MAXORDER);
}


%}

%init %{
	  // numpy
	  import_array();
%}

// Things in keywords.h (used by healpix.h)
#define Const
#define WarnUnusedResult
#define InlineDeclare
#define Flatten
#define ASTROMETRY_KEYWORDS_H
#define ATTRIB_FORMAT(x,y,z)

void log_init(int level);
int log_get_level();
void log_set_level(int lvl);

// for quadfile_get_stars(quadfile* qf, int quadid, unsigned int* stars)
// --> list of stars
// swap the int* neighbours arg for tempneigh
%typemap(in, numinputs=0) unsigned int *stars (unsigned int tempstars[DQMAX]) {
	$1 = tempstars;
}
// in the argout typemap we don't know about the swap (but that's ok)
%typemap(argout) (const quadfile* qf, unsigned int quadid, unsigned int *stars) {
  int i;
  int D;
  if (result == -1) {
	  goto fail;
  }
  D = $1->dimquads;
  $result = PyList_New(D);
  for (i = 0; i < D; i++) {
	  PyObject *o = PyInt_FromLong($3[i]);
	  PyList_SetItem($result, i, o);
  }
}


/**
 double* startree_get_data_column(startree_t* s, const char* colname, const int* indices, int N);
 -> list of doubles.
 -> ASSUME indices = None
 */
%typemap(argout) (startree_t* s, const char* colname, const int* indices, int N) {
	int i;
	int N;
	if (!result) {
		goto fail;
	}
	N = $4;
	$result = PyList_New(N);
	for (i = 0; i < N; i++) {
		PyObject *o = PyFloat_FromDouble(result[i]);
		PyList_SetItem($result, i, o);
	}
	free(result);
}


%include "index.h"
%include "quadfile.h"
%include "codekd.h"
%include "starkd.h"
 //%include "qidxfile.h"

%apply double *OUTPUT { double *dx, double *dy };
%apply double *OUTPUT { double *ra, double *dec };

// for int healpix_get_neighbours(int hp, int* neigh, int nside)
// --> list of neigh
// swap the int* neighbours arg for tempneigh
%typemap(in, numinputs=0) int *neighbours (int tempneigh[8]) {
	$1 = tempneigh;
}
// in the argout typemap we don't know about the swap (but that's ok)
%typemap(argout) int *neighbours {
  int i;
  int nn;
  // convert $result to nn
  //nn = (int)PyInt_AsLong($result);
  nn = result;
  $result = PyList_New(nn);
  for (i = 0; i < nn; i++) {
	  PyObject *o = PyInt_FromLong($1[i]);
	  PyList_SetItem($result, i, o);
  }
}


// for il* healpix_rangesearch_radec(ra, dec, double, int nside, il* hps);
// --> list
// swallow the int* hps arg
%typemap(in, numinputs=0) il* hps {
	$1 = NULL;
}
%typemap(out) il* {
  int i;
  int N;
  N = il_size($1);
  $result = PyList_New(N);
  for (i = 0; i < N; i++) {
	  PyObject *o = PyInt_FromLong(il_get($1, i));
	  PyList_SetItem($result, i, o);
  }
}

%include "healpix.h"
%include "healpix-utils.h"


// anwcs_get_radec_center_and_radius
%apply double *OUTPUT { double *p_ra, double *p_dec, double *p_radius };

// anwcs_get_radec_bounds
%apply double *OUTPUT { double* pramin, double* pramax, double* pdecmin, double* pdecmax };

%apply double *OUTPUT { double *p_x, double *p_y, double *p_z };
%apply double *OUTPUT { double *p_ra, double *p_dec };
//%apply double *OUTPUT { double *xyz };

// eg anwcs_radec2pixelxy
%apply double *OUTPUT { double *p_x, double *p_y };

// anwcs_pixelxy2xyz
%typemap(in, numinputs=0) double* p_xyz (double tempxyz[3]) {
	$1 = tempxyz;
}
// in the argout typemap we don't know about the swap (but that's ok)
%typemap(argout) double* p_xyz {
  $result = Py_BuildValue("(ddd)", $1[0], $1[1], $1[2]);
}

%include "anwcs.h"

%include "starutil.h"

%typemap(in) double [ANY] (double temp[$1_dim0]) {
  int i;
  if (!PySequence_Check($input)) {
	PyErr_SetString(PyExc_ValueError,"Expected a sequence");
	return NULL;
  }
  if (PySequence_Length($input) != $1_dim0) {
	PyErr_SetString(PyExc_ValueError,"Size mismatch. Expected $1_dim0 elements");
	return NULL;
  }
  for (i = 0; i < $1_dim0; i++) {
	PyObject *o = PySequence_GetItem($input,i);
	if (PyNumber_Check(o)) {
	  temp[i] = PyFloat_AsDouble(o);
	} else {
	  PyErr_SetString(PyExc_ValueError,"Sequence elements must be numbers");	  
	  return NULL;
	}
  }
  $1 = temp;
}
%typemap(out) double [ANY] {
  int i;
  $result = PyList_New($1_dim0);
  for (i = 0; i < $1_dim0; i++) {
	PyObject *o = PyFloat_FromDouble($1[i]);
	PyList_SetItem($result,i,o);
  }
}

%typemap(in) double flatmatrix[ANY][ANY] (double temp[$1_dim0][$1_dim1]) {
	int i;
	if (!PySequence_Check($input)) {
		PyErr_SetString(PyExc_ValueError,"Expected a sequence");
		return NULL;
	}
	if (PySequence_Length($input) != ($1_dim0 * $1_dim1)) {
		PyErr_SetString(PyExc_ValueError,"Size mismatch. Expected $1_dim0*$1_dim1 elements");
		return NULL;
	}
	for (i = 0; i < ($1_dim0*$1_dim1); i++) {
		PyObject *o = PySequence_GetItem($input,i);
		if (PyNumber_Check(o)) {
			// FIXME -- is it dim0 or dim1?
			temp[i / $1_dim0][i % $1_dim0] = PyFloat_AsDouble(o);
		} else {
			PyErr_SetString(PyExc_ValueError,"Sequence elements must be numbers");		
			return NULL;
		}
	}
	$1 = temp;
}
%typemap(out) double flatmatrix[ANY][ANY] {
  int i;
  $result = PyList_New($1_dim0 * $1_dim1);
  for (i = 0; i < ($1_dim0)*($1_dim1); i++) {
	  // FIXME -- dim0 or dim1?
	  PyObject *o = PyFloat_FromDouble($1[i / $1_dim0][i % $1_dim0]);
	  PyList_SetItem($result,i,o);
  }
 }


%apply double [ANY] { double crval[2] };
%apply double [ANY] { double crpix[2] };
%apply double flatmatrix[ANY][ANY] { double cd[2][2] };

%include "sip.h"
%include "sip_qfits.h"

%extend sip_t {
	sip_t(char* fn=NULL, int ext=0) {
		if (fn)
			return sip_read_header_file_ext(fn, ext, NULL);
		sip_t* t = (sip_t*)calloc(1, sizeof(sip_t));
		return t;
	}

	// copy constructor
	sip_t(const sip_t* other) {
		sip_t* t = (sip_t*)calloc(1, sizeof(sip_t));
		memcpy(t, other, sizeof(sip_t));
		return t;
	}

	sip_t(const tan_t* other) {
		sip_t* t = (sip_t*)calloc(1, sizeof(sip_t));
		memcpy(&(t->wcstan), other, sizeof(tan_t));
		return t;
	}

	~sip_t() { free($self); }

	double pixel_scale() { return sip_pixel_scale($self); }

	int write_to(const char* filename) {
		return sip_write_to_file($self, filename);
	}

	int ensure_inverse_polynomials() {
		return sip_ensure_inverse_polynomials($self);
	}

	void pixelxy2xyz(double x, double y, double *p_x, double *p_y, double *p_z) {
		double xyz[3];
		sip_pixelxy2xyzarr($self, x, y, xyz);
		*p_x = xyz[0];
		*p_y = xyz[1];
		*p_z = xyz[2];
	}
	void pixelxy2radec(double x, double y, double *p_ra, double *p_dec) {
		sip_pixelxy2radec($self, x, y, p_ra, p_dec);
	}
	int radec2pixelxy(double ra, double dec, double *p_x, double *p_y) {
		return sip_radec2pixelxy($self, ra, dec, p_x, p_y);
	}
	int xyz2pixelxy(double x, double y, double z, double *p_x, double *p_y) {
		double xyz[3];
		xyz[0] = x;
		xyz[1] = y;
		xyz[2] = z;
		return sip_xyzarr2pixelxy($self, xyz, p_x, p_y);
	}

	void set_a_term(int i, int j, double val) {
		checkorder(i, j);
		$self->a[i][j] = val;
	}
	void set_b_term(int i, int j, double val) {
		checkorder(i, j);
		$self->b[i][j] = val;
	}
	void set_ap_term(int i, int j, double val) {
		checkorder(i, j);
		$self->ap[i][j] = val;
	}
	void set_bp_term(int i, int j, double val) {
		checkorder(i, j);
		$self->bp[i][j] = val;
	}

	double get_a_term(int i, int j) {
		checkorder(i, j);
		return $self->a[i][j];
	}
	double get_b_term(int i, int j) {
		checkorder(i, j);
		return $self->b[i][j];
	}
	double get_ap_term(int i, int j) {
		checkorder(i, j);
		return $self->ap[i][j];
	}
	double get_bp_term(int i, int j) {
		checkorder(i, j);
		return $self->bp[i][j];
	}

	double get_width() {
		return $self->wcstan.imagew;
	}
	double get_height() {
		return $self->wcstan.imageh;
	}
	void get_distortion(double x, double y, double *p_x, double *p_y) {
		return sip_pixel_distortion($self, x, y, p_x, p_y);
	}

	int write_to(const char* filename) {
		return sip_write_to_file($self, filename);
	}


 }
%pythoncode %{

def sip_t_tostring(self):
	tan = self.wcstan
	return (('Sip: crpix (%.1f, %.1f), crval (%g, %g), cd (%g, %g, %g, %g), '
			 + 'image %g x %g; SIP orders A=%i, B=%i, AP=%i, BP=%i') %
			(tan.crpix[0], tan.crpix[1], tan.crval[0], tan.crval[1],
			 tan.cd[0], tan.cd[1], tan.cd[2], tan.cd[3],
			 tan.imagew, tan.imageh, self.a_order, self.b_order,
			 self.ap_order, self.bp_order))
sip_t.__str__ = sip_t_tostring

Sip = sip_t
	%}

%extend tan_t {
	tan_t(char* fn=NULL, int ext=0) {
		if (fn)
			return tan_read_header_file_ext(fn, ext, NULL);
		tan_t* t = (tan_t*)calloc(1, sizeof(tan_t));
		return t;
	}
	tan_t(double crval1, double crval2, double crpix1, double crpix2,
		  double cd11, double cd12, double cd21, double cd22,
		  double imagew, double imageh) {
		tan_t* t = (tan_t*)calloc(1, sizeof(tan_t));
		t->crval[0] = crval1;
		t->crval[1] = crval2;
		t->crpix[0] = crpix1;
		t->crpix[1] = crpix2;
		t->cd[0][0] = cd11;
		t->cd[0][1] = cd12;
		t->cd[1][0] = cd21;
		t->cd[1][1] = cd22;
		t->imagew = imagew;
		t->imageh = imageh;
		return t;
	}
	tan_t(const tan_t* other) {
		tan_t* t = (tan_t*)calloc(1, sizeof(tan_t));
		memcpy(t, other, sizeof(tan_t));
		return t;
	}

	~tan_t() { free($self); }
	void set(double crval1, double crval2,
		  double crpix1, double crpix2,
		  double cd11, double cd12, double cd21, double cd22,
		  double imagew, double imageh) {
		$self->crval[0] = crval1;
		$self->crval[1] = crval2;
		$self->crpix[0] = crpix1;
		$self->crpix[1] = crpix2;
		$self->cd[0][0] = cd11;
		$self->cd[0][1] = cd12;
		$self->cd[1][0] = cd21;
		$self->cd[1][1] = cd22;
		$self->imagew = imagew;
		$self->imageh = imageh;
	}
	double pixel_scale() { return tan_pixel_scale($self); }
	void radec_center(double *p_ra, double *p_dec) {
		tan_get_radec_center($self, p_ra, p_dec);
	}
	double radius() {
		return tan_get_radius_deg($self);
	}
	void xyzcenter(double *p_x, double *p_y, double *p_z) {
		double xyz[3];
		tan_pixelxy2xyzarr($self, 0.5+$self->imagew/2.0, 0.5+$self->imageh/2.0, xyz);
		*p_x = xyz[0];
		*p_y = xyz[1];
		*p_z = xyz[2];
	}
	void pixelxy2xyz(double x, double y, double *p_x, double *p_y, double *p_z) {
		double xyz[3];
		tan_pixelxy2xyzarr($self, x, y, xyz);
		*p_x = xyz[0];
		*p_y = xyz[1];
		*p_z = xyz[2];
	}
	void pixelxy2radec(double x, double y, double *p_ra, double *p_dec) {
		tan_pixelxy2radec($self, x, y, p_ra, p_dec);
	}
	int radec2pixelxy(double ra, double dec, double *p_x, double *p_y) {
		return tan_radec2pixelxy($self, ra, dec, p_x, p_y);
	}
	int xyz2pixelxy(double x, double y, double z, double *p_x, double *p_y) {
		double xyz[3];
		xyz[0] = x;
		xyz[1] = y;
		xyz[2] = z;
		return tan_xyzarr2pixelxy($self, xyz, p_x, p_y);
	}
	int write_to(const char* filename) {
		return tan_write_to_file($self, filename);
	}
	void set_crval(double ra, double dec) {
		$self->crval[0] = ra;
		$self->crval[1] = dec;
	}
	void set_crpix(double x, double y) {
		$self->crpix[0] = x;
		$self->crpix[1] = y;
	}
	void set_cd(double cd11, double cd12, double cd21, double cd22) {
		$self->cd[0][0] = cd11;
		$self->cd[0][1] = cd12;
		$self->cd[1][0] = cd21;
		$self->cd[1][1] = cd22;
	}
	void set_imagesize(double w, double h) {
		$self->imagew = w;
		$self->imageh = h;
	}


 };


%inline %{

	static int tan_numpy_pixelxy2radec(tan_t* tan, PyObject* npx, PyObject* npy, 
									   PyObject* npra, PyObject* npdec, int reverse) {
										
		int i, N;
		double *x, *y, *ra, *dec;
		
		if (PyArray_NDIM(npx) != 1) {
			PyErr_SetString(PyExc_ValueError, "arrays must be one-dimensional");
			return -1;
		}
		if (PyArray_TYPE(npx) != PyArray_DOUBLE) {
			PyErr_SetString(PyExc_ValueError, "array must contain doubles");
			return -1;
		}
		N = PyArray_DIM(npx, 0);
		if ((PyArray_DIM(npy, 0) != N) ||
			(PyArray_DIM(npra, 0) != N) ||
			(PyArray_DIM(npdec, 0) != N)) {
			PyErr_SetString(PyExc_ValueError, "arrays must be the same size");
			return -1;
		}
		x = PyArray_GETPTR1(npx, 0);
		y = PyArray_GETPTR1(npy, 0);
		ra = PyArray_GETPTR1(npra, 0);
		dec = PyArray_GETPTR1(npdec, 0);
		if (!reverse) {
				for (i=0; i<N; i++)
					tan_pixelxy2radec(tan, x[i], y[i], ra+i, dec+i);
		} else {
				for (i=0; i<N; i++)
				   if (!tan_radec2pixelxy(tan, ra[i], dec[i], x+i, y+i)) {
				   x[i] = HUGE_VAL;
				   y[i] = HUGE_VAL;
				   }
		}
		return 0;
	}

	static int tan_numpy_xyz2pixelxy(tan_t* tan, PyObject* npxyz,
		   PyObject* npx, PyObject* npy) {
		int i, N;
		double *x, *y;
		
		if (PyArray_NDIM(npx) != 1) {
			PyErr_SetString(PyExc_ValueError, "arrays must be one-dimensional");
			return -1;
		}
		if (PyArray_TYPE(npx) != PyArray_DOUBLE) {
			PyErr_SetString(PyExc_ValueError, "array must contain doubles");
			return -1;
		}
		N = PyArray_DIM(npx, 0);
		if ((PyArray_DIM(npy, 0) != N) ||
			(PyArray_DIM(npxyz, 0) != N) ||
			(PyArray_DIM(npxyz, 1) != 3)) {
			PyErr_SetString(PyExc_ValueError, "arrays must be the same size");
			return -1;
		}
		x = PyArray_GETPTR1(npx, 0);
		y = PyArray_GETPTR1(npy, 0);
		for (i=0; i<N; i++) {
			double xyz[3];
			xyz[0] = *((double*)PyArray_GETPTR2(npxyz, i, 0));
			xyz[1] = *((double*)PyArray_GETPTR2(npxyz, i, 1));
			xyz[2] = *((double*)PyArray_GETPTR2(npxyz, i, 2));
			tan_xyzarr2pixelxy(tan, xyz, x+i, y+i);
		}
		return 0;
	}




%}

%pythoncode %{
import numpy as np

def tan_t_tostring(self):
	return ('Tan: crpix (%.1f, %.1f), crval (%g, %g), cd (%g, %g, %g, %g), image %g x %g' %
			(self.crpix[0], self.crpix[1], self.crval[0], self.crval[1],
			 self.cd[0], self.cd[1], self.cd[2], self.cd[3],
			 self.imagew, self.imageh))
tan_t.__str__ = tan_t_tostring

def tan_t_pixelxy2radec_any(self, x, y):
	if np.iterable(x) or np.iterable(y):
		x = np.atleast_1d(x).astype(float)
		y = np.atleast_1d(y).astype(float)
		r = np.empty(len(x))
		d = np.empty(len(x))
		tan_numpy_pixelxy2radec(self.this, x, y, r, d, 0)
		return r,d
	else:
		return self.pixelxy2radec_single(float(x), float(y))
tan_t.pixelxy2radec_single = tan_t.pixelxy2radec
tan_t.pixelxy2radec = tan_t_pixelxy2radec_any

def tan_t_radec2pixelxy_any(self, r, d):
	if np.iterable(r) or np.iterable(d):
		r = np.atleast_1d(r).astype(float)
		d = np.atleast_1d(d).astype(float)
		# HACK -- should broadcast...
		assert(len(r) == len(d))
		x = np.empty(len(r))
		y = np.empty(len(r))
		# This looks like a bug (pixelxy2radec rather than radec2pixel)
		# but it isn't ("reverse = 1")
		tan_numpy_pixelxy2radec(self.this, x, y, r, d, 1)
		return x,y
	else:
		good,x,y = self.radec2pixelxy_single(r, d)
		return x,y
tan_t.radec2pixelxy_single = tan_t.radec2pixelxy
tan_t.radec2pixelxy = tan_t_radec2pixelxy_any


def tan_t_radec_bounds(self):
	W,H = self.imagew, self.imageh
	r,d = self.pixelxy2radec([1, W, W, 1], [1, 1, H, H])
	return (r.min(), r.max(), d.min(), d.max())
tan_t.radec_bounds = tan_t_radec_bounds	   

def tan_t_xyz2pixelxy_any(self, xyz):
	if np.iterable(xyz[0]):
		xyz = np.atleast_2d(xyz).astype(float)
		(N,three) = xyz.shape
		assert(three == 3)
		x = np.empty(N)
		y = np.empty(N)
		# This looks like a bug (pixelxy2radec rather than radec2pixel)
		# but it isn't ("reverse = 1")
		tan_numpy_xyz2pixelxy(self.this, xyz, x, y)
		return x,y
	else:
		good,x,y = self.xyz2pixelxy_single(*xyz)
		return x,y
tan_t.xyz2pixelxy_single = tan_t.xyz2pixelxy
tan_t.xyz2pixelxy = tan_t_xyz2pixelxy_any

Tan = tan_t
%} 


%include "fitsioutils.h"

