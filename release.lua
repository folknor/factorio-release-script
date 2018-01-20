#!/usr/bin/lua
local VERSION = 6
-- lua5.2 release script for factorio mods
-- by folk@folk.wtf
-- Requires https://github.com/zserge/luash, https://github.com/folknor/lua-github
-- Remember to set up ~/.netrc
-- https://github.com/folknor/factorio-release-script
-- LICENSE CC-BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0
local function exit(...) io.write(..., "\n") os.exit() end

local userId = os.getenv("FACTORIO_GIT_USER")
if type(userId) ~= "string" or #userId == 0 then exit("Set $FACTORIO_GIT_USER to your git username.") end

local sh = require("sh")
local _ = tostring
local curl = sh.command("curl")
local source = _(curl("-s", "https://raw.githubusercontent.com/folknor/factorio-release-script/master/release.lua"))
if type(source) == "string" then
	local currentVersion = tonumber(source:match("local VERSION = (%d+)"))
	if type(currentVersion) == "number" and currentVersion > VERSION then
		local answer
		repeat
			io.write("There is a new version of factorio-release-script available, do you want to exit (y/n)? ")
			io.flush()
			answer = io.read()
		until answer == "y" or answer == "n"
		if answer == "y" then return end
	end
end

-- Check for required shell commands
local which = sh.command("which")
for _, req in next, {"git", "cat", "sed"} do
	if which(req).__exitcode ~= 0 then exit(("`which %s` does not seem to return anything useful."):format(req)) end
end

local git = sh.command("git")

-- Check git status and see if we are up to date with our branch, or if we have unstaged changes
local _repoExists = true
local stat = _(git("status"))
if type(stat) ~= "string" or #stat == 0 or stat:find("Not a git repository") then
	_repoExists = false
elseif stat:find("to be committed") then
	exit("You seem to have commits ready for push, please check `git status`.")
elseif stat:find("not staged for commit") then
	exit("Please don't make a release while you have changes that are not staged for commit.")
elseif stat:find("Untracked files") then
	exit("You have untracked files, please check `git status`.")
elseif not stat:find("Your branch is up to date") then
	exit("You do not seem up to date with your branch, please check `git status`.")
end
if not _repoExists then exit("Current folder doesn't seem to contain a git repository.") end

-- Check that the current folder is a git repository, and store the repo name for later
local repo = _(git("rev-parse", "--show-toplevel"))
if type(repo) ~= "string" or #repo == 0 then exit("Current folder doesn't seem to contain a git repository.") end
repo = repo:match("^.*/([%w%-%_]+)$")

local _gh = require("lua-github").easy

local maj, min, patch = tonumber((select(1, ...))), tonumber((select(2, ...))), tonumber((select(3, ...)))
if type(maj) ~= "number" or type(min) ~= "number" or type(patch) ~= "number" then
	exit("Please provide an additive version number bump, like 0 0 10, 0 1 0, 1 0 2, or 0 0 0 for no bump.")
end
local mod = _(sh.command("cat")("info.json"))
local name = mod:match("\"name\":%s+\"(%S+)\"")
if type(name) ~= "string" or name:len() < 5 then exit("Could not parse name from info.json.") end
local function ton(...) return tonumber((select(1, ...))), tonumber((select(2, ...))), tonumber((select(3, ...))) end
local oMaj, oMin, oPatch = ton(mod:match("\"version\":%s+\"(%d+).(%d+).(%d+)\""))
-- lua string match to number
if type(oMaj) ~= "number" or type(oMin) ~= "number" or type(oPatch) ~= "number" then
	exit("Failed to parse mod version from info.json.")
end

local lastTag = _(git("for-each-ref", "--format=\"%(refname:short)\"", "--sort=-authordate", "--count=1", "refs/tags"))
local changes
if type(lastTag) == "string" and #lastTag ~= 0 then
	changes = _(git("log", lastTag .. "..HEAD", "--pretty=format:\"* %s\""))
else
	changes = _(git("log", "--pretty=format:\"* %s\""))
end
if type(changes) ~= "string" or #changes == 0 then
	changes = "* No changes detected since last release."
end

local version = "%d.%d.%d"
if maj ~= 0 or min ~= 0 or patch ~= 0 then
	version = version:format(oMaj + maj, oMin + min, oPatch + patch)
	local sed = sh.command("sed")
	sed("-i", ("'s/\"version\": \"[0-9]\\+.[0-9]\\+.[0-9]\\+\"/\"version\": %q/g'"):format(version), "info.json")
	git("add", "info.json")
	git("commit", "-m", "\"Prerelease version bump.\"")
	git("push")
else
	version = version:format(oMaj, oMin, oPatch)
end

local tag = "v" .. version
git("tag", tag)
git("push", "origin", tag) -- Commit the tag before we do the release post

local _, releaseJson = _gh.createRelease({
	tag_name = tag,
	name = tag,
	body = changes,
}, userId, repo)
if type(releaseJson) ~= "table" or not releaseJson.id or not releaseJson.upload_url then
	local serp = require("serpent")
	print("Could not create a github release for some reason.")
	print(serp.block(_))
	print(serp.block(releaseJson))
else
	local tuple = name .. "_" .. version
	local zip = tuple .. ".zip"
	git("archive", "--prefix=" .. tuple .. "/", "--output=" .. zip, tag)

	_gh.uploadReleaseAsset(
		userId,
		repo,
		releaseJson.id,
		zip, nil, nil, releaseJson.upload_url
	)
end
