import React, { useEffect, useMemo, useState } from 'react';
import { Server } from '@/api/server/getServer';
import getServers from '@/api/getServers';
import ServerRow from '@/components/dashboard/ServerRow';
import Spinner from '@/components/elements/Spinner';
import PageContentBlock from '@/components/elements/PageContentBlock';
import useFlash from '@/plugins/useFlash';
import { useStoreState } from 'easy-peasy';
import { usePersistedState } from '@/plugins/usePersistedState';
import Switch from '@/components/elements/Switch';
import tw from 'twin.macro';
import useSWR from 'swr';
import { PaginatedResult } from '@/api/http';
import Pagination from '@/components/elements/Pagination';
import { useLocation } from 'react-router-dom';
import styled from 'styled-components/macro';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faServer, faCircle, faSearch, faList, faTh } from '@fortawesome/free-solid-svg-icons';

const Hero = styled.div`
    padding: 26px;
    border: 1px solid var(--jz-border);
    border-radius: 22px;
    background:
        radial-gradient(circle at 90% 10%, rgba(99,102,241,.22), transparent 32%),
        linear-gradient(135deg, var(--jz-surface), var(--jz-surface-2));
    box-shadow: var(--jz-shadow);
    margin-bottom: 22px;
`;

const Stats = styled.div`
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
    margin-top: 22px;
    @media (max-width: 900px) { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    @media (max-width: 520px) { grid-template-columns: 1fr; }
`;

const Stat = styled.div`
    padding: 16px;
    border: 1px solid var(--jz-border);
    border-radius: 16px;
    background: color-mix(in srgb, var(--jz-surface) 72%, transparent);
`;

const Toolbar = styled.div`
    display: flex;
    gap: 10px;
    align-items: center;
    margin-bottom: 14px;
    @media (max-width: 680px) { flex-wrap: wrap; }
`;

const Search = styled.div`
    flex: 1;
    min-width: 220px;
    display: flex;
    align-items: center;
    gap: 9px;
    height: 44px;
    padding: 0 14px;
    border: 1px solid var(--jz-border);
    border-radius: 13px;
    background: var(--jz-surface);
    color: var(--jz-muted);
    input { width: 100%; border: 0; background: transparent; color: var(--jz-text); outline: none; }
`;

const ViewButton = styled.button<{ $active: boolean }>`
    width: 44px;
    height: 44px;
    border: 1px solid var(--jz-border);
    border-radius: 13px;
    color: ${({ $active }) => ($active ? 'var(--jz-text)' : 'var(--jz-muted)')};
    background: ${({ $active }) => ($active ? 'var(--jz-surface-2)' : 'var(--jz-surface)')};
    cursor: pointer;
`;

