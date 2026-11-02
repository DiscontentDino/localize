import type { LanguageCode } from "./data/init";
import type { FormatOptions } from "./numbers/numberFormatter";

export * from "./data/init";
export type { FormatOptions } from "./numbers/numberFormatter";
export { generateOperands, type Operands } from "./numbers/operands";
export type { PluralizationCount } from "./numbers/pluralization";

/**
 * The translations of a namespace, by key.
 */
export interface Translations {
    [key: string]: string;
}

/**
 * Loads the translations of a language and namespace on demand.
 */
export interface Backend {
    /**
     * Read the translations of a language and namespace. May yield.
     *
     * @param language The language.
     * @param namespace The namespace.
     * @returns The translations.
     */
    read: (language: LanguageCode, namespace: string) => Translations;
}

/**
 * Options for creating a {@link Localize} instance.
 */
export interface LocalizeOptions {
    /**
     * The current language.
     */
    language: LanguageCode;
    /**
     * The language to use when a key is missing from the current language.
     */
    fallbackLanguage?: LanguageCode;
    /**
     * The namespaces to load. Defaults to `[defaultNamespace]`.
     */
    namespaces?: string[];
    /**
     * The namespace of keys without one. Defaults to the first of `namespaces`,
     * or `"translation"`.
     */
    defaultNamespace?: string;
    /**
     * Loads the translations.
     */
    backend: Backend;
    /**
     * Separates a key from its plural form. Defaults to `"_"`.
     */
    pluralSeparator?: string;
    /**
     * Separates a namespace from a key. Defaults to `":"`, `false` disables
     * namespaces in keys.
     */
    namespaceSeparator?: string | false;
}

/**
 * Options for a lookup. All entries are available to interpolation.
 */
export interface TranslationOptions {
    /**
     * The number that selects a plural form.
     */
    count?: number;
    /**
     * Whether `count` selects an ordinal plural form.
     */
    ordinal?: boolean;
    [variable: string]: unknown;
}

/**
 * An i18next-style translator.
 */
export interface Localize {
    /**
     * The current language.
     */
    readonly language: LanguageCode;

    /**
     * Translate a key.
     *
     * @param key The key, optionally prefixed with a namespace.
     * @param options The plural options and interpolation variables.
     * @returns The translation, or the key if there is none.
     */
    t(key: string, options?: TranslationOptions): string;

    /**
     * Change the current language.
     *
     * @yields based on the backend's `read` method.
     * @param language The language to change to.
     */
    changeLanguage(language: LanguageCode): void;

    /**
     * Load the current namespaces of languages through the backend.
     *
     * @yields based on the backend's `read` method.
     * @param languages The language or languages to load.
     */
    loadLanguages(languages: LanguageCode | LanguageCode[]): void;

    /**
     * Add and load namespaces through the backend.
     *
     * @yields based on the backend's `read` method.
     * @param namespaces The namespace or namespaces to add.
     */
    loadNamespaces(namespaces: string | string[]): void;

    /**
     * Format a number for the current language.
     *
     * @param value The number to format.
     * @param options How to format the number.
     * @returns The formatted number.
     */
    formatNumber(value: number, options?: FormatOptions): string;
}

/**
 * Creates {@link Localize} instances.
 */
export interface LocalizeConstructor {
    /**
     * Create a {@link Localize} instance and load its language.
     *
     * @yields based on the backend's `read` method.
     * @param options The options.
     * @returns The instance.
     */
    new (options: LocalizeOptions): Localize;
}

export const Localize: LocalizeConstructor;
