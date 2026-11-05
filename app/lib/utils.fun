import { cx } from "class-variance-authority"
import { twMerge } from "tailwind-merge"

export cn = (first: String, second: String) => twMerge(cx(first, second))
