import { cx } from "class-variance-authority"
import { twMerge } from "tailwind-merge"

export fn cn(...inputs: ts { Parameters<typeof cx> }): String =>
  twMerge(cx(...inputs))
