# ADR — Remove Network Logger from Product/Design Scope

- **Date:** 2026-08-24
- **Status:** Accepted

## Context

Earlier design listed a Network Logger screen/route under Settings (`Settings → Network Logger`). Product does not require a persistent network log. Security redaction and retention policy are open (see `../../SECURITY.md`). The route would imply storage behavior that is not decided.

## Decision

- Remove Network Logger from product and design scope. Delete from `../../docs/design/navigation.md` (map, stack, cases) and `../../docs/design/screens.md` (inventory, list of screens, navigation map, state rules).
- Do not keep it as a product screen or route. Record the removal here as the accepted decision.

## Alternatives

| Option | Reason not chosen |
|---|---|
| Keep Network Logger screen | Requires retention and redaction policy that product does not define |
| Log to file only | Still needs storage and no product use case |
| Use OS log without UI | No persistent UI needed; future ADR CAN define scope if required |

## Consequences

- Navigation graph: `Settings → Cache Manager` and `Settings → Setting Editor` remain; `Settings → Network Logger` no longer exists.
- Screen inventory: seven product screens + overlays (Home Library, Add Book, Reading, References, Settings, Cache Manager, Setting Editor; overlays Bottom Sheet, Toast, Loading).
- Future diagnostic logging needs a new ADR that defines scope, storage, and redaction.

## Links

- `../../docs/design/navigation.md` · `../../docs/design/screens.md` · `../../SECURITY.md` · `../../ARCHITECTURE.md` §3
