import * as React from 'react';
import { useState } from 'react';
import { Link, NavLink } from 'react-router-dom';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faCogs, faLayerGroup, faSignOutAlt, faSun, faMoon, faDesktop } from '@fortawesome/free-solid-svg-icons';
import { useStoreState } from 'easy-peasy';
import { ApplicationStore } from '@/state';
import SearchContainer from '@/components/dashboard/search/SearchContainer';
import styled from 'styled-components/macro';
import http from '@/api/http';
import SpinnerOverlay from '@/components/elements/SpinnerOverlay';
import Tooltip from '@/components/elements/tooltip/Tooltip';
import Avatar from '@/components/Avatar';
import JzLogo from '@/components/JzLogo';
import { ThemeMode, useTheme } from '@/components/ThemeProvider';

const Bar = styled.header`
    position: sticky;
    top: 0;
    z-index: 50;
    width: 100%;
    background: color-mix(in srgb, var(--jz-surface) 94%, transparent);
    backdrop-filter: blur(18px);
    border-bottom: 1px solid var(--jz-border);
`;

const Inner = styled.div`
    width: min(1400px, calc(100% - 32px));
    min-height: 72px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    gap: 18px;
`;

const Action = styled.button`
    width: 40px;
    height: 40px;
    border: 1px solid var(--jz-border);
    border-radius: 11px;
    background: var(--jz-surface-2);
    color: var(--jz-muted);
    cursor: pointer;
    transition: transform 140ms ease, color 140ms ease, border-color 140ms ease, background 140ms ease;
    &:hover { color: var(--jz-text); border-color: rgba(99,102,241,.45); transform: translateY(-1px); }
    &:focus-visible { outline: 2px solid var(--jz-primary); outline-offset: 2px; }
`;

const NavAction = styled(Action).attrs({ as: 'div' })`
    display: grid;
    place-items: center;
    a { color: inherit; text-decoration: none; display: grid; place-items: center; width: 100%; height: 100%; }
`;

const ThemeMenu = styled.div`
    display: flex;
    align-items: center;
    gap: 3px;
    padding: 3px;
    border-radius: 13px;
    background: var(--jz-surface-2);
    border: 1px solid var(--jz-border);
    @media (max-width: 760px) { display: none; }
`;

const ThemeButton = styled.button<{ $active: boolean }>`
    width: 32px;
    height: 32px;
    border: 0;
    border-radius: 9px;
    color: ${({ $active }) => ($active ? 'var(--jz-text)' : 'var(--jz-muted)')};
    background: ${({ $active }) => ($active ? 'var(--jz-surface)' : 'transparent')};
    box-shadow: ${({ $active }) => ($active ? '0 4px 12px rgba(0,0,0,.12)' : 'none')};
    cursor: pointer;
`;

export default () => {
    const name = useStoreState((state: ApplicationStore) => state.settings.data!.name);
    const rootAdmin = useStoreState((state: ApplicationStore) => state.user.data!.rootAdmin);
    const [isLoggingOut, setIsLoggingOut] = useState(false);
    const { mode, setMode } = useTheme();

    const onTriggerLogout = () => {
        setIsLoggingOut(true);
        http.post('/auth/logout').finally(() => {
            // @ts-expect-error this is valid
            window.location = '/';
        });
    };

    const themeButtons: Array<[ThemeMode, any, string]> = [
        ['dark', faMoon, 'Dark'],
        ['light', faSun, 'Light'],
        ['system', faDesktop, 'System'],
    ];

    return (
        <Bar>
            <SpinnerOverlay visible={isLoggingOut} />
            <Inner>
                <Link to={'/'} style={{ color: 'var(--jz-text)', textDecoration: 'none', flex: '0 0 auto' }} aria-label="J&Z Panel home">
                    <JzLogo />
                </Link>
                <div style={{ flex: 1, minWidth: 0 }}><SearchContainer /></div>
                <ThemeMenu aria-label="Appearance">
                    {themeButtons.map(([value, icon, label]) => (
                        <Tooltip key={value} placement="bottom" content={label}>
                            <ThemeButton type="button" $active={mode === value} onClick={() => setMode(value)} aria-label={label}>
                                <FontAwesomeIcon icon={icon} />
                            </ThemeButton>
                        </Tooltip>
                    ))}
                </ThemeMenu>
                <NavAction><NavLink to={'/'} exact aria-label="Dashboard"><FontAwesomeIcon icon={faLayerGroup} /></NavLink></NavAction>
                {rootAdmin && <NavAction><a href={'/admin'} rel={'noreferrer'} aria-label="Administration"><FontAwesomeIcon icon={faCogs} /></a></NavAction>}
                <NavAction><NavLink to={'/account'} aria-label="Account settings"><span className={'flex items-center w-5 h-5'}><Avatar.User /></span></NavLink></NavAction>
                <Tooltip placement={'bottom'} content={'Sign Out'}>
                    <Action onClick={onTriggerLogout} aria-label="Sign out"><FontAwesomeIcon icon={faSignOutAlt} /></Action>
                </Tooltip>
            </Inner>
        </Bar>
    );
};
