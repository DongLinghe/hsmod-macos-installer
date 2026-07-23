#!/bin/zsh
set -euo pipefail

SOURCE_ROOT="${1:-}"

fail() {
    echo "error: $1" >&2
    exit 1
}

[ -n "$SOURCE_ROOT" ] || fail "missing HsMod source root"
[ -f "$SOURCE_ROOT/HsMod/HsMod.csproj" ] || fail "could not find HsMod/HsMod.csproj in: $SOURCE_ROOT"

HSMOD_DIR="$SOURCE_ROOT/HsMod"
CSProj="$HSMOD_DIR/HsMod.csproj"
WEBPAGE="$SOURCE_ROOT/HsMod/WebPage.cs"
WEBSERVER="$SOURCE_ROOT/HsMod/WebServer.cs"

[ -f "$WEBPAGE" ] || fail "missing HsMod/WebPage.cs"
[ -f "$WEBSERVER" ] || fail "missing HsMod/WebServer.cs"

/usr/bin/perl -0pi -e 's#\n\s*<Reference Include="QRCoderUnity[^"]*">\s*\n\s*<SpecificVersion>False</SpecificVersion>\s*\n\s*<HintPath>LibHearthstone\\QRCoderUnity\.dll</HintPath>\s*\n\s*</Reference>##g' "$CSProj"

if ! /usr/bin/grep -q 'Microsoft.NETFramework.ReferenceAssemblies.net48' "$CSProj"; then
    /usr/bin/perl -0pi -e 's#\n\s*<Import Project="\$\(MSBuildToolsPath\)\\Microsoft\.CSharp\.targets" />#\n  <ItemGroup>\n    <PackageReference Include="Microsoft.NETFramework.ReferenceAssemblies.net48" Version="1.0.3" PrivateAssets="All" />\n  </ItemGroup>\n  <Import Project="\$(MSBuildToolsPath)\\Microsoft.CSharp.targets" />#' "$CSProj"
fi

/usr/bin/perl -0pi -e 's#<PostBuildEvent>\s*\$\(ProjectDir\)\\install\.bat\s*</PostBuildEvent>#<PostBuildEvent>\n    </PostBuildEvent>#g' "$CSProj"
/usr/bin/perl -0pi -e 's#GenerateBtn\(\)\.Replace\("<br/>", ""\)\.Split\("<br />"\)#GenerateBtn().Replace("<br/>", "").Split(new[] { "<br />" }, StringSplitOptions.None)#g' "$WEBPAGE"
while IFS= read -r cs_file; do
    /usr/bin/perl -0pi -e 's#result\.TryAdd\(pair\.Key, 9\);#result[pair.Key] = 9;#g; s#result\.TryAdd\(pair\.Key, pair\.Value\);#result[pair.Key] = pair.Value;#g' "$cs_file"
done < <(/usr/bin/find "$HSMOD_DIR" -name '*.cs' -print)
/usr/bin/perl -0pi -e 's#http://\+:\{CommandConfig\.webServerPort\}/#http://127.0.0.1:{CommandConfig.webServerPort}/#g; s#await File\.ReadAllBytesAsync\(preUrl\)#File.ReadAllBytes(preUrl)#g' "$WEBSERVER"

/usr/bin/grep -q 'Microsoft.NETFramework.ReferenceAssemblies.net48' "$CSProj" || fail "failed to add .NET Framework reference assemblies package"
! /usr/bin/grep -q 'QRCoderUnity' "$CSProj" || fail "failed to remove missing QRCoderUnity reference"
! /usr/bin/grep -q 'install.bat' "$CSProj" || fail "failed to disable Windows-only post-build step"
! /usr/bin/grep -q 'Split("<br />")' "$WEBPAGE" || fail "failed to patch WebPage Split overload"
! /usr/bin/grep -R -q 'result.TryAdd(pair.Key' "$HSMOD_DIR" || fail "failed to patch Dictionary TryAdd calls"
! /usr/bin/grep -q 'http://+:{CommandConfig.webServerPort}/' "$WEBSERVER" || fail "failed to bind WebServer to 127.0.0.1"
! /usr/bin/grep -q 'ReadAllBytesAsync(preUrl)' "$WEBSERVER" || fail "failed to patch WebServer file read API"

echo "patch: applied macOS compatibility edits"
