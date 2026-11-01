import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ordinals from "cldr-core/supplemental/ordinals.json" with {
    type: "json",
};
import plurals from "cldr-core/supplemental/plurals.json" with { type: "json" };
import type { Language } from "./languages";

type Rules = Record<string, string>;

const cardinal: Record<string, Rules> =
    plurals.supplemental["plurals-type-cardinal"];
const ordinal: Record<string, Rules> =
    ordinals.supplemental["plurals-type-ordinal"];

/**
 * The non-"other" categories, in the order they are tested. "other" is the
 * default and never carries a condition.
 */
const CATEGORIES = ["zero", "one", "two", "few", "many"] as const;

/**
 * Strip the `@integer`/`@decimal` samples from a CLDR rule.
 *
 * @param rule The raw CLDR rule string.
 * @returns The bare condition, or an empty string when the rule is only
 * samples.
 */
const condition = (rule: string): string => {
    const at = rule.indexOf("@");
    return (at === -1 ? rule : rule.slice(0, at)).trim();
};

/**
 * Compile a single value or an integer range against a left-hand side.
 *
 * @param lhs The compiled left-hand-side expression.
 * @param term The CLDR value (`5`) or range (`2..4`) to test.
 * @returns The Luau boolean expression.
 */
const compileTerm = (lhs: string, term: string): string => {
    const dots = term.indexOf("..");
    if (dots === -1) {
        return `${lhs} == ${term}`;
    }
    const low = term.slice(0, dots);
    const high = term.slice(dots + 2);
    return `(${lhs} >= ${low} and ${lhs} <= ${high} and ${lhs} % 1 == 0)`;
};

/**
 * Compile one CLDR relation, for example `i % 10 = 2..4` or `n != 0,1`.
 *
 * @param relation The CLDR relation.
 * @returns The Luau boolean expression.
 */
const compileRelation = (relation: string): string => {
    const negated = relation.includes("!=");
    const parts = relation.split(negated ? "!=" : "=");
    const expr = parts[0].trim();

    const percent = expr.indexOf("%");
    const lhs =
        percent === -1
            ? `operands.${expr}`
            : `(operands.${expr.slice(0, percent).trim()} % ${expr
                  .slice(percent + 1)
                  .trim()})`;

    const terms = parts[1]
        .trim()
        .split(",")
        .map((term) => compileTerm(lhs, term.trim()));
    const joined = terms.length === 1 ? terms[0] : terms.join(" or ");

    return negated ? `not (${joined})` : joined;
};

/**
 * Compile a full CLDR condition into a Luau boolean expression. "and" binds
 * tighter than "or", which matches Luau's own precedence.
 *
 * @param cond The CLDR condition.
 * @returns The Luau boolean expression.
 */
const compileCondition = (cond: string): string => {
    const groups = cond.split(" or ").map((group) =>
        group
            .trim()
            .split(" and ")
            .map((relation) => compileRelation(relation.trim()))
            .join(" and "),
    );
    return groups.length === 1
        ? groups[0]
        : groups.map((group) => `(${group})`).join(" or ");
};

/**
 * Emit an anonymous Luau selector that returns the plural category. Absent
 * rules (a language with no ordinal rules) yield an "other"-only selector.
 *
 * @param rules The CLDR rules for the language and kind, if any.
 * @param indent The indentation of the line the function literal starts on.
 * @returns The Luau source for the selector function.
 */
const compileSelector = (rules: Rules | undefined, indent: string): string => {
    const body: string[] = [];
    for (const category of CATEGORIES) {
        const cond = condition(rules?.[`pluralRule-count-${category}`] ?? "");
        if (cond === "") {
            continue;
        }
        body.push(
            `${indent}    if ${compileCondition(cond)} then return "${category}" end`,
        );
    }
    body.push(`${indent}    return "other"`);

    return [
        "function(operands: Operands): PluralizationCount",
        ...body,
        `${indent}end`,
    ].join("\n");
};

/**
 * Format the plural categories a rule set uses as a Luau array literal.
 *
 * @param rules The CLDR rules for the language and kind, if any.
 * @returns The Luau array literal, always including `"other"`.
 */
const formatCounts = (rules: Rules | undefined): string => {
    const used = CATEGORIES.filter(
        (category) => rules?.[`pluralRule-count-${category}`] !== undefined,
    );
    return `{ ${[...used, "other"].map((count) => `"${count}"`).join(", ")} }`;
};

/**
 * Compact patterns for a locale, by magnitude then plural count.
 */
type CompactPatterns = { [magnitude: string]: { [count: string]: string } };

/**
 * Parse CLDR's flat `1000-count-other` compact keys into a nested map.
 *
 * @param raw The CLDR compact format object.
 * @returns The nested `{ magnitude: { count: pattern } }` map.
 */
const parseCompact = (raw: Record<string, string>): CompactPatterns => {
    const result: CompactPatterns = {};
    for (const [key, pattern] of Object.entries(raw)) {
        const [magnitude, count] = key.split("-count-");
        if (count === undefined) {
            continue;
        }
        if (!result[magnitude]) result[magnitude] = {};
        result[magnitude][count] = pattern;
    }
    return result;
};

