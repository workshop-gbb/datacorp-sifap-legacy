#!/usr/bin/env python3
"""Forge Natural cataloged DDM objects (.NGD) from text DDM definitions."""
from __future__ import annotations

import argparse
import dataclasses
import pathlib
import re
import struct
import time


FIELD_RE = re.compile(
    r"^(?P<t>[GMPS]?)\s*(?P<lvl>[1-7])\s+(?P<sn>[A-Z0-9]{2})\s+"
    r"(?P<name>[A-Z0-9][A-Z0-9@\-]*)\s+(?P<fmt>[A-Z])\s+"
    r"(?P<leng>\d+(?:[,.]\d+)?)\s*(?P<rest>.*)$"
)
GROUP_RE = re.compile(r"^(?P<t>[GP])\s+(?P<lvl>[1-7])\s+(?P<sn>[A-Z0-9]{2})\s+(?P<name>[A-Z0-9][A-Z0-9@\-]*)\s*(?P<rest>.*)$")
NSD_HEADER_RE = re.compile(r"^DB:\s*(?P<dbid>\d+)\s+FILE:\s*(?P<fnr>\d+)\s+-\s*(?P<file>.*?)\s+DEFAULT SEQUENCE:")
LIST_HEADER_RE = re.compile(r"^DDM NAME:\s*(?P<ddm>[A-Z0-9@\-]+)\s+DEFAULT SEQUENCE:")
DERIVED_RE = re.compile(r"^S\s+(?P<sn>[A-Z0-9]{2})\s+(?P<name>[A-Z0-9][A-Z0-9@\-]*)\s+(?P<fmt>[A-Z])\s+(?P<leng>\d+(?:[,.]\d+)?)\s*(?P<rest>.*)$")
LIST_DB_RE = re.compile(r"^DBID:\s*(?P<dbid>\d+)\s+FNR:\s*(?P<fnr>\d+)")


@dataclasses.dataclass
class Field:
    short_name: str
    name: str
    level: int
    field_type: str
    fmt: str
    length: int
    storage: str = " "
    descriptor: str = " "
    header: str | None = None
    edit_mask: str | None = None
    sources: list[str] = dataclasses.field(default_factory=list)
    derived: bool = False


@dataclasses.dataclass
class Ddm:
    name: str
    dbid: int
    fnr: int
    file_name: str
    fields: list[Field]


def tag(tag_id: int, value: str) -> bytes:
    raw = value.encode("ascii")
    if len(raw) % 2:
        raw += b"\x00"
    return struct.pack("<HH", tag_id, len(raw)) + raw


def ddm_length(fmt: str, spec: str) -> int:
    return int(re.split(r"[,.]", spec)[0])


def parse_flags(rest: str) -> tuple[str, str]:
    storage = " "
    descriptor = " "
    tokens = rest.split()
    if tokens and tokens[0] in {"N", "F"}:
        storage = tokens.pop(0)
    if tokens and tokens[0] in {"D", "U", "S", "H", "P"}:
        descriptor = "D" if tokens[0] == "U" else tokens[0]
    return storage, descriptor


def parse_text(text: str, *, name: str | None = None, dbid: int | None = None, fnr: int | None = None, file_name: str | None = None) -> Ddm:
    fields: list[Field] = []
    last: Field | None = None
    in_source_fields = False
    in_derived = False
    parsed_name = name or ""
    parsed_dbid = dbid
    parsed_fnr = fnr
    parsed_file = file_name or ""

    for line in text.splitlines():
        if m := NSD_HEADER_RE.match(line):
            parsed_dbid = int(m.group("dbid")) if dbid is None else dbid
            parsed_fnr = int(m.group("fnr")) if fnr is None else fnr
            parsed_file = file_name or m.group("file").strip()
            continue
        if m := LIST_HEADER_RE.match(line):
            parsed_name = name or m.group("ddm")
            parsed_file = file_name or parsed_name
            continue
        if m := LIST_DB_RE.match(line):
            parsed_dbid = int(m.group("dbid")) if dbid is None else dbid
            parsed_fnr = int(m.group("fnr")) if fnr is None else fnr
            continue
        if "DERIVED DESCRIPTORS" in line:
            in_derived = True
            continue
        stripped = line.strip()
        if stripped.startswith("******"):
            in_source_fields = False
            continue
        if last is not None and stripped.startswith("HD="):
            last.header = stripped[3:]
            continue
        if last is not None and stripped.startswith("EM="):
            last.edit_mask = stripped[3:]
            continue
        if line.startswith("*") and "SOURCE FIELD" in line:
            in_source_fields = True
            continue
        if last is not None and stripped.startswith("/*"):
            in_source_fields = True
            source = stripped[2:].strip()
            for part in source.split(","):
                part = part.strip()
                if part:
                    last.sources.append(part)
                    last.derived = True
            continue
        if in_source_fields and last is not None and line.startswith("*"):
            source = line[1:].strip()
            if source and not source.startswith("-"):
                for part in source.split(","):
                    part = part.strip()
                    if part:
                        last.sources.append(part)
                        last.derived = True
                continue
        in_source_fields = False
        if not stripped or stripped.startswith("*") or stripped.startswith("T ") or stripped.startswith("- ") or stripped.startswith("TYPE:"):
            continue

        dm = DERIVED_RE.match(stripped) if in_derived else None
        m = FIELD_RE.match(stripped)
        gm = GROUP_RE.match(stripped)
        if dm:
            groups = dm.groupdict()
            storage, descriptor = parse_flags(groups["rest"])
            fields.append(
                Field(
                    short_name=groups["sn"],
                    name=groups["name"],
                    level=1,
                    field_type=" ",
                    fmt=groups["fmt"],
                    length=ddm_length(groups["fmt"], groups["leng"]),
                    storage=storage,
                    descriptor=descriptor,
                    derived=True,
                )
            )
            last = fields[-1]
        elif m:
            groups = m.groupdict()
            source_type = groups["t"]
            field_type = "M" if source_type == "M" else ("P" if source_type == "P" else " ")
            storage, descriptor = parse_flags(groups["rest"])
            fields.append(
                Field(
                    short_name=groups["sn"],
                    name=groups["name"],
                    level=int(groups["lvl"]),
                    field_type=field_type,
                    fmt=groups["fmt"],
                    length=ddm_length(groups["fmt"], groups["leng"]),
                    storage=storage,
                    descriptor=descriptor,
                    derived=in_derived or source_type == "S",
                )
            )
            last = fields[-1]
        elif gm:
            groups = gm.groupdict()
            fields.append(
                Field(
                    short_name=groups["sn"],
                    name=groups["name"],
                    level=int(groups["lvl"]),
                    field_type=groups["t"],
                    fmt=" ",
                    length=0,
                    derived=in_derived,
                )
            )
            last = fields[-1]

    if parsed_dbid is None or parsed_fnr is None:
        raise ValueError("DDM DBID/FNR not found; pass --dbid and --fnr")
    return Ddm(parsed_name, parsed_dbid, parsed_fnr, parsed_file or parsed_name, fields)


