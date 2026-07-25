/** macOS system stack — the notch/menubar chrome reads as native, not serif. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/**
 * A macOS menu-bar strip with a centered camera-island cutout simulation.
 * The dark pill + camera dot at center mimics the MacBook Pro notch sitting
 * in the menubar, with menu items on the left and status items on the right.
 */
export function MenuBar({ right }: { right?: React.ReactNode }) {
  return (
    <div
      style={{ fontFamily: SYS }}
      className="relative z-0 flex h-8 items-center justify-between bg-black/25 px-[13px] text-[12.5px] text-text-primary backdrop-blur-md"
    >
      {/* Left menus */}
      <div className="flex items-center gap-[15px]">
        <span aria-hidden className="text-[13.5px]"></span>
        <span className="font-semibold">iTerm2</span>
        <span className="hidden font-normal text-text-secondary sm:inline">Shell</span>
        <span className="hidden font-normal text-text-secondary sm:inline">Edit</span>
        <span className="hidden font-normal text-text-secondary md:inline">View</span>
        <span className="hidden font-normal text-text-secondary md:inline">Window</span>
        <span className="hidden font-normal text-text-secondary md:inline">Help</span>
      </div>

      {/* Camera island — centered notch pill sitting in the menubar */}
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-0 -translate-x-1/2"
      >
        {/* Dark notch pill that extends down into the panel */}
        <div className="h-8 w-[130px] bg-surface-bottom" />
        {/* Camera dot centered in the pill */}
        <span
          className="absolute left-1/2 top-1/2 h-[6px] w-[6px] -translate-x-1/2 -translate-y-1/2 rounded-full"
          style={{
            background: "radial-gradient(circle at 35% 30%, #26324d, #000 70%)",
            boxShadow: "0 0 0 1px rgba(255,255,255,0.06)",
          }}
        />
      </div>

      {/* Right status items */}
      <div className="flex items-center gap-[13px]">{right}</div>
    </div>
  );
}
