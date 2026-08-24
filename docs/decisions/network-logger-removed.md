# ADR — Remove Network Logger from Product/Design Scope

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Earlier design listed a Network Logger screen/route under Settings (`Settings → Network Logger`). Product does not require a persistent network log; security redaction and retention policy are open (see `SECURITY.md`). Keeping the route would imply storage/retention behavior that is not decided.

## Decision

- Remove Network Logger from product/design scope. Deleted from `docs/design/navigation.md` (map, stack, cases) and `docs/design/screens.md` (inventory, list of screens, navigation map, state rules).
- Do not leave it as a product screen/route. Record the removal here as the accepted decision.

## Consequence

- Navigation graph: `Settings → Cache Manager` and `Settings → Setting Editor` remain; `Settings → Network Logger` no longer exists.
- Screen inventory: seven product screens + overlays (Home Library, Add Book, Reading, References, Settings, Cache Manager, Setting Editor; overlays Bottom Sheet, Toast, Loading).
- Any future diagnostic logging needs a new ADR that explicitly defines scope, storage, and redaction.

## Links

- `docs/design/navigation.md` · `docs/design/screens.md` · `SECURITY.md` · `ARCHITECTURE.md` §3
