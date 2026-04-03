#include <ruby.h>

/* Matches Ephem::Core::Constants::Time::SECONDS_PER_DAY */
#define SECONDS_PER_DAY 86400.0

/*
 * Ephem::Computation::ChebyshevPolynomial.evaluate(coeffs, t)
 *
 * Evaluates a 3D Chebyshev polynomial at a given normalized time
 * using the Clenshaw recurrence algorithm.
 *
 * coeffs: Array of Arrays, shape [n_terms][3]
 * t:      Float in [-1, 1]
 *
 * Returns: Array of 3 Floats [x, y, z]
 */
static VALUE
chebyshev_evaluate(VALUE self, VALUE rb_coeffs, VALUE rb_t)
{
    long n, k;
    double t, t2;
    double b1x, b1y, b1z;
    double b2x, b2y, b2z;
    double c0, c1, c2;
    double tx, ty, tz;
    VALUE c_ary;

    Check_Type(rb_coeffs, T_ARRAY);
    t = NUM2DBL(rb_t);

    n = RARRAY_LEN(rb_coeffs);

    b1x = b1y = b1z = 0.0;
    b2x = b2y = b2z = 0.0;

    t2 = 2.0 * t;

    for (k = n - 1; k > 0; k--) {
        c_ary = rb_ary_entry(rb_coeffs, k);
        Check_Type(c_ary, T_ARRAY);
        c0 = NUM2DBL(rb_ary_entry(c_ary, 0));
        c1 = NUM2DBL(rb_ary_entry(c_ary, 1));
        c2 = NUM2DBL(rb_ary_entry(c_ary, 2));

        tx = t2 * b1x - b2x + c0;
        ty = t2 * b1y - b2y + c1;
        tz = t2 * b1z - b2z + c2;

        b2x = b1x; b2y = b1y; b2z = b1z;
        b1x = tx;  b1y = ty;  b1z = tz;
    }

    c_ary = rb_ary_entry(rb_coeffs, 0);
    Check_Type(c_ary, T_ARRAY);
    c0 = NUM2DBL(rb_ary_entry(c_ary, 0));
    c1 = NUM2DBL(rb_ary_entry(c_ary, 1));
    c2 = NUM2DBL(rb_ary_entry(c_ary, 2));

    return rb_ary_new_from_args(3,
        DBL2NUM(t * b1x - b2x + c0),
        DBL2NUM(t * b1y - b2y + c1),
        DBL2NUM(t * b1z - b2z + c2));
}

/*
 * Ephem::Computation::ChebyshevPolynomial.evaluate_derivative(coeffs, t, radius)
 *
 * Evaluates the time derivative of a 3D Chebyshev polynomial
 * using the Clenshaw recurrence algorithm.
 *
 * coeffs: Array of Arrays, shape [n_terms][3]
 * t:      Float in [-1, 1]
 * radius: Float (half-interval in days)
 *
 * Returns: Array of 3 Floats [vx, vy, vz] in units per second
 */
static VALUE
chebyshev_evaluate_derivative(VALUE self, VALUE rb_coeffs, VALUE rb_t,
                              VALUE rb_radius)
{
    long n, k;
    double t, t2, radius, scale, k2;
    double d1x, d1y, d1z;
    double d2x, d2y, d2z;
    double c0, c1, c2;
    double tx, ty, tz;
    VALUE c_ary;

    Check_Type(rb_coeffs, T_ARRAY);
    t = NUM2DBL(rb_t);
    radius = NUM2DBL(rb_radius);

    n = RARRAY_LEN(rb_coeffs);

    if (n < 2) {
        return rb_ary_new_from_args(3,
            DBL2NUM(0.0), DBL2NUM(0.0), DBL2NUM(0.0));
    }

    d1x = d1y = d1z = 0.0;
    d2x = d2y = d2z = 0.0;

    t2 = 2.0 * t;

    for (k = n - 1; k > 0; k--) {
        c_ary = rb_ary_entry(rb_coeffs, k);
        Check_Type(c_ary, T_ARRAY);
        c0 = NUM2DBL(rb_ary_entry(c_ary, 0));
        c1 = NUM2DBL(rb_ary_entry(c_ary, 1));
        c2 = NUM2DBL(rb_ary_entry(c_ary, 2));

        k2 = 2.0 * (double)k;
        tx = t2 * d1x - d2x + k2 * c0;
        ty = t2 * d1y - d2y + k2 * c1;
        tz = t2 * d1z - d2z + k2 * c2;

        d2x = d1x; d2y = d1y; d2z = d1z;
        d1x = tx;  d1y = ty;  d1z = tz;
    }

    scale = SECONDS_PER_DAY / (2.0 * radius);

    return rb_ary_new_from_args(3,
        DBL2NUM(d1x * scale),
        DBL2NUM(d1y * scale),
        DBL2NUM(d1z * scale));
}

void
Init_chebyshev(void)
{
    VALUE mEphem, mComputation, mChebyshevPolynomial;

    mEphem = rb_define_module("Ephem");
    mComputation = rb_define_module_under(mEphem, "Computation");
    mChebyshevPolynomial = rb_define_module_under(mComputation,
                                                  "ChebyshevPolynomial");

    rb_define_module_function(mChebyshevPolynomial, "evaluate",
                              chebyshev_evaluate, 2);
    rb_define_module_function(mChebyshevPolynomial, "evaluate_derivative",
                              chebyshev_evaluate_derivative, 3);
}
