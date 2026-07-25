/** macOS system stack — the notch/menubar chrome reads as native, not serif. */
const SYS =
  "-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif";

/**
 * A macOS menu-bar strip: app menus on the left, a `right` slot on the right
 * (clock now; the ThemeSwitcher joins it in Task 7). Presentation-only — glassy
 * translucent dark so it reads over the Stage wallpaper (added in Task 6).
 */
export function MenuBar({ right }: { right?: React.ReactNode }) {
  return (
    <div
      style={{ fontFamily: SYS }}
      className="flex h-8 items-center justify-between bg-black/25 px-[13px] text-[12.5px] text-text-primary backdrop-blur-md"
    >
      <div className="flex items-center gap-[15px]">
        <span aria-hidden className="text-[13.5px]"></span>
        <span className="font-semibold">iTerm2</span>
        <span className="hidden font-normal text-text-secondary sm:inline">Shell</span>
        <span className="hidden font-normal text-text-secondary sm:inline">Edit</span>
        <span className="hidden font-normal text-text-secondary md:inline">View</span>
        <span className="hidden font-normal text-text-secondary md:inline">Window</span>
        <span className="hidden font-normal text-text-secondary md:inline">Help</span>
      </div>
      <div className="flex items-center gap-[13px]">{right}</div>
    </div>
  );
}
