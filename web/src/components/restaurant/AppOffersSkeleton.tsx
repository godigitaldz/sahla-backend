export function AppOffersSkeleton() {
  return (
    <div className="relative -mx-4 mt-2 overflow-hidden bg-[#F8EDED] py-7">
      <div className="px-4">
        <div className="mb-3 h-5 w-52 animate-pulse rounded-md bg-white/80" />
        <div className="flex gap-2.5 overflow-hidden">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className="h-[168px] w-[calc((100vw-3rem)/2.35)] max-w-[148px] shrink-0 animate-pulse rounded-xl bg-white/85"
            />
          ))}
        </div>
      </div>
    </div>
  );
}
