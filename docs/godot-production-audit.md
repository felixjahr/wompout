# Godot production-readiness audit — 12 October 2026

**Verdict: not production-ready yet.** Syntax and resource loading are healthy, but there are gameplay, session-lifecycle, asynchronous UI, and network-boundary issues to fix before release. This is an audit of the current working tree, including uncommitted changes; it is not a certification that no other defects exist.

Scope: first-party Godot scripts, scenes, resources, client/server networking, gameplay, UI, export configuration, and relevant backend contracts. Native plugin binaries and platform SDK internals were not audited. No gameplay implementation was changed during this audit.

Validation performed:

- All **85 first-party GDScript files** passed Godot 4.7.2 `--check-only`.
- All **87 first-party .tscn/.tres files** loaded; PackedScenes instantiated off-tree without load failures. This does not exercise every `_ready()` or interaction.
- Headless lobby smoke: player/lobby/friends/rankings updates and armory/settings/mode open-close paths completed without script errors.
- Reproduced shared melee collision resources across two player instances.
- Reproduced silently discarded live rankings dictionary updates.
- Reproduced a late signup callback leaving Login and Verify simultaneously visible.
- No live backend, multiplayer match, phone GPU, app-store export, packet-loss simulation, or native deep-link/share test was run. Headless runs also reported an environment certificate-store warning; no HTTP/TLS behavior was validated by those runs.

Priority: **P1** = fix before public release; **P2** = correctness/reliability work before calling the project clean; **P3** = maintainability or optional optimization. “Risk” means the implementation exposes a failure path but that exact runtime scenario was not reproduced here.

## Confirmed bugs and release blockers

1. **P1 — Production endpoints are localhost and unencrypted.** `client/client_backend_net.gd:23`: HTTP points to `http://localhost:3000`, WebSocket to `ws://localhost:3000/ws`. An installed phone connects to itself, not your deployed service. Add explicit environment configuration and production HTTPS/WSS endpoints, keeping localhost for development. Validate real-device TLS.

2. **P1 — WebSocket authentication expires without renewal.** `client/client_backend_net.gd` only sends `authenticate` while connecting. HTTP token refresh does not reauthenticate the socket. The backend's realtime service stops publishing once the socket identity expires, even if the connection stays open. Add one coordinated refresh/reauthentication flow before expiry, with reconnect/resubscribe recovery. Otherwise a long lobby session can quietly stop updating.

3. **P1 — Concurrent access-token refresh requests race.** `_get_valid_access_token()` independently calls `_refresh_session()` for each expired-token request. The backend rotates refresh tokens and allows only one update for a given old token. Two different pending actions can therefore make one another fail. Serialize refresh and have other callers await its result. Per-action pending flags do not solve this shared-session race.

4. **P1 — Async responses outlive their screen/session.** `client/client_controller.gd` calls `on_completed.call(response)` after awaits without checking callback validity or whether the request belongs to the current screen/account. Starting a chest request and leaving the lobby can target a deleted lobby. Delayed authentication responses can change state after navigation. Capture a session/screen generation; discard obsolete responses and check callable validity. Protect token writes in `client_backend_net.gd` against old-session responses too.

5. **P1 — Auth navigation can show conflicting forms.** `ui/auth/auth.gd`: start signup, switch to Login, then let signup finish. `_on_start_signup_completed()` hides Signup and shows Verify but leaves Login visible. This was reproduced. Pending flags only block another identical request; they do not lock navigation or preserve the email associated with an earlier request. Use an explicit auth state/request context, or disable the relevant navigation while pending. Apply the same rule to link-email screens and edited email fields.

6. **P1 — Melee hitbox dimensions are shared between players.** `participant/participant_server.gd:195` changes `hitbox_collision_shape.shape.size`; the shape in `participant_server.tscn` is not local to the scene. Two instantiated players share the same shape (reproduced). One player's weapon changes other players' hitbox dimensions. Duplicate the shape per instance or mark that resource local to scene.

