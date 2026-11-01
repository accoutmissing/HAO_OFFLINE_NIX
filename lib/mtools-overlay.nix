{ lib }:
_final: prev:
{
  mtools =
    if lib.versionAtLeast prev.mtools.version "4.0.50" then
      prev.mtools
    else if prev.mtools.version == "4.0.49" then
      prev.mtools.overrideAttrs
        (_old: {
          version = "4.0.50";
          src = prev.fetchurl {
            url = "mirror://gnu/mtools/mtools-4.0.50.tar.bz2";
            hash = "sha256-86WObPwmNLA8JARCVI47ABA2kjV6/Cjh5xBHRN1keLU=";
          };
        })
    else
      throw "mtools ${prev.mtools.version} is older than the fixed 4.0.50 release for CVE-2026-118384";
}
