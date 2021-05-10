"""
C implementation of the adaptation system.

External interface to allow to write adapters in external modules.
"""

from psycopg3_c cimport pq
from psycopg3_c.pq cimport libpq


cdef class CDumper:
    cdef readonly object cls
    cdef public libpq.Oid oid
    cdef pq.PGconn _pgconn

    cdef Py_ssize_t cdump(self, obj, bytearray rv, Py_ssize_t offset) except -1
    cdef object get_key(self, object obj, object format)
    cdef object upgrade(self, object obj, object format)

    @staticmethod
    cdef char *ensure_size(bytearray ba, Py_ssize_t offset, Py_ssize_t size) except NULL


cdef class CLoader:
    cdef public libpq.Oid oid
    cdef pq.PGconn _pgconn

    cdef object cload(self, const char *data, size_t length)