7. **P1 — Multiplayer request decoding trusts client payload structure.** `server/server_game_net.gd`, `packets/input/input_batch.gd`, `packets/game_request.gd`: an authenticated client can send truncated byte packets or dictionaries missing `type`/`payload`. Decoders read directly without a reject path. Validate packet lengths/counts and request schema/type before constructing objects; reject invalid data cleanly instead of triggering engine/script errors.

8. **P1 — Input acceptance has no tick window or request budget.** `data/modes/logic_server.gd:287` accepts inputs straight into the ring buffer, including arbitrarily future ticks. `server_game_net.gd` has no per-peer input/request rate budget. Restrict batch size to the supported protocol, weapon values to 0/1, ticks to a bounded past/future window, and request rates. Bound token length before hashing as well. This is network hardening, not a claim that a speed hack was demonstrated.

9. **P1 — Live rankings updates are discarded.** `client_backend_net.gd` declares `rankings_updated(rankings: Array)` and only dispatches rankings snapshots when they are Arrays. The backend and UI use `{players: [...]}` dictionaries. Initial subscription data takes a different path and works; subsequent published changes are ignored. Reproduced. Change both the signal type and dispatch condition to Dictionary.

10. **P1 — Optimistic equipment changes modify authoritative state and can be dropped.** `ui/lobby/armory_screen/armory_screen.gd:108` mutates the same nested player/loadout dictionary held by the controller, before sending the request. Failures do not roll it back. With the new pending guard, choosing item B while item A is saving still changes the UI locally, but the controller discards B's request. Send a copied requested loadout; disable equip while saving or queue the latest selection, and explicitly reconcile success/failure.

11. **P1 — Spike server feature check is inconsistent.** `data/maps/forest/spikes/spikes.gd` tests `OS.has_feature("server")`; bootstrap, map scripts, and the export preset use `dedicated_server`. The preset does not add a `server` custom feature, so spike solid collision is removed on the intended dedicated-server build too. Use the same dedicated-server feature throughout and test spike collision in the exported server.

12. **P1 risk — Fast projectiles use discrete overlap detection.** `projectile/projectile_server.gd` directly moves position each tick and relies on Area2D signals. The sniper travels about 117 pixels per 30 Hz tick, enough to skip thin targets/obstacles depending on overlap geometry. Use a swept ray/shape query along the travelled segment and resolve the first valid hit. Verify with moving targets and thin walls; actual tunneling was not simulated in this audit.

## Reliability and behavior fixes

13. **P2 — Session invalidation lacks a clean recovery path.** `_authenticated_request()` does not recover from HTTP 401; `_get_valid_access_token()` returns an empty string on refresh failure without distinguishing revoked credentials from transient outages for the controller. Route expired/revoked sessions back to authentication, coordinate renewal, and show recoverable connectivity errors. Do not blindly retry non-idempotent mutations.

14. **P2 — Token persistence is plaintext and save errors are ignored.** `_save_refresh_token()` stores a long-lived credential in ConfigFile and ignores `save()` failure. Use platform credential storage for mobile release, handle persistence failure, and keep debug account suffixes behind explicit development configuration. At minimum make the chosen storage threat model intentional.

15. **P2 — Match acknowledgement failure has no retry.** `_apply_match_state()` sets `displayed_game_id` before awaiting acknowledgement. If it fails, later snapshots for that game are ignored and only a log is written. Separate “displayed” from “acknowledged”; retry acknowledgement safely and visibly recover if it cannot complete.

16. **P2 — Friend-link redemption can run concurrently and loses retry state.** `_try_redeem_friend_invites()` pops the token before awaiting. A second incoming link can start another copy of the drain loop; failure only logs and discards the token. Have one queue consumer, track in-flight tokens, and retain retryable failures. Show a useful user-facing result for invalid/expired/self invites.

17. **P2 — Pending flags need corresponding UI behavior.** The flags now prevent duplicate controller requests, but controls still animate/toggle/mutate local state before the guard silently returns. Disable or show pending state for Ready, Equip, invite responses, and auth submissions. Only mutually exclusive operations need a shared guard; avoid a global app-wide lock.

