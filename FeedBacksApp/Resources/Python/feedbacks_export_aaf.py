#!/usr/bin/env python3

import json
import os
import sys


def _nominal_timecode_fps(frame_rate):
    rounded = round(frame_rate, 3)
    if abs(rounded - 23.976) < 0.01:
        return 24
    if abs(rounded - 29.97) < 0.01:
        return 30
    return int(round(frame_rate))


def _is_drop_frame_rate(frame_rate):
    rounded = round(frame_rate, 3)
    return abs(rounded - 29.97) < 0.01 or abs(rounded - 59.94) < 0.01


def _frames_to_samples(frame_count, frame_rate, sample_rate):
    return int(round((float(frame_count) / float(frame_rate)) * float(sample_rate)))


def _timecode_to_frame_count(timecode, frame_rate):
    parts = str(timecode).strip().split(":")
    if len(parts) != 4:
        raise ValueError(f"Invalid timecode '{timecode}'")
    hh, mm, ss, ff = [int(part) for part in parts]
    base_seconds = (hh * 3600) + (mm * 60) + ss
    return int(round(base_seconds * frame_rate)) + ff


def _append_marker_slot(f, comp, marker_rows, tc_edit_rate, slot_id, slot_name):
    if not marker_rows:
        return

    marker_slot = f.create.EventMobSlot()
    marker_slot.slot_id = slot_id
    marker_slot.name = slot_name
    marker_slot.edit_rate = tc_edit_rate
    marker_seq = f.create.Sequence(media_kind="DescriptiveMetadata")
    marker_seq["Components"].value = []

    for item in marker_rows:
        marker = f.create.CommentMarker()
        marker["Position"].value = max(0, int(item["frame"]))
        marker["Length"].value = 0
        try:
            marker["Comment"].value = item["comment"] or ""
        except Exception:
            pass
        marker_seq.components.append(marker)

    marker_slot.segment = marker_seq
    comp.slots.append(marker_slot)


def export_aaf(output_path, payload_path):
    try:
        import aaf2
    except Exception as exc:
        print(f"❌ aaf2 introuvable: {exc}")
        return 1

    try:
        with open(payload_path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except Exception as exc:
        print(f"❌ Erreur lecture JSON: {exc}")
        return 1

    title = str(payload.get("title") or "FeedBacksMarkers")
    frame_rate = float(payload.get("frameRate") or 25.0)
    rows = payload.get("rows") or []

    marker_rows = []
    for row in rows:
        try:
            timecode = row["timecode"]
            comment = str(row.get("comment") or "")
            absolute_frame = _timecode_to_frame_count(timecode, frame_rate)
            marker_rows.append({"frame": absolute_frame, "comment": comment})
        except Exception:
            continue

    marker_rows = sorted(marker_rows, key=lambda item: item["frame"])
    if not marker_rows:
        print("❌ Aucun marker a exporter")
        return 1

    start_timecode_frames = marker_rows[0]["frame"]
    for item in marker_rows:
        item["frame"] = max(0, item["frame"] - start_timecode_frames)

    max_relative_frame = marker_rows[-1]["frame"]
    duration_frames = max(max_relative_frame + int(round(frame_rate)), int(round(frame_rate)))
    sample_rate = 48000
    total_samples = _frames_to_samples(duration_frames, frame_rate, sample_rate)

    try:
        with aaf2.open(output_path, "w") as f:
            comp = f.create.CompositionMob(title)
            f.content.mobs.append(comp)

            tc_edit_rate = frame_rate
            tc_fps = _nominal_timecode_fps(frame_rate)
            tc_drop = _is_drop_frame_rate(frame_rate)
            if hasattr(comp, "create_timecode_slot"):
                tc_slot = comp.create_timecode_slot(
                    edit_rate=tc_edit_rate,
                    timecode_fps=tc_fps,
                    drop_frame=tc_drop,
                    length=duration_frames
                )
            else:
                tc_slot = comp.create_timeline_slot(edit_rate=tc_edit_rate)
                tc_slot.segment = f.create.Timecode(tc_fps, drop=tc_drop, length=duration_frames)
            tc_slot.name = "Timecode"
            tc_slot.segment.start = start_timecode_frames

            # Several DAW importers ignore marker-only AAFs unless the composition
            # also carries a regular timeline track. Keep it media-free with a filler.
            comp_slot = comp.create_sound_slot(edit_rate=sample_rate)
            comp_slot.name = title
            seq = comp_slot.segment
            filler = f.create.Filler(media_kind="sound", length=total_samples)
            seq.components.append(filler)
            seq.length = total_samples

            _append_marker_slot(
                f=f,
                comp=comp,
                marker_rows=marker_rows,
                tc_edit_rate=tc_edit_rate,
                slot_id=100,
                slot_name="Feedback Markers"
            )

        return 0
    except Exception as exc:
        print(f"❌ Erreur export AAF: {exc}")
        return 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 feedbacks_export_aaf.py /path/to/output.aaf /path/to/payload.json")
        sys.exit(1)
    sys.exit(export_aaf(sys.argv[1], sys.argv[2]))
