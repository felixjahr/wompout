# Delete an account

Send `POST /players/delete` with `Authorization: Bearer <access_token>` and no
request body. The endpoint permanently deletes the authenticated account
(including guest accounts) and returns `204 No Content`. It never accepts a target
player ID.

Deletion removes progression, loadout, inventory, friendships, friend invites,
verification codes, and all sessions. Signup verification records for the account's
email are also removed. Existing access and refresh tokens can no longer be used;
the backend WebSocket is disconnected. Missing or invalid authentication returns
`401 Unauthorized`. The client should clear its locally stored tokens after success.

No database migration is required: player-owned records already use cascading
foreign keys. Active games can finish, but results for deleted accounts do not
restore their progression.
