# J&Z implementation manifest

## Completed

- J&Z branding and favicon
- Dark/light/system theme with local persistence and reduced-motion support
- Premium responsive navigation/header
- Redesigned authentication surface
- Public registration using the existing UserCreationService and reCAPTCHA/throttle middleware
- Dashboard hero, live server resource cards, search and grid/list controls
- Server workspace header while preserving existing WebSocket/power/file infrastructure
- Modern admin shell and admin dashboard metrics backed by real database counts
- Production installer with Panel/Wings/Panel+Wings menu, dependency detection, web server, SSL, queue/scheduler and logging
- `jz-panel` operations CLI

## Intentionally preserved

- Pterodactyl internal PHP namespaces and service architecture
- Database schema and API contracts
- WebSocket authentication/console protocol
- Wings communication and Docker integration
- Existing server/file/backup/database/schedule/subuser permission checks
- Applicable open-source license and attribution files

## Validation status

Static validation completed in the build environment:

- PHP syntax checks: modified PHP files pass
- Bash syntax check: `install.sh` passes
- Repository TypeScript validation could not be completed because the uploaded source does not include `node_modules`, and external package installation is unavailable in the build environment.

The final production verification must run `yarn install`, `yarn run tsc`, `yarn run lint`, `yarn test`, and `yarn run build:production` in an environment with package registry access.
