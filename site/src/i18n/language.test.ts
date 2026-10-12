import {
	isLanguage,
	LANGUAGE_STORAGE_KEY,
	readStoredLanguage,
	writeStoredLanguage,
} from "./language";

const clearStoredLanguage = () => {
	window.localStorage.removeItem(LANGUAGE_STORAGE_KEY);
};

afterEach(clearStoredLanguage);

describe("language storage", () => {
	it("returns the stored language when valid", () => {
		window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "en");
		expect(readStoredLanguage()).toBe("en");
	});

	it("falls back to English in tests when nothing is stored", () => {
		clearStoredLanguage();
		expect(readStoredLanguage()).toBe("en");
	});

	it("falls back to English when the stored value is invalid", () => {
		window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "klingon");
		expect(readStoredLanguage()).toBe("en");
	});

	it("writes the language to storage", () => {
		writeStoredLanguage("zh");
		expect(window.localStorage.getItem(LANGUAGE_STORAGE_KEY)).toBe("zh");
	});

	it("validates language values", () => {
		expect(isLanguage("en")).toBe(true);
		expect(isLanguage("zh")).toBe(true);
		expect(isLanguage("fr")).toBe(false);
		expect(isLanguage(null)).toBe(false);
	});
});
