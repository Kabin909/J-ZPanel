import React, { memo, useEffect, useRef, useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faEthernet, faHdd, faMemory, faMicrochip, faServer, faArrowRight } from '@fortawesome/free-solid-svg-icons';
import { Link } from 'react-router-dom';
import { Server } from '@/api/server/getServer';
import getServerResourceUsage, { ServerPowerState, ServerStats } from '@/api/server/getServerResourceUsage';
import { bytesToString, ip, mbToBytes } from '@/lib/formatters';
import Spinner from '@/components/elements/Spinner';
import styled from 'styled-components/macro';
import isEqual from 'react-fast-compare';

const Card = styled(Link)<{ $status: ServerPowerState | undefined }>`
    position: relative;
    display: block;
    min-height: 168px;
    padding: 20px;
    overflow: hidden;
    color: var(--jz-text);
    text-decoration: none;
    border: 1px solid var(--jz-border);
    border-radius: 18px;
    background: linear-gradient(145deg, var(--jz-surface), var(--jz-surface-2));
    box-shadow: 0 10px 28px rgba(0,0,0,.10);
    transition: transform 160ms ease, border-color 160ms ease, box-shadow 160ms ease;
    &:hover { transform: translateY(-2px); border-color: rgba(99,102,241,.42); box-shadow: var(--jz-shadow); }
    &::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: ${({ $status }) => $status === 'running' ? 'var(--jz-success)' : $status === 'offline' ? 'var(--jz-danger)' : 'var(--jz-warning)'}; }
`;

const Metric = styled.div`
    min-width: 0;
    padding: 9px 11px;
    border: 1px solid var(--jz-border);
    border-radius: 12px;
    background: rgba(127,127,127,.035);
`;

const Icon = memo(styled(FontAwesomeIcon)<{ $alarm: boolean }>`color: ${({ $alarm }) => ($alarm ? 'var(--jz-danger)' : 'var(--jz-muted)')};`, isEqual);

const isAlarmState = (current: number, limit: number): boolean => limit > 0 && current / (limit * 1024 * 1024) >= 0.9;
type Timer = ReturnType<typeof setInterval>;

export default ({ server }: { server: Server; className?: string }) => {
    const interval = useRef<Timer>(null) as React.MutableRefObject<Timer>;
    const [isSuspended, setIsSuspended] = useState(server.status === 'suspended');
    const [stats, setStats] = useState<ServerStats | null>(null);
    const getStats = () => getServerResourceUsage(server.uuid).then(setStats).catch(() => undefined);

    useEffect(() => setIsSuspended(stats?.isSuspended || server.status === 'suspended'), [stats?.isSuspended, server.status]);
    useEffect(() => {
        if (isSuspended || server.isNodeUnderMaintenance) return;
        getStats().then(() => { interval.current = setInterval(getStats, 30000); });
        return () => { if (interval.current) clearInterval(interval.current); };
    }, [isSuspended, server.isNodeUnderMaintenance]);

    const alarms = { cpu: false, memory: false, disk: false };
    if (stats) {
        alarms.cpu = server.limits.cpu !== 0 && stats.cpuUsagePercent >= server.limits.cpu * 0.9;
        alarms.memory = isAlarmState(stats.memoryUsageInBytes, server.limits.memory);
        alarms.disk = isAlarmState(stats.diskUsageInBytes, server.limits.disk);
    }
    const diskLimit = server.limits.disk ? bytesToString(mbToBytes(server.limits.disk)) : 'Unlimited';
    const memoryLimit = server.limits.memory ? bytesToString(mbToBytes(server.limits.memory)) : 'Unlimited';
    const cpuLimit = server.limits.cpu ? `${server.limits.cpu} %` : 'Unlimited';
    const status = stats?.status;
    const statusText = isSuspended ? 'Suspended' : server.isNodeUnderMaintenance ? 'Maintenance' : server.isTransferring ? 'Transferring' : status === 'running' ? 'Online' : status === 'offline' ? 'Offline' : 'Connecting';
    const statusColor = status === 'running' ? 'var(--jz-success)' : status === 'offline' ? 'var(--jz-danger)' : 'var(--jz-warning)';

    return (
        <Card to={`/server/${server.id}`} $status={status}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 14 }}>
                <div style={{ minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div style={{ width: 36, height: 36, borderRadius: 11, display: 'grid', placeItems: 'center', background: 'rgba(99,102,241,.12)', color: 'var(--jz-primary)' }}><FontAwesomeIcon icon={faServer} /></div>
                        <div style={{ minWidth: 0 }}><div style={{ fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{server.name}</div><div style={{ color: 'var(--jz-muted)', fontSize: 11, marginTop: 2 }}>{server.node}</div></div>
                    </div>
                </div>
                <span style={{ whiteSpace: 'nowrap', fontSize: 11, color: statusColor, fontWeight: 700 }}><span style={{ marginRight: 5 }}>●</span>{statusText}</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginTop: 18 }}>
                <Metric><div style={{ color: 'var(--jz-muted)', fontSize: 10 }}>CPU</div><div style={{ marginTop: 4, fontWeight: 700 }}><Icon icon={faMicrochip} $alarm={alarms.cpu} /> {stats ? `${stats.cpuUsagePercent.toFixed(1)}%` : '—'}</div><div style={{ color: 'var(--jz-muted)', fontSize: 9 }}>of {cpuLimit}</div></Metric>
                <Metric><div style={{ color: 'var(--jz-muted)', fontSize: 10 }}>RAM</div><div style={{ marginTop: 4, fontWeight: 700 }}><Icon icon={faMemory} $alarm={alarms.memory} /> {stats ? bytesToString(stats.memoryUsageInBytes) : '—'}</div><div style={{ color: 'var(--jz-muted)', fontSize: 9 }}>of {memoryLimit}</div></Metric>
                <Metric><div style={{ color: 'var(--jz-muted)', fontSize: 10 }}>DISK</div><div style={{ marginTop: 4, fontWeight: 700 }}><Icon icon={faHdd} $alarm={alarms.disk} /> {stats ? bytesToString(stats.diskUsageInBytes) : '—'}</div><div style={{ color: 'var(--jz-muted)', fontSize: 9 }}>of {diskLimit}</div></Metric>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 14, color: 'var(--jz-muted)', fontSize: 11 }}>
                <span><FontAwesomeIcon icon={faEthernet} /> {server.allocations.find((a) => a.isDefault)?.alias || ip(server.allocations.find((a) => a.isDefault)?.ip || '0.0.0.0')}:{server.allocations.find((a) => a.isDefault)?.port || ''}</span>
                <span style={{ color: 'var(--jz-text)' }}>Open <FontAwesomeIcon icon={faArrowRight} /></span>
            </div>
            {!stats && !isSuspended && !server.isNodeUnderMaintenance && <div style={{ position: 'absolute', right: 18, bottom: 46 }}><Spinner size="small" /></div>}
        </Card>
    );
};
