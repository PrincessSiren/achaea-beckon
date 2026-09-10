#!/usr/bin/env python3
"""Pack AchaeaBeckon.lua plus the alias table below into a Mudlet package.

Produces two things next to this script:

  AchaeaBeckon.xml       drag-and-drop installable, and committed to the repo
  AchaeaBeckon.mpackage  the zip form Mudlet's package manager prefers

The shape is deliberate: real <Alias> elements inside one <AliasGroup> so they
can be read in Mudlet's Editor, and ALIASES as the single source of truth for
both the XML and the beckonlist.COMMANDS table appended to the Lua, so the
in-game help cannot drift from what is installed.

The one trigger this package needs is *not* declared here. It is created at
runtime with tempRegexTrigger, because its pattern is a setting: a capture
settles what the game prints today, and this reflex should outlive that (see
the header of AchaeaBeckon.lua), so `beckonlist pattern` has to be able to
correct it in game and persist that, which a declared <Trigger> element
cannot do.
"""

from __future__ import annotations

import hashlib
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

HERE = Path(__file__).parent

# Where a recipient can get the Corresponding Source. GPL-3 asks that they be
# able to, and the .mpackage ships the *generated* .xml rather than the .lua and
# build.py that are the preferred form for making modifications -- so the
# package cannot serve as its own source, and has to say where the source is.
SOURCE_URL = "https://github.com/PrincessSiren/achaea-beckon"
LUA = HERE / "AchaeaBeckon.lua"
XML = HERE / "AchaeaBeckon.xml"
MPACKAGE = HERE / "AchaeaBeckon.mpackage"

PACKAGE_NAME = "AchaeaBeckon"

# Mudlet's scmMudletXmlDefaultVersion (src/mudlet.h).
XML_VERSION = "1.001"

# (name, regex, lua, usage, help)
#
# Every argument-taking alias takes it as an optional trailing group, because
# Mudlet hands an unmatched group over as "" rather than nil and the Lua treats
# both as "no argument" -- which is what lets `beckonlist pattern` report and
# `beckonlist pattern <regex>` set, on one alias.
ALIASES: list[tuple[str, str, str, str, str]] = [
    (
        "help",
        r"^beckonlist$",
        "beckonlist.report()",
        "beckonlist",
        "how many names can move you, and this command list",
    ),
    (
        "status",
        r"^beckonlist\s+status$",
        "beckonlist.status()",
        "beckonlist status",
        "on or off, who is trusted, and where the list is saved",
    ),
    (
        "who",
        r"^beckonlist\s+who$",
        "beckonlist.trustList()",
        "beckonlist who",
        "who is allowed to beckon you, since when, and why",
    ),
    (
        "add",
        r"^beckonlist\s+add(?:\s+(.+))?$",
        "beckonlist.trustAdd(matches[2])",
        "beckonlist add <name>[: why]",
        "let a name move you -- the note is optional and kept on a re-add",
    ),
    (
        "rm",
        r"^beckonlist\s+rm(?:\s+(.+))?$",
        "beckonlist.trustRemove(matches[2])",
        "beckonlist rm <name>",
        "take a name back off the list",
    ),
    (
        "on",
        r"^beckonlist\s+on$",
        "beckonlist.arm(true)",
        "beckonlist on",
        "arm it: a trusted beckon follows automatically",
    ),
    (
        "off",
        r"^beckonlist\s+off$",
        "beckonlist.arm(false)",
        "beckonlist off",
        "disarm it: every beckon is still reported, nothing is sent",
    ),
    (
        "follow",
        r"^beckonlist\s+follow(?:\s+(.+))?$",
        "beckonlist.setFollow(matches[2])",
        "beckonlist follow [cmd]",
        "what a trusted beckon sends, `fol` by default (HELP 6.4)",
    ),
    # The pattern is a setting because the line behind it is not evidence yet.
    (
        "pattern",
        r"^beckonlist\s+pattern(?:\s+(.+))?$",
        "beckonlist.setPattern(matches[2])",
        "beckonlist pattern [regex|default]",
        "the line it watches for; the capture is the name",
    ),
    (
        "test",
        r"^beckonlist\s+test(?:\s+(.+))?$",
        "beckonlist.test(matches[2])",
        "beckonlist test <line>",
        "paste a real beckon line and see what it would do -- sends nothing",
    ),
    (
        "last",
        r"^beckonlist\s+last$",
        "beckonlist.last()",
        "beckonlist last",
        "the beckons seen this session and what was done about each",
    ),
    (
        "diag",
        r"^beckonlist\s+diag$",
        "beckonlist.diag()",
        "beckonlist diag",
        "build stamp, the live trigger, the pattern, and what it would send",
    ),
]

