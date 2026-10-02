import { notFound } from "next/navigation";

import { GalleryIndex } from "@/design/Gallery";
import { galleryEnabled } from "@/design/registry";

// /__design (the folder name %5F%5Fdesign is how the App Router spells a
// leading underscore, which otherwise marks a private folder). The gallery
// runs in `next dev`, and in a build only with DESIGN_GALLERY=1; production
// answers 404.
export default function DesignGalleryPage() {
  if (!galleryEnabled()) notFound();
  return <GalleryIndex />;
}
