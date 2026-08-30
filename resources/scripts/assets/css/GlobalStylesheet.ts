import tw from 'twin.macro';
import { createGlobalStyle } from 'styled-components/macro';
// @ts-expect-error untyped font file
import font from '@fontsource-variable/ibm-plex-sans/files/ibm-plex-sans-latin-wght-normal.woff2';

export default createGlobalStyle`
    @font-face {
        font-family: 'IBM Plex Sans';
        font-style: normal;
        font-display: swap;
        font-weight: 100 700;
        src: url(${font}) format('woff2-variations');
        unicode-range: U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD;
    }

    :root {
        --jz-bg: #080b12;
        --jz-surface: #0f1420;
        --jz-surface-2: #151b29;
        --jz-border: rgba(148, 163, 184, 0.14);
        --jz-text: #e7edf7;
        --jz-muted: #8d9ab0;
        --jz-primary: #6366f1;
        --jz-primary-2: #06b6d4;
        --jz-success: #22c55e;
        --jz-danger: #ef4444;
        --jz-warning: #f59e0b;
        --jz-shadow: 0 18px 50px rgba(0, 0, 0, 0.24);
    }

    :root[data-theme='light'] {
        --jz-bg: #f4f7fb;
        --jz-surface: #ffffff;
        --jz-surface-2: #eef2f8;
        --jz-border: rgba(15, 23, 42, 0.10);
        --jz-text: #101828;
        --jz-muted: #667085;
        --jz-shadow: 0 18px 50px rgba(15, 23, 42, 0.08);
    }

    html, body, #app { min-height: 100%; }

    body {
        ${tw`font-sans`};
        background: var(--jz-bg);
        color: var(--jz-text);
        letter-spacing: 0.015em;
        transition: background-color 180ms ease, color 180ms ease;
    }

    ::selection { background: rgba(99, 102, 241, 0.28); }

    @media (prefers-reduced-motion: reduce) {
        *, *::before, *::after {
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: 0.01ms !important;
            scroll-behavior: auto !important;
        }
    }

    :root[data-theme='light'] .bg-neutral-900 { background-color: var(--jz-surface) !important; }
    :root[data-theme='light'] .bg-neutral-800 { background-color: var(--jz-bg) !important; }
    :root[data-theme='light'] .bg-neutral-700 { background-color: var(--jz-surface-2) !important; }
    :root[data-theme='light'] .text-neutral-100,
    :root[data-theme='light'] .text-neutral-200,
    :root[data-theme='light'] .text-neutral-300 { color: var(--jz-text) !important; }
    :root[data-theme='light'] .text-neutral-400,
    :root[data-theme='light'] .text-neutral-500,
    :root[data-theme='light'] .text-neutral-600 { color: var(--jz-muted) !important; }
    :root[data-theme='light'] input, :root[data-theme='light'] textarea, :root[data-theme='light'] select { background-color: var(--jz-surface) !important; color: var(--jz-text) !important; border-color: var(--jz-border) !important; }

    h1, h2, h3, h4, h5, h6 {
        ${tw`font-medium tracking-normal font-header`};
    }

    p {
        ${tw`text-neutral-200 leading-snug font-sans`};
    }

    form {
        ${tw`m-0`};
    }

    textarea, select, input, button, button:focus, button:focus-visible {
        ${tw`outline-none`};
    }

    input[type=number]::-webkit-outer-spin-button,
    input[type=number]::-webkit-inner-spin-button {
        -webkit-appearance: none !important;
        margin: 0;
    }

    input[type=number] {
        -moz-appearance: textfield !important;
    }

    /* Scroll Bar Style */
    ::-webkit-scrollbar {
        background: none;
        width: 16px;
        height: 16px;
    }

    ::-webkit-scrollbar-thumb {
        border: solid 0 rgb(0 0 0 / 0%);
        border-right-width: 4px;
        border-left-width: 4px;
        -webkit-border-radius: 9px 4px;
        -webkit-box-shadow: inset 0 0 0 1px hsl(211, 10%, 53%), inset 0 0 0 4px hsl(209deg 18% 30%);
    }

    ::-webkit-scrollbar-track-piece {
        margin: 4px 0;
    }

    ::-webkit-scrollbar-thumb:horizontal {
        border-right-width: 0;
        border-left-width: 0;
        border-top-width: 4px;
        border-bottom-width: 4px;
        -webkit-border-radius: 4px 9px;
    }

    ::-webkit-scrollbar-corner {
        background: transparent;
    }
`;