18. **P2 — Panel loading/error states are missing.** Friends/rankings open immediately and may show old rows or an empty view until the server responds. Subscription send success is not subscription success; asynchronous WebSocket errors only reach `push_error()`. Model loading/content/empty/error explicitly, and render snapshots only for the active subscription/screen generation. Avoid treating an empty placeholder as a confirmed empty list.

19. **P2 — Screen close is not idempotent during animations.** `AnimatedPanel._input()` checks `visible`; a closing panel remains visible, so more clicks can restart its tween and repeat unsubscribe/reset side effects. Add an active/closing state, emit logical-close effects once, and disable processing after the animation. Use tree visibility where a hidden ancestor matters.

20. **P2 — Popup selection can survive a category rebuild.** Armory `_render_category()` now rebuilds cards without clearing or refreshing the equip popup. Player updates or non-mouse category activation can leave a popup for a stale selection/position. Define one rule: close on category/data invalidation, or preserve the selection and explicitly refresh/reanchor it. Retain a valid-selection guard in the Equip handler.

21. **P2 — Shop is an exposed no-op.** `lobby.gd` contains both an empty shop click handler and `update_shop()`. Implement the feature, hide/disable the button, or label it as unavailable rather than presenting a working action.

22. **P2 — Matchmaking elapsed time formats incorrectly after one minute.** `ui/loading/loading.gd:39` uses `"0:%02d" % seconds_elapsed`, yielding `0:60`. Format minutes and remaining seconds, and reset `seconds_elapsed`/stop the timer when reusing the loading screen.

23. **P2 risk — Projectiles can process more than one collision before deletion.** `despawn_bullet()` queues deletion; ordinary projectile collision handlers have no consumed/dead guard. Multiple same-frame overlap callbacks can still apply damage after the first hit. Add a consumed flag, disable collision promptly, and resolve collisions in a defined order. Rocket already has an explosion guard; apply an equivalent lifecycle to normal projectiles.

24. **P2 — Snapshot wire format has no version or safe count overflow policy.** `packets/snapshot/snapshot.gd` writes participant/bullet/event counts as u8 but loops over all entries. More than 255 entries causes the encoded count to disagree with the payload. Bound/assert collection sizes or use wider counts; validate decoding and add a version/content fingerprint. Item indices depend on the exact ordering in `Data.*_IDS`, which can change across client/server releases. Unknown IDs currently silently become the first item.

25. **P2 — Gameplay requests need an explicit repeated-auth policy.** `receive_game_token()` can authenticate an already authenticated peer again and emit another initialization/state sync. Reject redundant auth or make it deliberately idempotent; constrain how peer/player mappings can be replaced. Keep token-reconnect behavior, but do not allow repeated auth to drive arbitrary initialization work.

26. **P2 risk — Touch controls do not reset on focus loss/suspension.** Joystick, dpad, jump, and ability controls only release when the corresponding touch event arrives. App suspension, focus loss, or cancellation needs an explicit reset. A cancelled joystick touch should not fire an attack. Test multi-touch, interruptions, navigation gestures, and resume on physical devices.

27. **P2 — Desktop attack actions are configured but unused.** `project.godot` defines `aim_melee`/`aim_ranged`; Overlay does not consume them and `_get_mouse_aim_direction()` has no callers. Only touch joystick release sends attacks. If desktop is supported, implement mouse aiming/attacking; otherwise remove or clearly separate unused desktop mappings. Keyboard movement/jump working does not mean desktop combat is complete.

28. **P2 risk — UI tweens can outlive their owner.** Draft flight animations and participant hit effects use `get_tree().create_tween()` rather than a node-bound tween. Draft callbacks reference UI nodes after state changes free the screen. Bind tweens to their owner, stop competing effects, and cancel/guard delayed layout/animation continuations. Reproduce with reconnect or phase changes mid-animation.

29. **P2 — Validate startup configuration and external snapshots at boundaries.** `server_controller._ready()` assigns parsed environment JSON straight to a Dictionary and indexes required values. UI/controller snapshots similarly assume all nested keys/IDs exist. Validate config/mode/map/loadout schemas once at ingress and fail clearly. Do not add repeated defensive checks to every internal method; maintain validated internal contracts.

