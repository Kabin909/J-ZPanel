import React, { useEffect } from 'react';
import ContentContainer from '@/components/elements/ContentContainer';
import { CSSTransition } from 'react-transition-group';
import tw from 'twin.macro';
import FlashMessageRender from '@/components/FlashMessageRender';

export interface PageContentBlockProps { title?: string; className?: string; showFlashKey?: string; }

const PageContentBlock = ({ title, showFlashKey, className, children }: React.PropsWithChildren<PageContentBlockProps>) => {
    useEffect(() => { if (title) document.title = `${title} · J&Z Panel`; }, [title]);

    return (
        <CSSTransition timeout={150} classNames={'fade'} appear in>
            <>
                <ContentContainer css={tw`my-6 sm:my-8`} className={className}>
                    {showFlashKey && <FlashMessageRender byKey={showFlashKey} css={tw`mb-4`} />}
                    {children}
                </ContentContainer>
                <ContentContainer css={tw`mb-8`}>
                    <p css={tw`text-center text-xs`} style={{ color: 'var(--jz-muted)' }}>J&Z Panel · Advanced Minecraft Server Management</p>
                </ContentContainer>
            </>
        </CSSTransition>
    );
};

export default PageContentBlock;
