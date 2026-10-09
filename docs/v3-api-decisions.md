# EmberUI v3 API decisions

- `Id` is a stable, non-empty string identifier; display names are never persistence keys.
- Duplicate control IDs within a window are rejected.
- `Destroy()` is idempotent and parent destruction owns all descendant input scopes.
- Callback failures are reported with `warn` and a traceback in development instead of being silently swallowed.
- The public v2 method names are retained where possible. v3 handles standardise on `Get`, `Set`, `Changed`, `SetVisible`, `SetDisabled`, and `Destroy`.
- `State:Sub` is a compatibility spelling; v3 documents `Subscribe`.
- All normal mounting is through `PlayerGui`; CoreGui and executor-only mount paths are unsupported.
