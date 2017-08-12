# factorio-release-script
*License: CC-BY-SA-3.0 https://creativecommons.org/licenses/by-sa/3.0/legalcode*

by folk@folk.wtf

Lua script for releasing github-hosted Factorio mods.
1. Checks raw.githubusercontent.com if you have the latest version of the script
2. Reads semver and modname from info.json
3. Automatically puts all git shortlogs into the GitHub Releases description
4. Tags "vX.Y.Z"
5. Releases that tag, ZIPs it, and uploads it to the GH release

Requires https://github.com/zserge/luash, https://stedolan.github.io/jq/, and https://github.com/whiteinge/ok.sh
Please remember to set up ok.sh properly.

Invoke the script like so:
```
./release.lua 0 0 0
```
Where the numbers represent how much you want to increase the semver, if at all. If you pass "0 0 0", the semver will not be increased. If you pass "1 0 0", major gets +1, and if you pass "0 312 0", the minor gets +312. This gets committed to info.json automatically.

# Todo
* Obviously someone should actually make it take some real POSIX --flags in some fashion; there are probably 30 different ways of doing this in lua, none of which I particularly like :-P
* Get rid of most of the stdout from the commands and put out some proper progress text.
* Catch failes from git tag and friends, and maybe stop script execution.
