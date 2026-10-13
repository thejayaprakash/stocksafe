#!/usr/bin/env bash
# Post-processing step for `drift_dev schema generate`.
#
# The `batch` table generates a `batch` getter on GeneratedDatabase, which
# collides with drift's own `batch()` helper and fails to compile. drift_dev
# has no option to rename it, so we rename the getter to `batchTable` here.
#
# Full regeneration sequence after any schema change:
#   dart run drift_dev schema dump lib/src/data/database.dart drift_schemas/
#   dart run drift_dev schema steps drift_schemas/ lib/src/data/schema_versions.dart
#   dart run drift_dev schema generate --data-classes --companions \
#       drift_schemas/ test/generated_migrations/
#   bash tool/fix_generated_migrations.sh
set -euo pipefail
cd "$(dirname "$0")/.."

for f in test/generated_migrations/schema_v*.dart; do
  sed -i 's/late final Batch batch = Batch(this);/late final Batch batchTable = Batch(this);/' "$f"
  # Update references in allSchemaEntities, in every layout drift_dev emits:
  # inline in a list, or on its own line with or without a trailing comma.
  sed -i 's/stockAuditItem, batch\]/stockAuditItem, batchTable]/' "$f"
  sed -i 's/^\( *\)batch\(,\?\)$/\1batchTable\2/' "$f"
done

# Fail loudly rather than leaving a file that will not compile.
if grep -nE '^\s*batch,?$|late final Batch batch = ' test/generated_migrations/schema_v*.dart; then
  echo "ERROR: an unpatched 'batch' reference remains (see above)." >&2
  echo "drift_dev changed its output layout; update this script." >&2
  exit 1
fi

echo "patched: batch -> batchTable in generated migration schemas"
