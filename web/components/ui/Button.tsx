import type { HTMLAttributes, ReactNode } from "react";

/** Filled brand-accent CTA vs. a quiet bordered CTA. */
type Variant = "primary" | "ghost";

/**
 * Shared CTA primitive. Renders an `<a>` when `href` is given (navigation),
 * otherwise a `<button>` (actions). Both variants read entirely off theme
 * tokens, so every palette recolors the buttons. Extra DOM props (onClick,
 * aria-*, id, style, …) spread onto whichever element is rendered.
 */
type ButtonProps = {
  variant?: Variant;
  href?: string;
  children: ReactNode;
  className?: string;
  target?: string;
  rel?: string;
} & Omit<HTMLAttributes<HTMLElement>, "className" | "children">;

const BASE =
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full px-6 py-3 text-[14px] font-medium tracking-tight transition-[transform,filter,background-color,border-color] duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent/70";

const VARIANTS: Record<Variant, string> = {
  primary:
    "bg-accent text-on-accent shadow-[0_12px_34px_-12px_var(--accent)] hover:-translate-y-px hover:brightness-105 active:translate-y-0",
  ghost:
    "border border-border-c text-text-primary hover:-translate-y-px hover:border-white/25 hover:bg-white/[0.06] active:translate-y-0",
};

export function Button({
  variant = "primary",
  href,
  children,
  className = "",
  ...rest
}: ButtonProps) {
  const cls = `${BASE} ${VARIANTS[variant]} ${className}`.trim();

  if (href !== undefined) {
    return (
      <a href={href} className={cls} {...rest}>
        {children}
      </a>
    );
  }
  return (
    <button type="button" className={cls} {...rest}>
      {children}
    </button>
  );
}
