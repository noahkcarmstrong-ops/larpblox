const fs = require('fs');
const source = fs.readFileSync('native_avatar_views.lua', 'utf8');
const start = source.indexOf('local function clearVerification()');
const end = source.indexOf('local function restoreImage', start);
if (start < 0 || end < 0) throw new Error('verification renderer block is missing');
const block = source.slice(start, end);

if (!block.includes('renderingVerification')) throw new Error('renderer lacks reentrancy guard');
if (!block.includes('clearVerification();renderingVerification=false;return')) throw new Error('off state does not clean up');
if (!block.includes('VerifiedBadgeNameIcon.png')) throw new Error('native verified badge asset is missing');
if (!block.includes('verificationBadges[object]')) throw new Error('native row badge lifecycle is missing');
if (!block.includes('gsub("%s*%(You%)%s*$","")')) throw new Error('own-row suffix normalization is missing');
if (block.includes('object.Text=')) throw new Error('renderer must not rewrite Roblox-owned text');

const character = source.slice(source.indexOf('local function bindVerificationCharacter'), source.indexOf('local function restoreImage'));
if (!character.includes('queueVerification()')) throw new Error('respawn must refresh badges without watching accessory additions');
if (!source.includes('player.CharacterAdded:Connect(bindVerificationCharacter)')) throw new Error('CharacterAdded hook is missing');
if (!source.includes('verificationCharacterConnections')) throw new Error('character connection cleanup state is missing');

console.log('verification badge lifecycle source checks passed');
