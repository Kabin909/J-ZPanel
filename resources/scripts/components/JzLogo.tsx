import React from 'react';
import styled from 'styled-components/macro';

const Mark = styled.div`
    width: 38px;
    height: 38px;
    border-radius: 12px;
    display: grid;
    place-items: center;
    color: #fff;
    font-weight: 800;
    letter-spacing: -0.08em;
    background: linear-gradient(135deg, #7c3aed 0%, #2563eb 55%, #06b6d4 100%);
    box-shadow: 0 8px 24px rgba(37, 99, 235, 0.28);
    user-select: none;
`;

export default ({ compact = false }: { compact?: boolean }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: compact ? 9 : 12 }}>
        <Mark>JZ</Mark>
        {!compact && (
            <div style={{ lineHeight: 1.05 }}>
                <strong style={{ display: 'block', fontSize: 16, letterSpacing: '-0.02em' }}>J&Z PANEL</strong>
                <span style={{ display: 'block', fontSize: 10, opacity: 0.62, letterSpacing: '0.08em' }}>MINECRAFT INFRASTRUCTURE</span>
            </div>
        )}
    </div>
);
