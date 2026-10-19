/** The visitor's appearance choice, kept in localStorage; `data-theme` on <html> is the resolved light or dark. */
export type ThemeChoice = 'system' | 'light' | 'dark'

const KEY = 'kakera-theme'

/**
 * Runs in <head> before the page paints (as a string, so it needs no bundle): applies the stored choice and follows
 * the system while the choice is "system". The switch calls the same code through `window.kakeraTheme`.
 */
export const THEME_SCRIPT = `(function(){var k='${KEY}',m=matchMedia('(prefers-color-scheme: dark)');function c(){try{var v=localStorage.getItem(k);return v==='light'||v==='dark'?v:'system'}catch(e){return 'system'}}function a(v){var d=v==='dark'||(v==='system'&&m.matches),r=document.documentElement;r.dataset.theme=d?'dark':'light';r.style.colorScheme=d?'dark':'light'}a(c());m.addEventListener('change',function(){a(c())});window.kakeraTheme={get:c,set:function(v){try{if(v==='system')localStorage.removeItem(k);else localStorage.setItem(k,v)}catch(e){}a(v)}}})()`

type ThemeApi = { get: () => ThemeChoice; set: (choice: ThemeChoice) => void }
const api = () => (globalThis as { kakeraTheme?: ThemeApi }).kakeraTheme

export const readTheme = (): ThemeChoice => api()?.get() ?? 'system'
export const setTheme = (choice: ThemeChoice) => api()?.set(choice)
