# builder for Emacs packages built for packages.el
# using MELPA package-build.el

{ lib, stdenv, fetchFromGitHub, emacs, texinfo, writeText }:

with lib;

{ /*
    pname: Nix package name without special symbols and without version or
    "emacs-" prefix.
  */
  pname
  /*
    ename: Original Emacs package name, possibly containing special symbols.
  */
, ename ? null
, version
, recipe
, meta ? {}
, ...
}@args:

let

  defaultMeta = {
    homepage = args.src.meta.homepage or "http://melpa.org/#/${pname}";
  };

in

import ./generic.nix { inherit lib stdenv emacs texinfo writeText; } ({

  ename =
    if ename == null
    then pname
    else ename;

  packageBuild = fetchFromGitHub {
    owner = "melpa";
    repo = "package-build";
    rev = "0a22c3fbbf661822ec1791739953b937a12fa623";
    sha256 = "0dpy5p34il600sc8ic5jdgb3glya9si3lrvhxab0swks8fdydjgs";
  };

  elpa2nix = ./elpa2nix.el;
  melpa2nix = ./melpa2nix.el;

  preUnpack = ''
    mkdir -p "$NIX_BUILD_TOP/recipes"
    if [ -n "$recipe" ]; then
      cp "$recipe" "$NIX_BUILD_TOP/recipes/$ename"
    fi

    ln -s "$packageBuild" "$NIX_BUILD_TOP/package-build"

    mkdir -p "$NIX_BUILD_TOP/packages"
  '';

  postUnpack = ''
    mkdir -p "$NIX_BUILD_TOP/working"
    ln -s "$NIX_BUILD_TOP/$sourceRoot" "$NIX_BUILD_TOP/working/$ename"
  '';

  buildPhase = ''
    runHook preBuild

    cd "$NIX_BUILD_TOP"

    emacs --batch -Q \
        --eval "(setq comp-enable-subr-trampolines nil)" \
        -L "$NIX_BUILD_TOP/package-build" \
        -l "$melpa2nix" \
        -f melpa2nix-build-package \
        $ename $version

    runHook postBuild
    '';

  installPhase = ''
    runHook preInstall

    archive="$NIX_BUILD_TOP/packages/$ename-$version.el"
    if [ ! -f "$archive" ]; then
        archive="$NIX_BUILD_TOP/packages/$ename-$version.tar"
    fi

    emacs --batch -Q \
        --eval "(setq comp-enable-subr-trampolines nil)" \
        -l "$elpa2nix" \
        -f elpa2nix-install-package \
        "$archive" "$out/share/emacs/site-lisp/elpa"

    runHook postInstall
  '';

  meta = defaultMeta // meta;
}

// removeAttrs args [ "meta" ])
