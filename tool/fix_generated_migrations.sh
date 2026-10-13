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
  # Update the allSchemaEntities list, both single-line and multi-line forms.
  sed -i 's/stockAuditItem, batch\]/stockAuditItem, batchTable]/' "$f"
  sed -i 's/^\( *\)batch$/\1batchTable/' "$f"
done
echo "patched: batch -> batchTable in generated migration schemas"
