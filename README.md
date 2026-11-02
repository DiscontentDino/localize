# `localize`

[![npm version](https://img.shields.io/npm/v/@rbxts/localize)](https://www.npmjs.com/package/@rbxts/localize)
[![npm downloads](https://img.shields.io/npm/dm/@rbxts/localize)](https://www.npmjs.com/package/@rbxts/localize)
[![license](https://img.shields.io/npm/l/@rbxts/localize)](https://github.com/DiscontentDino/localize/blob/main/LICENSE.md)

`localize` is a runtime internationalization (i18n) and localization library for
Roblox, inspired by i18next. Define your translations as data and resolve them
at runtime!

## Why `localize`

Roblox's automatic translation renders the same string inconsistently within a
single language.

Example: when localizing the string "Spectating {username}", it sometimes
renders as "正在观看 Player A", "正在观战 Player B", or worse, just leaves it in
English. This is because Roblox's automatic translation solution isn't aware of
parameters, so it can't consistently translate the same string with different
parameters.

## Quick Start

### Installation

With Wally:

```toml
[dependencies]
localize = "discontentdino/localize@2.0.0"
```

With roblox-ts:

```bash
pnpm add @rbxts/localize
```

### Usage

Translations come from a `backend`. Its `read` function returns the translations
for a language and namespace, and it may yield.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Localize = require(ReplicatedStorage.Packages.localize)

local translations = {
    en_US = {
        translation = {
            greeting = "Hello {{name}}",
            apples_one = "You have {{count}} apple",
            apples_other = "You have {{count}} apples",
            place_ordinal_one = "You came in {{count}}st place",
            place_ordinal_two = "You came in {{count}}nd place",
            place_ordinal_few = "You came in {{count}}rd place",
            place_ordinal_other = "You came in {{count}}th place",
            coins_one = "{{count, number(notation: compact)}} coin",
            coins_other = "{{count, number(notation: compact)}} coins",
        },
        shop = { buy = "Buy" },
    },
    zh_CN = {
        translation = {
            greeting = "你好，{{name}}",
            apples_other = "你有{{count}}个苹果",
        },
        shop = { buy = "购买" },
    },
}

local i18n = Localize.new({
    language = "en_US",
    fallbackLanguage = "en_US",
    namespaces = { "translation", "shop" },
    backend = {
        read = function(language, namespace)
            return translations[language][namespace]
        end,
    },
})

i18n:t("greeting", { name = "Jo" }) -- Hello Jo
```

The same thing in roblox-ts:

```ts
import { Localize } from "@rbxts/localize";

const i18n = new Localize({
    language: "en_US",
    backend: {
        read: () => ({ greeting: "Hello {{name}}" }),
    },
});

print(i18n.t("greeting", { name: "Jo" })); // Hello Jo
```

## Plurals

Pass `count` to select a plural form. Keys end in a CLDR category: `_zero`,
`_one`, `_two`, `_few`, `_many` or `_other`. Each language only needs the
categories it uses. Change the `_` with the `pluralSeparator` option.

```lua
i18n:t("apples", { count = 1 }) -- You have 1 apple
i18n:t("apples", { count = 2 }) -- You have 2 apples
```

A lookup tries `key_<category>`, then `key_other`, then `key`, and then the same
in the fallback language using that language's rules.

For ordinals, pass `ordinal = true` and use `_ordinal_<category>` keys:

```lua
i18n:t("place", { count = 1, ordinal = true }) -- You came in 1st place
i18n:t("place", { count = 2, ordinal = true }) -- You came in 2nd place
i18n:t("place", { count = 3, ordinal = true }) -- You came in 3rd place
i18n:t("place", { count = 11, ordinal = true }) -- You came in 11th place
```

## Namespaces

`:` selects a namespace, and keys without one use the default namespace. The key
itself is returned when the key is missing.

```lua
i18n:t("shop:buy") -- Buy
i18n:t("missing") -- missing
```

Change the `:` with the `namespaceSeparator` option, or set it to `false` to
turn it off.

## Typed Keys

In roblox-ts, pass your translations as a type argument to check the keys of
`t`. Keys with only `_ordinal_` forms then need `ordinal: true`.

```ts
import type shop from "./locales/en_US/shop.json";
import type translation from "./locales/en_US/translation.json";

const i18n = new Localize<{
    translations: { translation: typeof translation; shop: typeof shop };
}>({
    language: "en_US",
    namespaces: ["translation", "shop"],
    backend,
});

i18n.t("apples", { count: 2 }); // ok
i18n.t("place", { count: 1, ordinal: true }); // ok
i18n.t("shop:buy"); // ok
i18n.t("missing"); // error
i18n.t("place"); // error
```

The type argument also takes `defaultNamespace`, `namespaceSeparator` and
`pluralSeparator`. When it sets one, the options must set it to the same value.

## Interpolation

`{{name}}` inserts a variable, and a missing variable stays as written. Use
`\{{` for a literal `{{` and `\\` for a literal backslash.

## Number Formatting

Format a number for the current language:

```lua
i18n:formatNumber(1234.5) -- 1,234.5
i18n:formatNumber(1500000, { notation = "compact" }) -- 1.5M
i18n:formatNumber(1500, { notation = "compact", compactDisplay = "long" })
    -- 1.5 thousand
i18n:formatNumber(2, { minimumFractionDigits = 2 }) -- 2.00
```

Or format it inside a translation with `{{variable, number}}`. Separate multiple
options with `;`.

```lua
i18n:t("coins", { count = 1 }) -- 1 coin
i18n:t("coins", { count = 1500 }) -- 1.5K coins
```

The options are `notation`, `compactDisplay`, `minimumFractionDigits`,
`maximumFractionDigits` and `useGrouping`.

## Languages

Change language with `changeLanguage`. It yields until the backend has loaded
the language.

```lua
i18n:changeLanguage("zh_CN")
i18n:t("apples", { count = 1 }) -- 你有1个苹果
i18n:formatNumber(15000, { notation = "compact" }) -- 1.5万
```

`LanguageChanged` fires after the language changes, so you can refresh your UI:

```lua
local connection = i18n.LanguageChanged:Connect(function(language)
    print(language)
end)

connection:Disconnect()
```

Languages use codes like `en_US`, not Roblox's `LocaleId`. Convert a `LocaleId`
with `robloxLocaleIdToLanguageCode`, which returns `nil` if it isn't supported:

```lua
local LocalizationService = game:GetService("LocalizationService")

local localeId = LocalizationService.RobloxLocaleId
i18n:changeLanguage(Localize.robloxLocaleIdToLanguageCode(localeId) or "en_US")
```

Add namespaces later with `loadNamespaces`, or preload languages with
`loadLanguages`.

## Supported Languages

| Language | Code | Roblox `LocaleId` |
| --- | --- | --- |
| German | `de_DE` | `de-de` |
| English (United Kingdom) | `en_GB` | `en-gb` |
| English (United States) | `en_US` | `en-us` |
| Spanish (Spain) | `es_ES` | `es-es` |
| French (France) | `fr_FR` | `fr-fr` |
| Indonesian | `id_ID` | `id-id` |
| Italian | `it_IT` | `it-it` |
| Japanese | `ja_JP` | `ja-jp` |
| Korean | `ko_KR` | `ko-kr` |
| Malay | `ms_MY` | `ms-my` |
| Polish | `pl_PL` | `pl-pl` |
| Portuguese (Brazil) | `pt_BR` | `pt-br` |
| Russian | `ru_RU` | `ru-ru` |
| Thai | `th_TH` | `th-th` |
| Turkish | `tr_TR` | `tr-tr` |
| Vietnamese | `vi_VN` | `vi-vn` |
| Chinese (Simplified) | `zh_CN` | `zh-cn` |
| Chinese (Traditional) | `zh_TW` | `zh-tw` |

Any other language logs a warning and only uses `_other` plural keys.

## Migrating from v1

| v1 | v2 |
| --- | --- |
| `new Localizer(provider)` | `new Localize({ language, backend })` |
| `LocalizationProvider` class | `backend = { read = function(language, namespace) ... end }` |
| `localizer.setLanguage(LanguageCode.en_US)` | `i18n.changeLanguage("en_US")`, which yields |
| `localizer.getLanguage()` | `i18n.language` |
| `localizer.languageChangedSignal.Event` | `i18n.LanguageChanged` |
| `localizer.localize(key, { $count: 1 })` | `i18n.t(key, { count: 1 })` |
| `{ $ordinal: true }` | `{ ordinal: true }` |
| `{{$count}}` | `{{count}}` |
| `apples:one`, `apples:other` | `apples_one`, `apples_other` |
| `place:ordinal:one` | `place_ordinal_one` |
| `LanguageCode.en_US` | `"en_US"` |
| `ROBLOX_LANGUAGE_CODE_MAP[localeId]` | `robloxLocaleIdToLanguageCode(localeId)` |
| `LANGUAGE_CODE_ROBLOX_MAP[code]` | `LanguageMetadata[code].robloxLocaleId` |


- **`:` in keys:** this now selects a namespace. If your keys contain it, set
  `namespaceSeparator` to `false`.
- **Plural fallback:** without a `count`, `apples` no longer falls back to
  `apples:other`, so add a plain `apples` key if you need one.
- **Missing variables:** these stay as `{{name}}` instead of printing `(nil)`.
- **Removed:**
  - `getLookupKeyName`
  - `parseInterpolatable`
  - `interpolate`
  - `getKey`
  - `PLURALIZATION_RULES`
