import { notFound } from "next/navigation";

import { GalleryScreen } from "@/design/Gallery";
import { galleryEnabled, parseGallerySearch } from "@/design/registry";

/** /__design/<id>?state=&theme=&chrome=0&variant=: one screen in one state. */
export default async function DesignScreenPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  if (!galleryEnabled()) notFound();
  const { id } = await params;
  const search = parseGallerySearch(await searchParams);
  return <GalleryScreen id={id} search={search} />;
}
