import socket
from ipaddress import ip_address

import pytest

import psycopg._dns
from psycopg.conninfo import conninfo_to_dict


@pytest.mark.parametrize(
    "conninfo, want",
    [
        ("", ""),
        ("host='' user=bar", "host='' user=bar"),
        (
            "host=127.0.0.1 user=bar",
            "host=127.0.0.1 user=bar hostaddr=127.0.0.1",
        ),
        (
            "host=1.1.1.1,2.2.2.2 user=bar",
            "host=1.1.1.1,2.2.2.2 user=bar hostaddr=1.1.1.1,2.2.2.2",
        ),
        (
            "host=1.1.1.1,2.2.2.2 port=5432",
            "host=1.1.1.1,2.2.2.2 port=5432 hostaddr=1.1.1.1,2.2.2.2",
        ),
    ],
)
@pytest.mark.asyncio
async def test_resolve_hostaddr_async_no_resolve(monkeypatch, conninfo, want):
    monkeypatch.setattr(socket, "gethostbyname", fake_gethostbyname)

    params = conninfo_to_dict(conninfo)
    await psycopg._dns.resolve_hostaddr_async(params)
    assert conninfo_to_dict(want) == params


@pytest.mark.parametrize(
    "conninfo, want",
    [
        (
            "host=foo.com,qux.com",
            "host=foo.com,qux.com hostaddr=1.1.1.1,2.2.2.2",
        ),
        (
            "host=foo.com,qux.com port=5433",
            "host=foo.com,qux.com hostaddr=1.1.1.1,2.2.2.2 port=5433",
        ),
        (
            "host=foo.com,qux.com port=5432,5433",
            "host=foo.com,qux.com hostaddr=1.1.1.1,2.2.2.2 port=5432,5433",
        ),
        (
            "host=foo.com,nosuchhost.com",
            "host=foo.com hostaddr=1.1.1.1",
        ),
        (
            "host=nosuchhost.com,foo.com",
            "host=foo.com hostaddr=1.1.1.1",
        ),
    ],
)
@pytest.mark.asyncio
async def test_resolve_hostaddr_async(monkeypatch, conninfo, want):
    monkeypatch.setattr(socket, "gethostbyname", fake_gethostbyname)

    params = conninfo_to_dict(conninfo)
    await psycopg._dns.resolve_hostaddr_async(params)
    assert conninfo_to_dict(want) == params


fake_hosts = {
    "localhost": "127.0.0.1",
    "foo.com": "1.1.1.1",
    "qux.com": "2.2.2.2",
}


def fake_gethostbyname(host):
    try:
        ip_address(host)
        return host
    except Exception:
        pass

    try:
        addr = fake_hosts[host]
    except KeyError:
        raise OSError(f"unknown test host: {host}")
    else:
        return addr


@pytest.mark.parametrize(
    "conninfo",
    [
        "host=bad1.com,bad2.com",
        "host=foo.com port=1,2",
        "host=1.1.1.1,2.2.2.2 port=5432,5433,5434",
    ],
)
@pytest.mark.asyncio
async def test_resolve_hostaddr_async_bad(monkeypatch, conninfo):
    monkeypatch.setattr(socket, "gethostbyname", fake_gethostbyname)
    params = conninfo_to_dict(conninfo)
    with pytest.raises((TypeError, psycopg.Error)):
        await psycopg._dns.resolve_hostaddr_async(params)
