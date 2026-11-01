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

## Supported Languages

- German
- English (US)
- Spanish (Spain)
- French (France)
- Indonesian
- Italian
- Japanese
- Korean
- Polish
- Portuguese (Brazil)
- Russian
- Thai
- Turkish
- Vietnamese
- Chinese (Simplified)
- Chinese (Traditional)
