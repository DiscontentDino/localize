/**
 * CLDR plural operands (Unicode TR35).
 *
 * https://unicode.org/reports/tr35/tr35-numbers.html#Operands
 */
export interface Operands {
    /**
     * The absolute value of the number.
     */
    n: number;
    /**
     * The number as an integer.
     */
    i: number;
    /**
     * The number of visible fraction digits, with trailing zeros.
     *
     * Trailing zeros come from `fractionalDigits`, so `1.50` gives `v = 2`
     * while {@link w} gives `1`.
     */
    v: number;
    /**
     * The number of visible fraction digits, without trailing zeros.
     */
    w: number;
    /**
     * The visible fraction digits, with trailing zeros, as an integer.
     *
     * For `1.50` this is `50`, while {@link t} is `5`.
     */
    f: number;
    /**
     * The visible fraction digits, without trailing zeros, as an integer.
     */
    t: number;
    /**
     * The compact decimal exponent, the power of 10 used in compact formatting.
     *
     * It is 0 for a plainly-formatted number, and the suffix exponent when
     * compact-formatted:
     * * 1200 shown as "1.2K" -> c = 3
     * * 10100000 shown as "10.1M" -> c = 6
     */
    c: number;
    /**
     * A deprecated alias for {@link c}. This is kept for backwards
     * compatibility.
     *
     * The CLDR docs states that this may change in the future.
     */
    e: number;
}

/**
 * Generates a table with CLDR operands given a number, an optional
 * `fractionalDigits`, and an optional `compactExponent`.
 *
 * @param number The number that needs operands generated for. When compact
 *        formatted, this is the full value: 1200 for "1.2K".
 * @param fractionalDigits The number of visible fractional digits, rounding the
 *        number to fit. An example would be the following: 20.400 -> 3 and
 *        80.00 -> 2. Without it, the digits come from the number itself.
 * @param compactExponent The power of 10 used in compact formatting: 3 for
 *        "1.2K". Defaults to 0.
 * @returns A table with CLDR operands.
 */
export const generateOperands: (
    number: number,
    fractionalDigits?: number,
    compactExponent?: number,
) => Operands;
