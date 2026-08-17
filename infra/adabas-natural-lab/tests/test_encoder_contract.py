from __future__ import annotations

import struct
import subprocess

from conftest import DDM_DIR, ENCODER, FILES, SEED_DIR, WORK_DIR


def parse_layout_width(layout_path):
    total = 0
    for line in layout_path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        total += int(line.split()[-1])
    return total


def test_should_derive_seed_widths_from_ddms_and_match_seed_files(encoder):
    for name, (_, ddm, expected_records, expected_width) in FILES.items():
        fields = encoder.parse_ddm((DDM_DIR / ddm).read_text(encoding="utf-8", errors="replace"))
        plan, ddm_width = encoder.build_plan(fields)
        layout_width = parse_layout_width(SEED_DIR / f"layout-{name}.txt")
        data = (SEED_DIR / f"{name}.dat").read_bytes()

        assert ddm_width == expected_width == layout_width
        assert len(data) == expected_records * (expected_width + 1)
        assert all(data[i * (expected_width + 1) + expected_width] == 0x0A for i in range(expected_records))
        assert plan


def test_should_frame_records_with_e4_little_endian_length_excluding_prefix(encoder):
    out = WORK_DIR / "beneficiary.cmpin"
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["python3", str(ENCODER), "--ddm", str(DDM_DIR / "BENEFICIARY.ddm"), "--seed", str(SEED_DIR / "beneficiary.dat"), "--out", str(out)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=True,
    )
    data = out.read_bytes()
    first_body_len = struct.unpack("<I", data[:4])[0]

    assert first_body_len == 1741
    assert data[:4] == b"\xcd\x06\x00\x00"
    assert len(data) == 500 * (4 + first_body_len)


def test_should_encode_periodic_groups_with_one_byte_counts_and_occurrence_major_order(encoder):
    fields = encoder.parse_ddm((DDM_DIR / "BENEFICIARY.ddm").read_text(encoding="utf-8", errors="replace"))
    plan, width = encoder.build_plan(fields)
    record = (SEED_DIR / "beneficiary.dat").read_bytes()[:width]
    body = encoder.encode(record, plan, "<B")

    encoded_offset = 0
    periodic = None
    for entry in plan:
        if entry["kind"] == "PE" and entry["db"] == "DA":
            periodic = entry
            break
        if entry["kind"] in {"F", "MU"}:
            encoded_offset += entry["width"] * entry["occurs"] + (1 if entry["kind"] == "MU" else 0)
        else:
            encoded_offset += 1 + sum(m["width"] for m in entry["members"]) * entry["occurs"]

    assert periodic is not None
    assert body[encoded_offset] == 10

    cursor = encoded_offset + 1
    for occurrence in range(2):
        for member in periodic["members"]:
            expected = record[member["offset"] + occurrence * member["width"] : member["offset"] + (occurrence + 1) * member["width"]]
            assert body[cursor : cursor + member["width"]] == expected
            cursor += member["width"]

    first_member = periodic["members"][0]
    second_member = periodic["members"][1]
    assert body[encoded_offset + 1 + first_member["width"] : encoded_offset + 1 + first_member["width"] + second_member["width"]] == record[
        second_member["offset"] : second_member["offset"] + second_member["width"]
    ]


def test_should_keep_packed_width_arithmetic_and_numeric_fields_unpack_format(encoder):
    assert encoder.width_of("P", "9,2") == 5
    assert encoder.width_of("P", "7.2") == 4
    assert encoder.width_of("P", "3,4") == 2
    assert encoder.width_of("N", "11") == 11
