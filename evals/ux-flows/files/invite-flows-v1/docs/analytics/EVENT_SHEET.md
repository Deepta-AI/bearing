# Event sheet

Owner: growth. Add an event here before shipping code that sends it.

| Event | When | Properties |
|---|---|---|
| schedule_published | An admin publishes a week | week, shift_count |
| shift_claimed | A member picks up an open shift | shift_id |
| invite_sent | The API created an invite | workspace_id, plan, role |
| invite_accepted | An invitee joined a workspace | workspace_id, days_to_accept |
| member_removed | An admin removed a member | workspace_id |