XML_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE MudletPackage>
<MudletPackage version="{xml_version}">
    <ScriptPackage>
        <Script isActive="yes" isFolder="no">
            <name>{package}</name>
            <packageName>{package}</packageName>
            <script>{script}</script>
            <eventHandlerList />
        </Script>
    </ScriptPackage>
    <AliasPackage>
        <AliasGroup isActive="yes" isFolder="yes">
            <name>{package}</name>
            <script></script>
            <command></command>
            <packageName>{package}</packageName>
            <regex></regex>
{aliases}        </AliasGroup>
    </AliasPackage>
</MudletPackage>
"""

ALIAS_TEMPLATE = """            <Alias isActive="yes" isFolder="no">
                <name>{name}</name>
                <script>{script}</script>
                <command></command>
                <packageName>{package}</packageName>
                <regex>{regex}</regex>
            </Alias>
"""


def read_version(lua_source: str) -> str:
    for raw in lua_source.splitlines():
        line = raw.strip()
        if line.startswith("M.VERSION"):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return "0.0.0"


def lua_quote(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_stamp(lua_source: str) -> str:
    """Short digest of everything that ends up in the package.

    A content hash rather than a timestamp, because the .xml is committed: two
    builds with no source change must be byte-identical. `beckonlist diag`
    prints it back, which is the only reliable answer to "is Mudlet running
    what is on disk?" -- the version says what you expect whether or not you
    rebuilt.
    """
    material = lua_source + "\x00".join("\x00".join(row) for row in ALIASES)
    return hashlib.sha256(material.encode("utf-8")).hexdigest()[:8]


def commands_lua(lua_source: str) -> str:
    rows = "".join(
        f"    {{ usage = {lua_quote(usage)}, help = {lua_quote(help)} }},\n"
        for _name, _regex, _lua, usage, help in ALIASES
    )
    return (
        "\n-- Generated by build.py from its ALIASES table. Do not edit here.\n"
        f"beckonlist.BUILD = {lua_quote(build_stamp(lua_source))}\n"
        f"beckonlist.COMMANDS = {{\n{rows}}}\n"
    )


def config_lua(version: str) -> str:
    return (
        f'mpackage = "{PACKAGE_NAME}"\n'
        f'version = "{version}"\n'
        f'author = "PrincessSiren"\n'
        f'title = "Beckon whitelist for Achaea"\n'
        f"description = [[Watches for someone beckoning you. A name on your "
        f"trusted list is followed automatically; anyone else gets a red line "
        f"and nothing is sent. Type `beckonlist` in game for the commands. Source and licence (GPL-3): {SOURCE_URL}]]\n"
        f'license = "GPL-3.0-or-later"\n'
        f'source = "{SOURCE_URL}"\n'
    )


def license_text() -> str:
    """The licence this package ships under.

    Looked for beside build.py first, then up the tree: a package that has been
    split out into its own repository carries its own copy, one still in the
    workshop shares the root one, and the same build.py works either way.

    It goes *inside* the .mpackage because Mudlet's package format has no
    licence field -- config.lua carries mpackage, version, author, title and
    description and nothing else -- so this file is the only way the terms
    reach anyone who installs the package.
    """
    for path in (HERE / "LICENSE", *(p / "LICENSE" for p in HERE.parents)):
        if path.is_file():
            return path.read_text(encoding="utf-8")
    raise SystemExit("no LICENSE beside build.py or anywhere above it")


def build() -> None:
    handwritten = LUA.read_text(encoding="utf-8")
    lua_source = handwritten + commands_lua(handwritten)
    version = read_version(lua_source)
    stamp = build_stamp(handwritten)

    aliases = "".join(
        ALIAS_TEMPLATE.format(
            name=escape(name),
            script=escape(lua),
            package=PACKAGE_NAME,
            regex=escape(regex),
        )
        for name, regex, lua, _usage, _help in ALIASES
    )

    XML.write_text(
        XML_TEMPLATE.format(
            xml_version=XML_VERSION,
            package=PACKAGE_NAME,
            script=escape(lua_source),
            aliases=aliases,
        ),
        encoding="utf-8",
    )

    with zipfile.ZipFile(MPACKAGE, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(f"{PACKAGE_NAME}.xml", XML.read_text(encoding="utf-8"))
        archive.writestr("config.lua", config_lua(version))
        archive.writestr("LICENSE", license_text())

    print(f"{PACKAGE_NAME} {version} build {stamp} ({len(ALIASES)} aliases)")
    print(f"  `beckonlist diag` in Mudlet should say build {stamp}; "
          f"anything else is a stale install")
    print(f"  wrote {XML.relative_to(HERE.parent)}")
    print(f"  wrote {MPACKAGE.relative_to(HERE.parent)}")


if __name__ == "__main__":
    build()
