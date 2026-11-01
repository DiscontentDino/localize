import { generateInitScripts } from "./generateInitScripts";
import { generateLanguageScript } from "./generateLanguageScripts";
import { getLanguages } from "./languages";

/**
 * Log a message to the console with a specific color based on the type.
 *
 * @param type
 * @param message
 */
const log = (type: "error" | "info" | "success", message: string): void => {
    const colorCodes = {
        error: "\x1b[31m", // Red
        info: "\x1b[34m", // Blue
        success: "\x1b[32m", // Green
    };
    const resetCode = "\x1b[0m"; // Reset color

    console.log(`${colorCodes[type]}${message}${resetCode}`);
};

/**
 * The main function.
 *
 * @returns The exit code of the program. 0 for success, anything else for
 *          failure.
 */
const main = async (): Promise<number> => {
    // Get the languages to generate
    const [languagesResult, languages] = getLanguages();
    if (!languagesResult) {
        switch (languages.code) {
            case "fileReadFail":
                log(
                    "error",
                    `Failed to read languages.csv: ${languages.error.message}`,
                );
                break;
            case "emptyFile":
                log("error", "languages.csv is empty.");
                break;
            case "malformedHeader":
                log(
                    "error",
                    `Malformed header in languages.csv. Found: ${languages.found}, Expected: ${languages.expected}`,
                );
                break;
            case "malformedLine":
                log(
                    "error",
                    `Malformed line in languages.csv at line ${languages.lineNumber}: ${languages.line}`,
                );
                break;
        }
        return 1;
    }

    const [generatedOk, generatedError] = generateInitScripts(languages);
    if (!generatedOk) {
        switch (generatedError.code) {
            case "writeFail":
                log(
                    "error",
                    `Failed to write output: ${generatedError.error.message}`,
                );
                break;
        }
        return 1;
    }

    for (const language of languages) {
        log(
            "info",
            `Generating data for language: ${language.code} (${language.name})`,
        );

        const [generationResult, generation] =
            await generateLanguageScript(language);
        if (!generationResult) {
            switch (generation.code) {
                case "writeFail":
                    log(
                        "error",
                        `Failed to write output for language ${language.code}: ${generation.error.message}`,
                    );
                    break;
                case "unknownCldrCode":
                    log(
                        "error",
                        `Unknown CLDR code for language ${language.code}: ${generation.cldrCode}`,
                    );
                    break;
            }
            return 1;
        }
    }

    log(
        "success",
        `Successfully generated init scripts and language data for ${languages.length} languages.`,
    );

    return 0;
};

main().then((exitCode) => process.exit(exitCode));
