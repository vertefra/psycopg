cimport cython

from libc.stdint cimport uint16_t, int16_t

import psycopg3.pq
from psycopg3 import errors as e

cdef extern from "Python.h":
    # Missing in cpython/unicode.pxd
    const char *PyUnicode_AsUTF8(object unicode) except NULL


DEF DEC_DIGITS = 4  # decimal digits per Postgres "digit"
DEF NUMERIC_POS = 0x0000
DEF NUMERIC_NEG = 0x4000
DEF NUMERIC_NAN = 0xC000
DEF NUMERIC_PINF = 0xD000
DEF NUMERIC_NINF = 0xF000

cdef extern from *:
    """
/* Weights of py digits into a pg digit according to their positions. */
static const int pydigit_weights[] = {1000, 100, 10, 1};
"""
    const int[4] pydigit_weights


@cython.final
@cython.cdivision(True)
cdef class DecimalBinaryDumper(CDumper):

    format = psycopg3.pq.Format.BINARY

    def __cinit__(self):
        self.oid = oids.NUMERIC_OID

    cdef Py_ssize_t cdump(self, obj, bytearray rv, Py_ssize_t offset) except -1:

        # TODO: this implementation is about 30% slower than the text dump.
        # This might be probably optimised by accessing the C structure of
        # the Decimal object, if available, which would save the creation of
        # several intermediate Python objects (the DecimalTuple, the digits
        # tuple, and then accessing them).

        cdef object t = obj.as_tuple()
        cdef int sign = t[0]
        cdef tuple digits = t[1]
        cdef uint16_t *buf
        cdef Py_ssize_t length

        cdef object pyexp = t[2]
        cdef const char *bexp
        if not isinstance(pyexp, int):
            # Handle inf, nan
            length = 4 * sizeof(uint16_t)
            buf = <uint16_t *>CDumper.ensure_size(rv, offset, length)
            buf[0] = 0
            buf[1] = 0
            buf[3] = 0
            bexp = PyUnicode_AsUTF8(pyexp)
            if bexp[0] == b'n' or bexp[0] == b'N':
                buf[2] = endian.htobe16(NUMERIC_NAN)
            elif bexp[0] == b'F':
                if sign:
                    buf[2] = endian.htobe16(NUMERIC_NINF)
                else:
                    buf[2] = endian.htobe16(NUMERIC_PINF)
            else:
                raise e.DataError(f"unexpected decimal exponent: {pyexp}")
            return length

        cdef int exp = pyexp
        cdef uint16_t ndigits = len(digits)

        # Find the last nonzero digit
        cdef int nzdigits = ndigits
        while nzdigits > 0 and digits[nzdigits - 1] == 0:
            nzdigits -= 1

        cdef uint16_t dscale
        if exp <= 0:
            dscale = -exp
        else:
            dscale = 0
            # align the py digits to the pg digits if there's some py exponent
            ndigits += exp % DEC_DIGITS

        if nzdigits == 0:
            length = 4 * sizeof(uint16_t)
            buf = <uint16_t *>CDumper.ensure_size(rv, offset, length)
            buf[0] = 0  # ndigits
            buf[1] = 0  # weight
            buf[2] = endian.htobe16(NUMERIC_POS)  # sign
            buf[3] = endian.htobe16(dscale)
            return length

        # Equivalent of 0-padding left to align the py digits to the pg digits
        # but without changing the digits tuple.
        cdef int wi = 0
        cdef int mod = (ndigits - dscale) % DEC_DIGITS
        if mod < 0:
            # the difference between C and Py % operator
            mod += 4
        if mod:
            wi = DEC_DIGITS - mod
            ndigits += wi

        cdef int tmp = nzdigits + wi
        cdef int pgdigits = tmp // DEC_DIGITS + (tmp % DEC_DIGITS and 1)
        length = (pgdigits + 4) * sizeof(uint16_t)
        buf = <uint16_t*>CDumper.ensure_size(rv, offset, length)
        buf[0] = endian.htobe16(pgdigits)
        buf[1] = endian.htobe16(<int16_t>((ndigits + exp) // DEC_DIGITS - 1))
        buf[2] = endian.htobe16(NUMERIC_NEG) if sign else endian.htobe16(NUMERIC_POS)
        buf[3] = endian.htobe16(dscale)

        cdef uint16_t pgdigit = 0
        cdef int bi = 4
        for i in range(nzdigits):
            pgdigit += pydigit_weights[wi] * <int>(digits[i])
            wi += 1
            if wi >= DEC_DIGITS:
                buf[bi] = endian.htobe16(pgdigit)
                pgdigit = wi = 0
                bi += 1

        if pgdigit:
            buf[bi] = endian.htobe16(pgdigit)

        return length
