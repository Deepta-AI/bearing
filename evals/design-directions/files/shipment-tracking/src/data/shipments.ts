export type ShipmentStatus = "booked" | "in_transit" | "delayed" | "delivered" | "exception";

export type TrackingEvent = { at: string; place: string; note: string };

export type Shipment = {
  id: string;
  reference: string;
  carrier: string;
  origin: string;
  destination: string;
  pallets: number;
  weightKg: number;
  status: ShipmentStatus;
  eta: string;
  promisedBy: string;
  events: TrackingEvent[];
  carrierReachable: boolean;
};

export const shipments: Shipment[] = [
  {
    id: "shp_1042",
    reference: "HB-24-01042",
    carrier: "Western Ghats Roadlines",
    origin: "Bhiwandi warehouse 3",
    destination: "Hosur industrial estate, gate 2",
    pallets: 6,
    weightKg: 2840,
    status: "in_transit",
    eta: "2026-09-27T16:00:00+05:30",
    promisedBy: "2026-09-27T18:00:00+05:30",
    carrierReachable: true,
    events: [
      { at: "2026-09-25T09:10:00+05:30", place: "Bhiwandi", note: "Loaded, 6 pallets counted" },
      { at: "2026-09-25T21:40:00+05:30", place: "Pune bypass", note: "Driver change" },
      { at: "2026-09-26T11:05:00+05:30", place: "Belagavi", note: "Passed checkpoint" },
    ],
  },
  {
    id: "shp_1043",
    reference: "HB-24-01043",
    carrier: "Deccan Part Loads",
    origin: "Chakan plant",
    destination: "Guindy depot",
    pallets: 2,
    weightKg: 610,
    status: "delayed",
    eta: "2026-09-28T11:00:00+05:30",
    promisedBy: "2026-09-27T12:00:00+05:30",
    carrierReachable: true,
    events: [
      { at: "2026-09-25T15:00:00+05:30", place: "Chakan", note: "Loaded" },
      { at: "2026-09-26T08:30:00+05:30", place: "Solapur", note: "Held at weighbridge" },
    ],
  },
  {
    id: "shp_1044",
    reference: "HB-24-01044",
    carrier: "Konkan Freight Co",
    origin: "Taloja",
    destination: "Verna, Goa",
    pallets: 4,
    weightKg: 1320,
    status: "booked",
    eta: "2026-09-29T10:00:00+05:30",
    promisedBy: "2026-09-29T17:00:00+05:30",
    carrierReachable: false,
    events: [],
  },
];
