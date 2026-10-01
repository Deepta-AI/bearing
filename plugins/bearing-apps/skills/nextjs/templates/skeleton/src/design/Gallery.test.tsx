import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";

import { GalleryIndex, GalleryScreen } from "./Gallery";
import { galleryEnabled, parseGallerySearch, searchToQuery } from "./registry";
import type { ScreenSpec } from "./screen";

const screens: ScreenSpec[] = [
  {
    id: "S-02",
    name: "Second",
    feature: "demo",
    job: "Show the second screen.",
    states: { success: () => <p>second ok</p> },
  },
  {
    id: "S-01",
    name: "First",
    feature: "demo",
    job: "Show the first screen.",
    states: {
      loading: () => <p>loading first</p>,
      error: () => <p>first failed</p>,
    },
  },
];

afterEach(() => {
  document.documentElement.classList.remove("dark");
  delete document.documentElement.dataset.theme;
  delete document.documentElement.dataset.variant;
});

// The gallery renders any screen design in any state with the app's own
// components; screen-design and design-critique read it at /__design.
describe("design gallery", () => {
  it("lists every screen with its states", () => {
    render(<GalleryIndex screens={screens} />);
    expect(screen.getByRole("heading", { name: "Design gallery" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "S-01 First" })).toHaveAttribute(
      "href",
      "/__design/S-01",
    );
    expect(screen.getByText("loading")).toBeInTheDocument();
  });

  it("renders the chosen state with the state switcher", () => {
    render(<GalleryScreen id="S-01" search={{ state: "error" }} screens={screens} />);
    expect(screen.getByText("first failed")).toBeInTheDocument();
    expect(screen.getByRole("tablist", { name: "S-01 states" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "loading" })).toHaveAttribute(
      "href",
      "/__design/S-01?state=loading",
    );
  });

  it("shows the first state when none is asked for", () => {
    render(<GalleryScreen id="S-01" search={{}} screens={screens} />);
    expect(screen.getByText("loading first")).toBeInTheDocument();
  });

  it("hides the switcher for screenshots and applies the dark theme and a variant", () => {
    render(
      <GalleryScreen
        id="S-02"
        search={{ chrome: "0", theme: "dark", variant: "2-ledger" }}
        screens={screens}
      />,
    );
    expect(screen.getByText("second ok")).toBeInTheDocument();
    expect(screen.queryByRole("tablist")).not.toBeInTheDocument();
    expect(document.documentElement).toHaveClass("dark");
    expect(document.documentElement.dataset.variant).toBe("2-ledger");
  });

  it("says so when the screen is unknown", () => {
    render(<GalleryScreen id="S-99" search={{}} screens={screens} />);
    expect(screen.getByRole("alert")).toHaveTextContent("No screen S-99");
  });

  it("keeps only the search keys it knows", () => {
    expect(
      parseGallerySearch({ state: "error", theme: "dark", chrome: "0", variant: "1-quiet", x: 1 }),
    ).toEqual({ state: "error", theme: "dark", chrome: "0", variant: "1-quiet" });
    expect(parseGallerySearch({ theme: "blue", chrome: 1, variant: "../evil" })).toEqual({
      state: undefined,
      theme: undefined,
      chrome: undefined,
      variant: undefined,
    });
    expect(searchToQuery({ state: "error", theme: undefined })).toBe("?state=error");
    expect(searchToQuery({})).toBe("");
  });

  it("is on in development and off in production unless asked for", () => {
    expect(galleryEnabled({ NODE_ENV: "development" })).toBe(true);
    expect(galleryEnabled({ NODE_ENV: "production" })).toBe(false);
    expect(galleryEnabled({ NODE_ENV: "production", DESIGN_GALLERY: "1" })).toBe(true);
  });
});