export default () => {
    const { search } = useLocation();
    const defaultPage = Number(new URLSearchParams(search).get('page') || '1');
    const [page, setPage] = useState(!isNaN(defaultPage) && defaultPage > 0 ? defaultPage : 1);
    const [query, setQuery] = useState('');
    const [grid, setGrid] = usePersistedState('jz-panel:dashboard-grid', true);
    const { clearFlashes, clearAndAddHttpError } = useFlash();
    const uuid = useStoreState((state) => state.user.data!.uuid);
    const rootAdmin = useStoreState((state) => state.user.data!.rootAdmin);
    const [showOnlyAdmin, setShowOnlyAdmin] = usePersistedState(`${uuid}:show_all_servers`, false);

    const { data: servers, error } = useSWR<PaginatedResult<Server>>(
        ['/api/client/servers', showOnlyAdmin && rootAdmin, page],
        () => getServers({ page, type: showOnlyAdmin && rootAdmin ? 'admin' : undefined })
    );

    useEffect(() => setPage(1), [showOnlyAdmin]);
    useEffect(() => {
        if (servers && servers.pagination.currentPage > 1 && !servers.items.length) setPage(1);
    }, [servers?.pagination.currentPage]);
    useEffect(() => {
        window.history.replaceState(null, document.title, `/${page <= 1 ? '' : `?page=${page}`}`);
    }, [page]);
    useEffect(() => {
        if (error) clearAndAddHttpError({ key: 'dashboard', error });
        if (!error) clearFlashes('dashboard');
    }, [error]);

    const visible = useMemo(() => {
        if (!servers) return [];
        const q = query.trim().toLowerCase();
        return q ? servers.items.filter((server) => `${server.name} ${server.node} ${server.description}`.toLowerCase().includes(q)) : servers.items;
    }, [servers, query]);

    const total = servers?.pagination.total || 0;
    const online = servers?.items.filter((s) => s.status === null || s.status === 'running').length || 0;
    const offline = Math.max(0, (servers?.items.length || 0) - online);
    const ram = servers?.items.reduce((sum, s) => sum + (s.limits.memory || 0), 0) || 0;

    return (
        <PageContentBlock title={'Dashboard'} showFlashKey={'dashboard'}>
            <Hero>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 18, alignItems: 'flex-start', flexWrap: 'wrap' }}>
                    <div>
                        <p style={{ color: 'var(--jz-primary-2)', fontSize: 12, fontWeight: 700, letterSpacing: '.12em', textTransform: 'uppercase' }}>J&Z CONTROL CENTER</p>
                        <h1 style={{ color: 'var(--jz-text)', fontSize: 30, marginTop: 5 }}>Welcome back 👋</h1>
                        <p style={{ color: 'var(--jz-muted)', marginTop: 6 }}>Manage your Minecraft infrastructure from one place.</p>
                    </div>
                    {rootAdmin && (
                        <label style={{ display: 'flex', alignItems: 'center', gap: 9, color: 'var(--jz-muted)', fontSize: 12 }}>
                            <span>{showOnlyAdmin ? "Showing others' servers" : 'Showing your servers'}</span>
                            <Switch name={'show_all_servers'} defaultChecked={showOnlyAdmin} onChange={() => setShowOnlyAdmin((s) => !s)} />
                        </label>
                    )}
                </div>
                <Stats>
                    <Stat><div style={{ color: 'var(--jz-muted)', fontSize: 12 }}>Servers</div><strong style={{ display: 'block', fontSize: 24, marginTop: 4 }}>{total}</strong></Stat>
                    <Stat><div style={{ color: 'var(--jz-muted)', fontSize: 12 }}><FontAwesomeIcon icon={faCircle} style={{ color: 'var(--jz-success)', fontSize: 8, marginRight: 6 }} />Online</div><strong style={{ display: 'block', fontSize: 24, marginTop: 4 }}>{online}</strong></Stat>
                    <Stat><div style={{ color: 'var(--jz-muted)', fontSize: 12 }}>Offline / unavailable</div><strong style={{ display: 'block', fontSize: 24, marginTop: 4 }}>{offline}</strong></Stat>
                    <Stat><div style={{ color: 'var(--jz-muted)', fontSize: 12 }}>Allocated RAM</div><strong style={{ display: 'block', fontSize: 24, marginTop: 4 }}>{ram ? `${Math.round(ram / 1024)} GB` : '—'}</strong></Stat>
                </Stats>
            </Hero>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <div><h2 style={{ fontSize: 21, color: 'var(--jz-text)' }}>Your servers</h2><p style={{ color: 'var(--jz-muted)', fontSize: 13 }}>Live resources and quick access.</p></div>
                <span style={{ color: 'var(--jz-muted)', fontSize: 12 }}><FontAwesomeIcon icon={faServer} /> {total} total</span>
            </div>
            <Toolbar>
                <Search><FontAwesomeIcon icon={faSearch} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search servers on this page..." aria-label="Search servers" /></Search>
                <ViewButton type="button" $active={grid} onClick={() => setGrid(true)} aria-label="Grid view"><FontAwesomeIcon icon={faTh} /></ViewButton>
                <ViewButton type="button" $active={!grid} onClick={() => setGrid(false)} aria-label="List view"><FontAwesomeIcon icon={faList} /></ViewButton>
            </Toolbar>

            {!servers ? <Spinner centered size={'large'} /> : (
                <Pagination data={servers} onPageSelect={setPage}>
                    {() => visible.length > 0 ? (
                        <div style={{ display: grid ? 'grid' : 'block', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: 12 }}>
                            {visible.map((server) => <ServerRow key={server.uuid} server={server} />)}
                        </div>
                    ) : <p css={tw`text-center text-sm`} style={{ color: 'var(--jz-muted)', padding: 36 }}>{query ? 'No servers match your search.' : 'There are no servers associated with your account.'}</p>}
                </Pagination>
            )}
        </PageContentBlock>
    );
};
