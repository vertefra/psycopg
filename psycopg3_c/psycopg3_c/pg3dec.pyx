"""
psycopg3_c.pg3dec optimization module.

This module contains fast binary conversions between Python Decimal (backed by
the mpdecimal_ library) and PostgreSQL numeric data type.

.. _mpdecimal: https://www.bytereef.org/mpdecimal/

"""

# Copyright (C) 2021 The Psycopg Team

from psycopg3_c._psycopg3 cimport CDumper, oids, endian

include "pg3dec/pg3dec.pyx"
