import { notFound } from "next/navigation";
import { Suspense } from "react";

import { GalleryScreen } from "@/design/Gallery";
import { galleryEnabled, parseGallerySearch } from "@/design/registry";

type Params = Promise<{ id: string }>;
type SearchParams = Promise<Record<string, string | string[] | undefined>>;

/**
 * /__design/<id>?state=&theme=&chrome=0&variant=: one screen in one state.
 * The params are request data, so under Cache Components they are read
 * inside a Suspense boundary, not in the page body.
 */
export default function DesignScreenPage(props: { params: Params; searchParams: SearchParams }) {
  if (!galleryEnabled()) notFound();
  return (
    <Suspense
      fallback={
        <p role="status" aria-live="polite" className="px-4 py-8">
          Loading the screen
        </p>
      }
    >
      <Screen {...props} />
    </Suspense>
  );
}

async function Screen({ params, searchParams }: { params: Params; searchParams: SearchParams }) {
  const { id } = await params;
  const search = parseGallerySearch(await searchParams);
  return <GalleryScreen id={id} search={search} />;
}
