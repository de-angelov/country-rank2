import { cx } from "class-variance-authority"
import { twMerge } from "tailwind-merge"

export cn = (...inputs: Parameters<typeof cx>): String =>
  twMerge(cx(...inputs))
