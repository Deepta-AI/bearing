from worker.queue import enqueue

# Large exports are split so each job message stays under the queue's
# message size limit.
CHUNK_ROWS = 2000


def schedule_export(export_id, row_ids):
    for start in range(0, len(row_ids), CHUNK_ROWS):
        enqueue({"export_id": export_id, "rows": row_ids[start:start + CHUNK_ROWS]})
