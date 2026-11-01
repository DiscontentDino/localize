import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * A language to be supported.
 */
export interface Language {
    /**
     * The name of the language, in English.
     */
    name: string;
    /**
     * The name of the language, in the language itself.
     */
    nativeName: string;
    /**
     * The language code.
     */
    code: string;
    /**
     * The CLDR code.
     */
    cldrCode: string;
    /**
     * The Roblox `LocaleId`.
     */
    robloxLocaleId: string;
}

/**
 * Get the languages to generate.
 */
export const getLanguages = ():
    | [true, Language[]]
    | [false, { code: "fileReadFail"; error: Error }]
    | [false, { code: "emptyFile" }]
    | [false, { code: "malformedHeader"; found: string; expected: string }]
    | [false, { code: "malformedLine"; lineNumber: number; line: string }] => {
    // Get the path to the languages.csv file
    const fileName = fileURLToPath(import.meta.url);
    const dirName = path.dirname(fileName);
    const languagesFilePath = path.join(dirName, "..", "languages.csv");

    // Read the languages.csv file
    let fileContents: string;
    try {
        fileContents = readFileSync(languagesFilePath, "utf-8");
    } catch (error) {
        return [
            false,
            {
                code: "fileReadFail",
                error:
                    error instanceof Error ? error : new Error(String(error)),
            },
        ];
    }

    // Parse the languages.csv file
    const lines = fileContents.split("\n");
    const languages: Language[] = [];

    if (lines.length < 1)
        return [
            false,
            {
                code: "emptyFile",
            },
        ];

    // Check the header
    const header = lines[0].trim();
    const expectedHeader =
        "name,nativeName,languageCode,cldrCode,robloxLocaleId";
    if (header !== expectedHeader)
        return [
            false,
            {
                code: "malformedHeader",
                found: header,
                expected: expectedHeader,
            },
        ];

    // Parse the lines
    for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line === "") continue;

        const parts = line.split(",");
        if (parts.length !== 5)
            return [
                false,
                {
                    code: "malformedLine",
                    lineNumber: i + 1,
                    line,
                },
            ];

        const [name, nativeName, code, cldrCode, robloxLocaleId] = parts;
        languages.push({
            name,
            nativeName,
            code,
            cldrCode,
            robloxLocaleId,
        });
    }

    return [true, languages];
};
