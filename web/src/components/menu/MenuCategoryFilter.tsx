'use client';

import { RemoteImage } from '@/components/ui/RemoteImage';
import type { MenuCategoryEntry } from '@/lib/menuCategoryMeta';

type Props = {
  categories: MenuCategoryEntry[];
  selectedKey: string | null;
  onSelect: (key: string | null) => void;
};

const CARD_WIDTH = 126;
const CARD_HEIGHT = 50;

function CategoryCard({
  label,
  iconUrl,
  selected,
  onTap,
}: {
  label: string;
  iconUrl: string | null;
  selected: boolean;
  onTap: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onTap}
      className={`flex h-[50px] w-[126px] shrink-0 items-center overflow-hidden rounded-[14px] bg-white text-start transition active:scale-[0.98] ${
        selected
          ? 'border-2 border-gray-900 shadow-[0_3px_10px_rgba(0,0,0,0.12)]'
          : 'border-2 border-transparent shadow-[0_3px_5px_rgba(0,0,0,0.04)]'
      }`}
    >
      <span className="flex h-[50px] w-[50px] shrink-0 items-center justify-center overflow-hidden bg-gray-100">
        {iconUrl ? (
          <RemoteImage
            src={iconUrl}
            alt=""
            width={50}
            height={50}
            className="h-full w-full object-cover"
            fallbackClassName="h-full w-full"
          />
        ) : (
          <span className="text-xl" aria-hidden>
            🍽
          </span>
        )}
      </span>
      <span className="min-w-0 flex-1 px-1.5 text-center text-[11px] font-bold leading-tight text-gray-900">
        {label}
      </span>
    </button>
  );
}

export function MenuCategoryFilter({ categories, selectedKey, onSelect }: Props) {
  if (!categories.length) return null;

  return (
    <section className="-mx-4">
      <div className="flex gap-2 overflow-x-auto overscroll-x-contain px-4 py-0.5 scrollbar-none">
        {categories.map((entry) => (
          <CategoryCard
            key={entry.key}
            label={entry.label}
            iconUrl={entry.iconUrl}
            selected={selectedKey === entry.key}
            onTap={() => onSelect(selectedKey === entry.key ? null : entry.key)}
          />
        ))}
      </div>
    </section>
  );
}

export { CARD_WIDTH, CARD_HEIGHT };
