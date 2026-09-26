"""Patient records. Synthetic: every name, number and date is made up."""

from dataclasses import dataclass


@dataclass
class Patient:
    id: str
    name: str
    phone: str
    dob: str


PATIENTS = {
    p.id: p
    for p in (
        Patient("p_501", "Kiran Deshpande", "+91 90000 30501", "1988-04-12"),
        Patient("p_502", "Farah Siddiqui", "+91 90000 30502", "1975-11-30"),
        Patient("p_503", "Vikram Nair", "+91 90000 30503", "1992-02-07"),
        Patient("p_504", "Lata Kulkarni", "+91 90000 30504", "1961-06-19"),
    )
}
