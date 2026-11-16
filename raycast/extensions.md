# Raycast

Raycast keeps settings in its own encrypted store, so this repo cannot restore them directly.

1. On the old machine: Raycast > Settings > Advanced > **Export** (set a password). Keep the `.rayconfig` file
   somewhere private (not in this repo).
2. On the new machine, after bootstrap installs Raycast: Settings > Advanced > **Import**.

The old machine has two store extensions installed (ids in `~/.config/raycast/extensions`):
`0e43920f-bbf6-4582-bc3f-5f63092c915f`, `c5ce763c-8582-4da2-badb-10b63d514297`; the export includes them.