30. **P2 — Release export configuration needs deliberate cleanup/verification.** Android still uses `com.felixjahr.smashdash` and a `Smash Dash.aab` output path; iOS uses Wompout. Confirm whether the Android identifier is intentional before changing an existing published identity. Verify intended iPhone/iPad device-family selection, release signing/provisioning, native plugins, associated-domain files, and release endpoints in actual exports. Both client presets export all resources; audit package contents and separate server-only assets/code if appropriate.

## Performance, maintenance, and consistency

31. **P3 / profile — Hidden UI still receives expensive updates.** `lobby.update_player()` always rebuilds armory content and updates its preview, including when closed. Friends/rankings also recreate every row on updates. Apply your chosen active-screen update policy, keep snapshots in the owner, and render once on opening. Small labels can remain simple; use ID-based row reuse only where useful.

32. **P3 / profile — Inactive previews and viewport work.** Hidden screens retain processing/animations, and the game SubViewport is configured to update always. Disable irrelevant processing while hidden and choose an appropriate viewport update mode. Measure mobile frame time, memory, and battery impact rather than assuming lazy instantiation alone fixes it.

33. **P3 / profile — Chest particle count equals currency amount.** `_emit_currency()` sets `currency_burst.amount = amount`; a 10,000-coin reward creates 10,000 particles. Decouple cosmetic particle count from reward amount and cap it. Also recalculate cached home positions after viewport/layout changes if the screen is reused.

34. **P3 / profile — Snapshot rendering allocates and searches heavily.** `logic_client.gd` scans 128 snapshot slots and builds dictionaries, arrays, snapshots and entity-ID lists at render ticks; entity removal uses repeated array membership tests. Profile before optimizing; then maintain adjacent snapshots/ID sets and reuse scratch structures where measurements justify it. Aim cones additionally cast multiple rays each render tick.

35. **P3 / profile — Bots have duplicated physics constants and per-bot work budgets.** `bot_controller.gd` copies speed, acceleration, gravity, capsule geometry and simulation step from participant/server settings. Changes can silently invalidate navigation predictions. Share immutable movement configuration. Profile cold graph construction and trajectory simulations with the maximum bots; the 1.5 ms deadline is per caller and one trajectory can exceed it. Splitting the 1,138-line file into geometry/navigation/combat helpers is optional, not itself a release requirement.

36. **P3 — Remove verified dead code/resources.** `friends_screen.gd` has an unused `add_friends_button` reference; `game_mode_entry.gd` has unused `scale_tween`; armory has unused local `category_items`; Overlay's `_get_mouse_aim_direction()` is unused. The old `item_entry.gd/.tscn` is no longer instantiated by the armory; remove its stale `ext_resource` declaration from `armory_screen.tscn` and then remove the obsolete scene/script/UID if no intended future use remains. Confirm usages again immediately before deletion.

37. **P3 — Fix redundant map cleanup.** `mountains.gd` loops over collision shapes but calls `arena.queue_free()` each time, never using the loop variable. Free the arena once. Decide separately whether client map collision must remain for aiming raycasts; do not delete useful collision shapes just because the loop looks unfinished. Forest's collision-shape list is also a cleanup candidate if unused.

38. **P3 — Choose naming conventions and apply them to first-party code.** Use UPPER_SNAKE_CASE for scene constants (`Overlay`, `Loading`, `PlayerEntry`, `DraftScreen`, etc. currently mix styles); snake_case for local arguments (`displayName` remains in auth/network UI layers); consistent `participant` vs `player` for entities that include bots; one UI verb convention for `render_*`, `update_*`, `show_*`, `open`, and `_close`. Keep backend JSON keys like `displayName` unchanged at the serialization boundary. Do not rename RPC methods independently on client/server.

39. **P3 — Normalize types, signals, and method order.** Add missing `-> void` and useful parameter types, standardize `signal.emit()` versus `emit_signal("...")`, and adopt a common declaration/lifecycle/public/private ordering. Prefer named child references over repeated `get_child(0)` where practical. Keep virtual base hooks and RPC counterpart stubs: their `pass` bodies are intentional, not dead code.

