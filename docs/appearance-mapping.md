# Avatar presentation mapping

Roblox generates both the account baseline and the Larp replacement with
`HumanoidDescription.UseAvatarSettings = true`. Experience avatar restrictions
therefore apply to both. Cached description IDs alone do not establish what
Roblox actually generated; accessory admission inspects the generated instances.

Each mapped property keeps the game source separately from the last Larp write.
Only source values matching the normalized account baseline receive a Larp
replacement. A different uniform, mesh, color, scale, face or accessory category
remains under game control. Restoring the baseline resumes substitution.
Extension revisions change the replacement, without replacing the source.
Dependent body fields require matching source geometry. Native joints and
accessory fitting retain independent game changes.

Scoped property and hierarchy events trigger deferred, coalesced work. The
mapping installs no polling, frame listeners or global metamethod hooks. Local
metadata travels with ordinary character clones so source/write ownership can
be recovered when a cloned body enters Workspace, including delayed parenting.
Disable and destroy restore only owned writes and remove owned additions.

## Evidence and boundaries

`lune run tests/run_appearance_mapping.luau` covers initial native restrictions,
property and instance changes, extension revisions, original restoration,
respawn, cloned body effects, clothing, disable and reload. These suites
also pass using real Roblox instances and events in the connected client.
The accessory admission suite also checks raw catalog items whose
`AccessoryType` is `Unknown`: resolve the category from supplied catalog
metadata, saved catalog category, or MarketplaceService before native admission.
An unknown category must not be mistaken for an experience restriction.
Generated-root and verification-event regressions pass separately.

Live RIVALS verification confirms the replacement leg uses the experience's
generated meshes rather than the saved Korblox meshes. A full live RIVALS
death/ragdoll sequence remains unverified; controlled cloned bodies are tested.
Frame drops reported during the investigation remain unresolved.

Identity cannot distinguish a newly granted item identical to the baseline;
it receives the same substitution. Assigning a property its existing Larp value
does not expose a distinct native property event, so that intent is unobservable.
Stripped clone metadata, unrelated models without reliable player identity, and
custom geometry rules absent from native generation are outside this mapping.
Old versions did not retain write provenance: existing contaminated source
values may require a fresh game spawn when migrating from those versions.
