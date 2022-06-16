`crdb` -- CockroachDB support
=============================

.. module:: psycopg.crdb

.. versionadded:: 3.1

CockroachDB_ is a distributed database using the same fronted-backend protocol
of PostgreSQL. As such, Psycopg can be used to write Python programs
interacting with CockroachDB.

.. _CockroachDB: https://www.cockroachlabs.com/

Opening a connection to a CRDB database using `psycopg.connect()` provides a
largely working object. However, using the `psycopg.crdb.connect()` function
instead, Psycopg will create more specialised objects and provide a types
mapping tweaked on the CockroachDB data model.


.. _crdb-differences:

Main differences from PostgreSQL
--------------------------------

CockroachDB behaviour is `different from PostgreSQL`__: please refer to the
database documentation for details. These are some of the main differences
affecting Psycopg behaviour:

.. __: https://www.cockroachlabs.com/docs/stable/postgresql-compatibility.html


- `~psycopg.Connection.cancel()` doesn't work. You can use `CANCEL QUERY`_
  instead (from a different connection). TODOCRDB: possibly supported in 22.1.
- `~psycopg.ConnectionInfo.backend_pid` doesn't return useful info. You can
  use `SHOW SESSIONS`_ to find a session id which you may use with `CANCEL
  SESSION`_ in lieu of PostgreSQL's :sql:`pg_terminate_backend()`.
- Several data types are missing or slightly different from PostgreSQL (see
  `adapters` for an overview of the differences).
- The :ref:`two-phase commit protocol <two-phase-commit>` is not supported.
- :sql:`LISTEN` and :sql:`NOTIFY` are not supported. However the `CHANGEFEED`_
  command, in conjunction with `~psycopg.Cursor.stream()`, can provide push
  notifications.

.. _CANCEL QUERY: https://www.cockroachlabs.com/docs/stable/cancel-query.html
.. _SHOW SESSIONS: https://www.cockroachlabs.com/docs/stable/show-sessions.html
.. _CANCEL SESSION: https://www.cockroachlabs.com/docs/stable/cancel-session.html
.. _CHANGEFEED: https://www.cockroachlabs.com/docs/stable/changefeed-for.html


.. _crdb-objects:

CockroachDB-specific objects
----------------------------

.. autofunction:: connect

   This is an alias of the class method `CrdbConnection.connect`.

   If you need an asynchronous connection use the `AsyncCrdbConnection.connect()`
   method instead.


.. autoclass:: CrdbConnection

    `psycopg.Connection` subclass.


.. autoclass:: AsyncCrdbConnection

    `psycopg.AsyncConnection` subclass.


.. autoclass:: CrdbConnectionInfo

    The object is returned by the `!info` attribute of `CrdbConnection` and
    `AsyncCrdbConnection`.

    The object behaves like the `!ConnectionInfo`, with the following
    differences:

    .. autoattribute:: vendor

        The `CockroachDB` string.

    .. autoattribute:: server_version

    .. attribute:: backend_pid

        Always 0 as not reported by CockroachDB.


.. data:: adapters

    The default adapters map establishing how Python and CockroachDB types are
    converted into each other.
 
    The map is used as a template when new connections are created, using
    `psycopg.crdb.connect()`.

    This registry contains only the types and adapters supported by
    CockroachDB. Several PostgreSQL types and adapters are missing or
    different from PostgreSQL, among which:

    - Composite types
    - :sql:`range`, :sql:`multirange` types
    - The :sql:`hstore` type
    - Geometric types
    - Nested arrays
    - Arrays of :sql:`jsonb`
    - The :sql:`cidr` data type
    - The :sql:`json` type is an alias for :sql:`jsonb`
    - The :sql:`int` type is an alias for :sql:`int8`, not `int4`.
