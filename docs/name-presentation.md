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