def encode_field(field: Field) -> bytes:
    flags = f"{field.field_type}{field.fmt}{field.storage}{field.descriptor}".encode("ascii")
    tags = [tag(1, field.name)]
    if field.header:
        tags.append(tag(3, field.header))
    if field.edit_mask:
        tags.append(tag(2, field.edit_mask))
    for source in field.sources:
        tags.append(tag(6, source))
    out = bytearray()
    out += struct.pack("<H", field.length)
    out += b"\x00\x00\x00\x00"
    out += struct.pack("<H", field.level)
    out += b"\x00\x00\x00"
    out += flags
    out += struct.pack("B", len(tags) + 1)
    out += b"\x00\x00\x02\x00"
    out += field.short_name.encode("ascii")
    for item in tags:
        out += item
    while len(out) % 4:
        out += b"\x00"
    return bytes(out)


def physical_field_count(fields: list[Field]) -> int:
    base = [field for field in fields if not field.derived]
    return 1 + sum(1 for field in base if field.field_type != "G")


def encode_ngd(ddm: Ddm, *, timestamp: int | None = None) -> bytes:
    if timestamp is None:
        timestamp = int(time.time())
    records = b"".join(encode_field(field) for field in ddm.fields)
    file_name = ddm.file_name.encode("ascii")
    if len(file_name) < 9:
        file_name = file_name.ljust(9, b" ")
    header_size = 0x64 + len(file_name)
    header = bytearray(header_size)
    header[0:4] = b"\xff\xffD\x00"
    header[0x16:0x20] = bytes.fromhex("08 00 03 00 09 03 02 00 01 00")
    header[0x20:0x28] = ddm.name.encode("ascii")[:8].ljust(8, b" ")
    header[0x28:0x2C] = struct.pack("<I", timestamp)
    values = [0x50, 1, physical_field_count(ddm.fields), 1, len(records), 1, len(ddm.fields), ddm.dbid, ddm.fnr, len(file_name)]
    for idx, value in enumerate(values):
        header[0x38 + idx * 4 : 0x3C + idx * 4] = struct.pack("<I", value)
    header[0x60:0x64] = b"\x00\x00\x05\x00"
    header[0x64 : 0x64 + len(file_name)] = file_name
    out = bytes(header) + records
    out = out[:4] + struct.pack("<I", len(out)) + out[8:]
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Natural .NGD files from DDM text")
    parser.add_argument("--ddm", required=True, help="Input .ddm or .NSD")
    parser.add_argument("--out", required=True, help="Output .NGD")
    parser.add_argument("--name")
    parser.add_argument("--dbid", type=int)
    parser.add_argument("--fnr", type=int)
    parser.add_argument("--file-name")
    parser.add_argument("--timestamp", type=lambda value: int(value, 0))
    args = parser.parse_args()

    path = pathlib.Path(args.ddm)
    ddm = parse_text(path.read_text(encoding="utf-8", errors="replace"), name=args.name, dbid=args.dbid, fnr=args.fnr, file_name=args.file_name)
    pathlib.Path(args.out).write_bytes(encode_ngd(ddm, timestamp=args.timestamp))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