/**
 * Derive the grouping sizes from a CLDR standard pattern like `#,##0.###`.
 *
 * @param pattern The standard decimal pattern.
 * @returns The primary and secondary grouping sizes.
 */
const parseGrouping = (
    pattern: string,
): { primary: number; secondary: number } => {
    const groups = pattern.split(".")[0].split(",");
    const primary = groups[groups.length - 1].length;
    const secondary =
        groups.length > 2 ? groups[groups.length - 2].length : primary;
    return { primary, secondary };
};

/**
 * Load and shape the CLDR number formatting data for a locale.
 *
 * @param cldrCode The CLDR code to load.
 * @returns The number formatting data.
 */
const loadNumberFormatting = async (cldrCode: string) => {
    const data = await import(
        `cldr-numbers-full/main/${cldrCode}/numbers.json`,
        { with: { type: "json" } }
    );
    const numbers = data.default.main[cldrCode].numbers;
    const symbols = numbers["symbols-numberSystem-latn"];
    const decimalFormats = numbers["decimalFormats-numberSystem-latn"];
    return {
        symbols: {
            decimal: symbols.decimal,
            group: symbols.group,
            minusSign: symbols.minusSign,
            plusSign: symbols.plusSign,
            percentSign: symbols.percentSign,
            infinity: symbols.infinity,
            nan: symbols.nan,
        },
        grouping: parseGrouping(decimalFormats.standard),
        compact: {
            short: parseCompact(decimalFormats.short.decimalFormat),
            long: parseCompact(decimalFormats.long.decimalFormat),
        },
    };
};

/**
 * Serialize a JSON-like value to a Luau literal.
 *
 * @param value The value to serialize.
 * @param indent The indentation of the line the value starts on.
 * @returns The Luau source for the value.
 */
const toLuau = (value: unknown, indent: string): string => {
    if (typeof value === "number") {
        return String(value);
    }
    if (typeof value === "string") {
        return `"${value.replaceAll("\\", "\\\\").replaceAll('"', '\\"')}"`;
    }
    const entries = Object.entries(value as Record<string, unknown>).map(
        ([key, child]) =>
            `${indent}    ["${key}"] = ${toLuau(child, `${indent}    `)},`,
    );
    return `{\n${entries.join("\n")}\n${indent}}`;
};

/**
 * Build a per-language configuration module (`src/data/<code>.luau`).
 *
 * @param cldrCode The CLDR code to compile rules for.
 * @returns A success tuple with the Luau source, or a failure tuple when the
 * CLDR code has no cardinal rules.
 */
const createLanguageScript = async (
    cldrCode: string,
): Promise<
    [true, string] | [false, { code: "unknownCldrCode"; cldrCode: string }]
> => {
    // I hate my life.
    const cardinalRules =
        cardinal[cldrCode] ?? cardinal[cldrCode.split("-")[0]];
    if (cardinalRules === undefined) {
        return [false, { code: "unknownCldrCode", cldrCode }];
    }

    const ordinalRules = ordinal[cldrCode] ?? ordinal[cldrCode.split("-")[0]];
    const numberFormatting = await loadNumberFormatting(cldrCode);
    const indent = "        ";

    return [
        true,
        `--!strict
-- Generated by \`pnpm generate\`. Do not edit by hand.

local operandsModule = require("../numbers/operands")
local pluralizationModule = require("../numbers/pluralization")

type Operands = operandsModule.Operands
type PluralizationCount = pluralizationModule.PluralizationCount

return {
    pluralization = {
        cardinal = ${compileSelector(cardinalRules, indent)},
        cardinalCounts = ${formatCounts(cardinalRules)},
        ordinal = ${compileSelector(ordinalRules, indent)},
        ordinalCounts = ${formatCounts(ordinalRules)},
    },
    numberFormatting = ${toLuau(numberFormatting, "    ")},
}
`,
    ];
};

/**
 * Generate the per-language configuration modules under `src/data`.
 *
 * @param language The language to generate.
 * @returns A success tuple, or a failure tuple describing what went wrong.
 */
export const generateLanguageScript = async (
    language: Language,
): Promise<
    | [true]
    | [false, { code: "unknownCldrCode"; cldrCode: string }]
    | [false, { code: "writeFail"; error: Error }]
> => {
    const [scriptResult, script] = await createLanguageScript(
        language.cldrCode,
    );
    if (!scriptResult) return [false, script];

    const fileName = fileURLToPath(import.meta.url);
    const dirName = path.dirname(fileName);
    const outputDirectory = path.join(dirName, "..", "src", "data");

    try {
        mkdirSync(outputDirectory, { recursive: true });
        writeFileSync(
            path.join(outputDirectory, `${language.code}.luau`),
            script,
        );
    } catch (error) {
        return [
            false,
            {
                code: "writeFail",
                error:
                    error instanceof Error ? error : new Error(String(error)),
            },
        ];
    }

    return [true];
};
