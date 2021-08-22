"""
DNS query support
"""

# Copyright (C) 2021 The Psycopg Team

import socket
from typing import Any, Dict

from . import pq
from . import errors as e
from ._compat import get_running_loop


async def resolve_hostaddr_async(params: Dict[str, Any]) -> None:
    """
    Change the *params* dict inplace performing async DNS lookup of the hosts

    If a ``host`` param is present but not ``hostname``, resolve the host
    addresses dynamically.

    Change ``host``, ``hostname``, ``port`` in place to allow to connect
    without further DNS lookups (remove hosts that are not resolved, keep the
    lists consistent).

    Raise `OperationalError` if connection is not possible (e.g. no host
    resolve, inconsistent lists length).

    See https://www.postgresql.org/docs/13/libpq-connect.html#LIBPQ-PARAMKEYWORDS
    for explanation of how these params are used, and how they support multiple
    entries.
    """
    if params.get("hostaddr") or not params.get("host"):
        return

    if pq.version() < 100000:
        # hostaddr not supported
        return

    host = params["host"]

    if host.startswith("/") or host[1:2] == ":":
        # Local path
        return

    hosts_in = host.split(",")
    ports_in = str(params["port"]).split(",") if params.get("port") else []
    if len(ports_in) <= 1:
        # If only one port is specified, the libpq will apply it to all
        # the hosts, so don't mangle it.
        del ports_in[:]
    else:
        if len(ports_in) != len(hosts_in):
            # ProgrammingError would have been more appropriate, but this is
            # what the raise if the libpq fails connect in the same case.
            raise e.OperationalError(
                f"cannot match {len(hosts_in)} hosts with {len(ports_in)}"
                " port numbers"
            )
        ports_out = []

    loop = get_running_loop()
    hosts_out = []
    hostaddr_out = []
    for i, host in enumerate(hosts_in):
        try:
            addr = await loop.run_in_executor(None, socket.gethostbyname, host)
        except Exception as ex:
            last_exc = ex
        else:
            hosts_out.append(host)
            hostaddr_out.append(addr)
            if ports_in:
                ports_out.append(ports_in[i])

    # Throw an exception if no host could be resolved
    if not hosts_out:
        raise e.OperationalError(str(last_exc))

    params["host"] = ",".join(hosts_out)
    params["hostaddr"] = ",".join(hostaddr_out)
    if ports_in:
        params["port"] = ",".join(ports_out)
