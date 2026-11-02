import type { LanguageCode } from "./data/init";
import type { FormatOptions } from "./numbers/numberFormatter";
import type { PluralizationCount } from "./numbers/pluralization";

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
 * The translation types of a {@link Localize} instance.
 */
export interface TypeOptions {
    /**
     * The translations of each namespace.
     */
    translations: Record<string, Record<string, string>>;
    /**
     * The namespace of keys without one. Defaults to `"translation"`.
     */
    defaultNamespace?: string;
    /**
     * Separates a namespace from a key. Defaults to `":"`.
     */
    namespaceSeparator?: string | false;
    /**
     * Separates a key from its plural form. Defaults to `"_"`.
     */
    pluralSeparator?: string;
}

/**
 * The translation types of a {@link Localize} instance without any.
 */
export interface DefaultTypeOptions {
    translations: { translation: Record<string, string> };
}

type TranslationsOf<Types> = Types extends { translations: infer Value }
    ? Value
    : never;

type DefaultNamespaceOf<Types> = Types extends {
    defaultNamespace: infer Value extends string;
}
    ? Value
    : "translation";

type NamespaceSeparatorOf<Types> = Types extends {
    namespaceSeparator: infer Value extends string | false;
}
    ? Value
    : ":";

type PluralSeparatorOf<Types> = Types extends {
    pluralSeparator: infer Value extends string;
}
    ? Value
    : "_";

type OrdinalBase<Key, Separator extends string> = {
    [Rule in PluralizationCount]: Key extends `${infer Base}${Separator}ordinal${Separator}${Rule}`
        ? Base
        : never;
}[PluralizationCount];

type CardinalBase<Key, Separator extends string> = {
    [Rule in PluralizationCount]: Key extends `${infer Base}${Separator}${Rule}`
        ? Base
        : never;
}[PluralizationCount];

type StripPlural<Key, Separator extends string> = Key extends string
    ? [OrdinalBase<Key, Separator>] extends [never]
        ? [CardinalBase<Key, Separator>] extends [never]
            ? Key
            : CardinalBase<Key, Separator>
        : OrdinalBase<Key, Separator>
    : never;

type OrdinalOnlyKeys<Translations, Separator extends string> = Exclude<
    OrdinalBase<keyof Translations, Separator>,
    StripPlural<
        Exclude<
            keyof Translations,
            `${string}${Separator}ordinal${Separator}${PluralizationCount}`
        >,
        Separator
    >
>;

type WithNamespace<Types, Namespace extends string, Key extends string> =
    | (NamespaceSeparatorOf<Types> extends string
          ? `${Namespace}${NamespaceSeparatorOf<Types>}${Key}`
          : never)
    | (Namespace extends DefaultNamespaceOf<Types> ? Key : never);

/**
 * A key of `t` for the given translation types.
 */
export type TranslationKey<Types extends TypeOptions = DefaultTypeOptions> = {
    [Namespace in keyof TranslationsOf<Types> & string]: WithNamespace<
        Types,
        Namespace,
        StripPlural<
            keyof TranslationsOf<Types>[Namespace],
            PluralSeparatorOf<Types>
        >
    >;
}[keyof TranslationsOf<Types> & string];

/**
 * A key of `t` that only has ordinal plural forms.
 */
export type OrdinalTranslationKey<
    Types extends TypeOptions = DefaultTypeOptions,
> = {
    [Namespace in keyof TranslationsOf<Types> & string]: WithNamespace<
        Types,
        Namespace,
        OrdinalOnlyKeys<
            TranslationsOf<Types>[Namespace],
            PluralSeparatorOf<Types>
        >
    >;
}[keyof TranslationsOf<Types> & string];

type TypedOptions<Types extends TypeOptions> =
    string extends TranslationKey<Types>
        ? unknown
        : (DefaultNamespaceOf<Types> extends "translation"
              ? { defaultNamespace?: "translation" }
              : { defaultNamespace: DefaultNamespaceOf<Types> }) &
              (NamespaceSeparatorOf<Types> extends ":"
                  ? { namespaceSeparator?: ":" }
                  : { namespaceSeparator: NamespaceSeparatorOf<Types> }) &
              (PluralSeparatorOf<Types> extends "_"
                  ? { pluralSeparator?: "_" }
                  : { pluralSeparator: PluralSeparatorOf<Types> });

/**
 * An i18next-style translator.
 */
export interface Localize<Types extends TypeOptions = DefaultTypeOptions> {
    /**
     * The current language.
     */
    readonly language: LanguageCode;

    /**
     * Fires after the current language changes.
     */
    readonly LanguageChanged: RBXScriptSignal<(language: LanguageCode) => void>;

    /**
     * Translate a key.
     *
     * @param key The key, optionally prefixed with a namespace.
     * @param options The plural options and interpolation variables.
     * @returns The translation, or the key if there is none.
     */
    t<Key extends TranslationKey<Types>>(
        key: Key,
        ...options: [Extract<Key, OrdinalTranslationKey<Types>>] extends [never]
            ? [options?: TranslationOptions]
            : [options: TranslationOptions & { ordinal: true }]
    ): string;

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
    new <Types extends TypeOptions = DefaultTypeOptions>(
        options: LocalizeOptions & TypedOptions<Types>,
    ): Localize<Types>;
}

export const Localize: LocalizeConstructor;
