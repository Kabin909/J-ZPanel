import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

export type ThemeMode = 'dark' | 'light' | 'system';

type ThemeContextValue = {
    mode: ThemeMode;
    setMode: (mode: ThemeMode) => void;
};

const ThemeContext = createContext<ThemeContextValue>({ mode: 'dark', setMode: () => undefined });

const STORAGE_KEY = 'jz-panel:appearance';

const getInitialMode = (): ThemeMode => {
    try {
        const value = window.localStorage.getItem(STORAGE_KEY);
        return value === 'light' || value === 'system' || value === 'dark' ? value : 'dark';
    } catch {
        return 'dark';
    }
};

export const useTheme = () => useContext(ThemeContext);

export default ({ children }: { children: React.ReactNode }) => {
    const [mode, setModeState] = useState<ThemeMode>(getInitialMode);

    const setMode = (next: ThemeMode) => {
        setModeState(next);
        try {
            window.localStorage.setItem(STORAGE_KEY, next);
        } catch {
            // Ignore storage failures (private browsing or disabled storage).
        }
    };

    useEffect(() => {
        const root = document.documentElement;
        const apply = () => {
            const resolved = mode === 'system'
                ? window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
                : mode;
            root.dataset.theme = resolved;
            root.style.colorScheme = resolved;
        };

        apply();
        if (mode !== 'system') return undefined;

        const media = window.matchMedia('(prefers-color-scheme: light)');
        if (media.addEventListener) {
            media.addEventListener('change', apply);
            return () => media.removeEventListener('change', apply);
        }
        media.addListener(apply);
        return () => media.removeListener(apply);
    }, [mode]);

    const value = useMemo(() => ({ mode, setMode }), [mode]);
    return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
};
