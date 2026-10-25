{
  pkgs,
  lib,
  stdenvNoCC,
  writeShellScript,
  makeWrapper,
  mkM2Repository,
  updateVerificationMetadata,
}: {
  pname,
  version,
  src,
  meta ? {},
  env ? {},
  jdk ? pkgs.jdk,
  gradle ? pkgs.gradle,
  buildInputs ? [],
  nativeBuildInputs ? [],
  dependencyFilter ? depSpec: true,
  repositories ? ["https://plugins.gradle.org/m2/" "https://repo1.maven.org/maven2/"],
  verificationFile ? "gradle/verification-metadata.xml",
  buildTask ? ":installDist",
  installPhase,
  postFixup ? "",
}: let
  m2Repository = mkM2Repository {
    inherit pname version src dependencyFilter repositories verificationFile;
  };

  package = stdenvNoCC.mkDerivation {
    inherit pname version src buildInputs env installPhase meta postFixup;

    passthru = {
      inherit jdk gradle;
      updateVerificationMetadata = updateVerificationMetadata.override {inherit gradle;};
    };

    nativeBuildInputs = [gradle jdk makeWrapper] ++ nativeBuildInputs;
    buildPhase = ''
      runHook preBuild

      # Setup maven repo
      export MAVEN_SOURCE_REPOSITORY=${m2Repository.m2Repository}
      echo "Using maven repository at: $MAVEN_SOURCE_REPOSITORY"

      # create temporary gradle home
      export GRADLE_USER_HOME=$(mktemp -d)

      # Export application version to the build
      export APP_VERSION=${version}

      # built the dam thing!
      gradle --offline --no-daemon --no-watch-fs -Dorg.gradle.unsafe.isolated-projects=false --no-configuration-cache --no-build-cache -Dorg.gradle.console=plain --no-scan -Porg.gradle.java.installations.auto-download=false --init-script ${./init.gradle.kts} ${buildTask}

      runHook postBuild
    '';

    dontWrapGApps = true;
  };
in
  package
