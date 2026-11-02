/**
 * Options controlling how a number is formatted.
 */
export interface FormatOptions {
    /**
     * Whether to shorten large numbers, as in "1.2K".
     */
    notation?: "standard" | "compact";
    /**
     * Whether compact numbers use "1.2K" or "1.2 thousand".
     */
    compactDisplay?: "short" | "long";
    /**
     * The minimum number of fraction digits.
     */
    minimumFractionDigits?: number;
    /**
     * The maximum number of fraction digits.
     */
    maximumFractionDigits?: number;
    /**
     * Whether to group digits.
     */
    useGrouping?: boolean;
}
