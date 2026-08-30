import React, { forwardRef } from 'react';
import { Form } from 'formik';
import styled from 'styled-components/macro';
import FlashMessageRender from '@/components/FlashMessageRender';
import JzLogo from '@/components/JzLogo';
import tw from 'twin.macro';

type Props = React.DetailedHTMLProps<React.FormHTMLAttributes<HTMLFormElement>, HTMLFormElement> & { title?: string };

const Page = styled.div`
    min-height: 100vh;
    display: grid;
    place-items: center;
    padding: 32px 18px;
    background:
        radial-gradient(circle at 15% 20%, rgba(99,102,241,.20), transparent 34%),
        radial-gradient(circle at 85% 80%, rgba(6,182,212,.16), transparent 34%),
        var(--jz-bg);
`;

const Container = styled.div`
    width: min(460px, 100%);
`;

const Card = styled.div`
    margin-top: 24px;
    padding: 30px;
    border: 1px solid var(--jz-border);
    border-radius: 24px;
    background: color-mix(in srgb, var(--jz-surface) 94%, transparent);
    box-shadow: var(--jz-shadow);
    backdrop-filter: blur(20px);
`;

export default forwardRef<HTMLFormElement, Props>(({ title, ...props }, ref) => (
    <Page>
        <Container>
            <div style={{ display: 'flex', justifyContent: 'center' }}><JzLogo /></div>
            <p css={tw`text-center mt-3`} style={{ color: 'var(--jz-muted)' }}>Advanced Minecraft Server Management</p>
            <Card>
                {title && <h2 css={tw`text-2xl text-center font-medium`} style={{ color: 'var(--jz-text)' }}>{title}</h2>}
                <FlashMessageRender css={tw`mt-4 mb-2`} />
                <Form {...props} ref={ref}>
                    <div css={tw`w-full`}>{props.children}</div>
                </Form>
            </Card>
            <p css={tw`text-center text-xs mt-5`} style={{ color: 'var(--jz-muted)' }}>
                J&Z Panel · Advanced Minecraft Server Management
            </p>
        </Container>
    </Page>
));
