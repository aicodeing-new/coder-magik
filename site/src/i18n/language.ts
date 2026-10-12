export type Language = "en" | "zh";

export const LANGUAGE_STORAGE_KEY = "coder:language";

export function isLanguage(value: string | null): value is Language {
	return value === "en" || value === "zh";
}

export function readStoredLanguage(): Language {
	const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
	if (isLanguage(stored)) {
		return stored;
	}
	// Unit tests, Storybook, and e2e (English-locale browsers) pin English
	// so assertions and baselines stay deterministic; Chinese browsers get
	// Chinese without a saved preference.
	if (import.meta.env.MODE === "test" || import.meta.env.STORYBOOK) {
		return "en";
	}
	return navigator.language.toLowerCase().startsWith("zh") ? "zh" : "en";
}

export function writeStoredLanguage(language: Language) {
	window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
}
