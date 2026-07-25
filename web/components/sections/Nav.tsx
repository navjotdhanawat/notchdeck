// Sticky top nav: wordmark (serif "Notch" in accent), in-page links, and a small
// Download CTA. Pure CSS sticky; condenses gracefully on narrow screens.

export function Nav() {
  return (
    <nav className="sticky top-0 z-50 w-full border-b border-white/[0.04] bg-surface-top/70 backdrop-blur-xl backdrop-saturate-150">
      <div className="mx-auto flex h-16 max-w-[1120px] items-center justify-between gap-6 px-6">
        {/* wordmark */}
        <a
          href="#"
          style={{ fontFamily: "var(--font-serif)" }}
          className="shrink-0 text-[20px] font-normal tracking-tight text-text-primary transition-colors hover:text-accent"
        >
          Claude<em className="text-accent not-italic">Notch</em>
        </a>

        {/* in-page links */}
        <div className="hidden items-center gap-1 sm:flex">
          <NavLink href="#features">Features</NavLink>
          <NavLink href="#act">Act in place</NavLink>
          <NavLink href="#themes">Themes</NavLink>
          <NavLink href="#roadmap">Roadmap</NavLink>
        </div>

        {/* Download CTA */}
        <a
          href="#download"
          className="shrink-0 rounded-full border border-border-c px-4 py-1.5 text-[13px] font-medium text-text-primary transition-[transform,border-color,background-color] duration-200 hover:-translate-y-px hover:border-white/25 hover:bg-white/[0.06] active:translate-y-0"
        >
          Download
        </a>
      </div>
    </nav>
  );
}

function NavLink({ href, children }: { href: string; children: string }) {
  return (
    <a
      href={href}
      className="rounded-md px-3 py-2 text-[13px] font-medium text-text-secondary transition-colors hover:text-text-primary"
    >
      {children}
    </a>
  );
}
