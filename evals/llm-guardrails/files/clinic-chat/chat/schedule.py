"""Today's appointment book. Synthetic data."""

from chat.patients import PATIENTS

DOCTORS = {"d_1": "Dr. S. Rao (General Medicine)", "d_2": "Dr. A. Menon (Dermatology)"}

# (doctor, time) -> patient id, or None when the slot is free
BOOK = {
    ("d_1", "09:30"): "p_502",
    ("d_1", "10:00"): "p_503",
    ("d_1", "10:30"): None,
    ("d_1", "11:00"): "p_504",
    ("d_1", "11:30"): None,
    ("d_2", "16:00"): "p_503",
    ("d_2", "16:30"): None,
}


def today_text() -> str:
    lines = []
    for (doc, time), pid in sorted(BOOK.items()):
        if pid is None:
            lines.append(f"{DOCTORS[doc]} {time}: FREE")
        else:
            p = PATIENTS[pid]
            lines.append(f"{DOCTORS[doc]} {time}: booked by {p.name} ({p.phone}), patient {p.id}")
    return "\n".join(lines)