40. **P3 — Formatting cleanup.** Remove trailing whitespace reported in `lobby.gd`, extra blank lines, spacing before dictionary colons (`data.gd`), mixed `=`/`:=` when inference is intended, and inconsistent multiline indentation. Format first-party scripts with an agreed tool/config; avoid reformatting vendored addons and generated scene files wholesale.

41. **P3 — Remove duplication selectively.** `_load_refresh_token()` and `_save_refresh_token()` duplicate debug suffix/path selection; token response parsing duplicates refresh parsing with weaker type checks in the latter (`str()` coerces bad values); client/server controllers duplicate the mode-to-scene map; touch controls share pointer-tracking/reset behavior; melee/ranged reload logic is nearly identical. Extract small shared helpers where they clarify behavior. Keep client-side input checks and authoritative server validation: they are not redundant.

42. **P3 — Clean up small misleading/inefficient expressions.** Replace `true if status == "offline" else false` with the comparison; use `player_id.is_empty()` consistently; compile/reuse email validation rather than creating a regex each submission; remove repeated identical `link_button.show()` branches. In `chest_screen`, repeated particle restart/emitting assignments deserve a documented reason or simplification after visual verification. Avoid broad removal of guards merely to reduce line count.

## Release verification still required

43. **Network/session matrix:** idle beyond token lifetime; two simultaneous authenticated actions during refresh; logout while requests are pending; session revocation; background/resume; server restart; slow/lost HTTP responses; dropped/reordered UDP; disconnect/reconnect during draft, combat, chest opening and gameover. Verify no stale callback changes a new account/screen.

44. **Gameplay matrix:** every mode/map/team size, all weapons/armours/abilities, mixed simultaneous melee attacks, high-speed projectile hits, repeated collision callbacks, spawn/respawn, abandonment during preparation and fight, ties/time limits, teammate elimination, reconnect windows, and result-delivery retries. Verify that input delay under realistic RTT/loss remains playable; the current client interpolates authoritative motion without local prediction.

45. **Device/release matrix:** signed Android/iOS exports, native cold/warm deep links, share sheet, actual server reachability, touch cancellation, safe areas and aspect ratios, keyboard/email entry, low-end GPU particle load, memory after repeated matches, and long-session battery/frame-time behavior. Forward Plus and always-live previews need measurement on your supported hardware, not an automatic renderer rewrite.

46. **Automated regression coverage:** no first-party test files were found in the Godot tree. Add focused tests for packet malformed-input rejection/round trips, session-refresh serialization, stale-response rejection, resource isolation, ready/equip pending behavior, live rankings contracts, and match completion/reconnect. Add a reproducible headless smoke command to CI. These checks are more valuable than tests that simply mirror every getter or UI label assignment.

## Things already fixed or not justified as mandatory rewrites

- Chest availability now returns before sending; mode-size validation, display-name checks, email/code checks, pending controller flags, and outgoing-invite/membership filtering exist.
- The previously reported `status_label.color` issue was corrected during the current working-tree review; it is not listed as an outstanding defect.
- EquipPopup now has the intended 288 × 488 root bounds and the preview card setup changed; the old 8 × 8 diagnosis no longer applies.
- Keeping small lobby screens instantiated is not itself a bug. Moving to lazy creation is an optional memory/startup choice after profiling.
- Passing a lobby reference to its own subscreens is a coupling tradeoff, not automatically a production blocker. A scene manager/event bus rewrite is not required.
- Client/server RPC stubs, intentional base-class hooks, authoritative backend checks, and validated-boundary guards should not be deleted as “redundant.”
- Backend readiness/completion callbacks already include idempotent behavior; generic retries should still distinguish retryable network/server failures from permanent request errors.

Suggested order: fix items 1–12; address session/UI reliability and packet compatibility; run the release matrices; then do naming/dead-code cleanup and measured performance work. Do not equate a parser-clean project with a production-tested game.
