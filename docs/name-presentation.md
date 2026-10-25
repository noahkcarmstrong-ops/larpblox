# Player identity and displayed names

Player.Name and Player.DisplayName retain their native values. Games use them
for child lookups, server-data table keys, remotes and roster membership. Larp
aliases apply to identity-resolved text labels, Humanoid display names and chat
formatting. Native leaderboard and spectate controls retain their own behavior.

The former Player property-read override could cause a game to build a roster
under alias keys, then fail to find those aliases as actual Player children. It
also broke round-data lookups keyed by the server's original usernames. Reload
clears that old hook's targets. It installs no replacement identity hook and
does not restore shared metamethods that another script may own.

Name labels may include leading bracketed membership/rank tags. Resolution
requires an exact known identity after the decoration. Tags, rich-text markup,
unrelated stat text and conflicting explicit player IDs are preserved.

Run `lune run tests/run_name_identity.luau` for identity-key lookups, decorated
leaderboard labels, peer spectate labels, extension revisions, native redraws,
disable, reload and migration from the legacy hook. The same suite passes with
real Roblox instances. Live MM2 verification restored both mapped users' native
leaderboard rows with their Larp aliases; native spectate roster membership was
checked against the current round's eligibility after its own refresh callback.
Existing native lists can retain cached state until their next game refresh.

## Native avatar portraits

Full-body cards use the finished Roblox-rendered PNG in the native Image slot.
Local and shared images take this same path. A missing full-body image retains
Roblox's native thumbnail until a matching finished image is supplied; it never
switches to the lower-quality model preview. Headshot slots retain their distinct
framing. Shared image downloads are validated PNGs from permitted Roblox CDNs.

Explicit avatar thumbnail IDs veto conflicting text fallback. An opaque People
thumbnail resolves only within a single card; blank or truncated foreign labels
cannot borrow a sibling's identity. Preview ownership is registered before
parenting can trigger reentrant layout events. Disable, card reuse and cleanup
restore authored image sources and the latest transparency values.

`lune run tests/run_portrait_ownership.luau` covers card isolation, conflicting
thumbnail IDs, truncated/incomplete labels, reentrant creation, native PNG
assignment, missing-image behavior, backing updates, disable and card reuse.
It also passes with real Roblox instances.
