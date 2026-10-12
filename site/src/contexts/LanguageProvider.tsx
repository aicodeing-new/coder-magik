import "dayjs/locale/zh-cn";
import dayjs from "dayjs";
import {
	createContext,
	useCallback,
	useContext,
	useEffect,
	useState,
} from "react";
import { activateDomTranslator } from "#/i18n/domTranslator";
import {
	type Language,
	readStoredLanguage,
	writeStoredLanguage,
} from "#/i18n/language";
import { setHumanizeLanguage } from "#/utils/time";

type LanguageContextValue = Readonly<{
	language: Language;
	setLanguage: (language: Language) => void;
}>;

const LanguageContext = createContext<LanguageContextValue | undefined>(
	undefined,
);

export const LanguageProvider: React.FC<React.PropsWithChildren> = ({
	children,
}) => {
	const [language, setLanguageState] = useState(readStoredLanguage);

	useEffect(() => {
		document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
		dayjs.locale(language === "zh" ? "zh-cn" : "en");
		setHumanizeLanguage(language);
		if (language !== "zh") {
			return;
		}
		return activateDomTranslator();
	}, [language]);

	const setLanguage = useCallback(
		(next: Language) => {
			setLanguageState(next);
			if (next === language) {
				return;
			}
			// Reload so every string re-renders from source in the new
			// language; no reverse translation is needed.
			writeStoredLanguage(next);
			window.location.reload();
		},
		[language],
	);

	return (
		<LanguageContext.Provider value={{ language, setLanguage }}>
			{children}
		</LanguageContext.Provider>
	);
};

export function useLanguage(): LanguageContextValue {
	const context = useContext(LanguageContext);
	if (!context) {
		throw new Error("useLanguage must be used within a LanguageProvider");
	}
	return context;
}
