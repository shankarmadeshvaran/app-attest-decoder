#!/usr/bin/env python3
"""Regenerate AppAttestDecoder.xcodeproj from Sources/AppAttestDecoder. Run from the repository root:

    python3 script/generate_xcodeproj.py .

Run it after adding, removing, or renaming a source or resource file. Object IDs are
derived from file paths, so the output is deterministic."""
import hashlib, os, sys
root = sys.argv[1]
src = "Sources/AppAttestDecoder"
def oid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

groups = {}
for sub in ["App", "Models", "Services", "Stores", "Views", "Resources"]:
    groups[sub] = sorted(f for f in os.listdir(os.path.join(root, src, sub)) if not f.startswith("."))
swift = [(g, f) for g in groups for f in groups[g] if f.endswith(".swift")]
res = [("Resources", f) for f in groups["Resources"]]
ftype = {".swift": "sourcecode.swift", ".py": "text.script.python", ".json": "text.json", ".icns": "image.icns", ".plist": "text.plist.xml"}

P = oid("project"); T = oid("target"); MAIN = oid("maingroup"); PRODG = oid("products"); APP = oid("product.app")
SRCG = oid("group.src"); SUPG = oid("group.support"); PLIST = oid("file.infoplist")
SP = oid("phase.sources"); RP = oid("phase.resources"); FP = oid("phase.frameworks")
PCL = oid("cfglist.project"); TCL = oid("cfglist.target")
PD, PR, TD, TR = oid("cfg.p.debug"), oid("cfg.p.release"), oid("cfg.t.debug"), oid("cfg.t.release")
fref = lambda g, f: oid("ref." + g + "/" + f)
bfile = lambda g, f: oid("build." + g + "/" + f)

o = []
w = o.append
w("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n")
w("\n/* Begin PBXBuildFile section */\n")
for g, f in swift:
    w(f"\t\t{bfile(g,f)} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref(g,f)} /* {f} */; }};\n")
for g, f in res:
    w(f"\t\t{bfile(g,f)} /* {f} in Resources */ = {{isa = PBXBuildFile; fileRef = {fref(g,f)} /* {f} */; }};\n")
w("/* End PBXBuildFile section */\n\n/* Begin PBXFileReference section */\n")
w(f"\t\t{APP} /* AppAttestDecoder.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = AppAttestDecoder.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n")
w(f"\t\t{PLIST} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n")
for g in groups:
    for f in groups[g]:
        t = ftype[os.path.splitext(f)[1]]
        p = f'"{f}"' if ("+" in f or "-" in f) else f
        w(f"\t\t{fref(g,f)} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = {t}; path = {p}; sourceTree = \"<group>\"; }};\n")
w("/* End PBXFileReference section */\n\n/* Begin PBXFrameworksBuildPhase section */\n")
w(f"\t\t{FP} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
w("/* End PBXFrameworksBuildPhase section */\n\n/* Begin PBXGroup section */\n")
def group(id_, name, children, path=None):
    pathline = f"\t\t\tpath = {path};\n" if path else ""
    nameline = "" if path == name or path is None and name is None else (f"\t\t\tname = {name};\n" if path and name and name != path else "")
    kids = "".join(f"\t\t\t\t{c} /* {n} */,\n" for c, n in children)
    w(f"\t\t{id_}{' /* '+name+' */' if name else ''} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{kids}\t\t\t);\n{nameline}{pathline}\t\t\tsourceTree = \"<group>\";\n\t\t}};\n")
group(MAIN, None, [(SRCG, "AppAttestDecoder"), (SUPG, "XcodeSupport"), (PRODG, "Products")])
group(SRCG, "AppAttestDecoder", [(oid("group." + g), g) for g in groups], path=src)
for g in groups:
    group(oid("group." + g), g, [(fref(g, f), f) for f in groups[g]], path=g)
group(SUPG, "XcodeSupport", [(PLIST, "Info.plist")], path="XcodeSupport")
group(PRODG, "Products", [(APP, "AppAttestDecoder.app")])
w("/* End PBXGroup section */\n\n/* Begin PBXNativeTarget section */\n")
w(f"""\t\t{T} /* AppAttestDecoder */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {TCL} /* Build configuration list for PBXNativeTarget "AppAttestDecoder" */;
\t\t\tbuildPhases = (
\t\t\t\t{SP} /* Sources */,
\t\t\t\t{FP} /* Frameworks */,
\t\t\t\t{RP} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = AppAttestDecoder;
\t\t\tproductName = AppAttestDecoder;
\t\t\tproductReference = {APP} /* AppAttestDecoder.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{P} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2600;
\t\t\t\tLastUpgradeCheck = 2600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{T} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {PCL} /* Build configuration list for PBXProject "AppAttestDecoder" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {MAIN};
\t\t\tproductRefGroup = {PRODG} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{T} /* AppAttestDecoder */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{RP} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
""")
for g, f in res: w(f"\t\t\t\t{bfile(g,f)} /* {f} in Resources */,\n")
w(f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{SP} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
""")
for g, f in swift: w(f"\t\t\t\t{bfile(g,f)} /* {f} in Sources */,\n")
w("\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase section */\n\n/* Begin XCBuildConfiguration section */\n")
common = {
 "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
 "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
 "GCC_C_LANGUAGE_STANDARD": "gnu17", "MACOSX_DEPLOYMENT_TARGET": "14.0", "SDKROOT": "macosx",
 "SWIFT_VERSION": "6.0", "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
}
dbg = {"DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_OPTIMIZATION_LEVEL": "0",
       "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"', "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"', "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE"}
rel = {"DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"', "ENABLE_NS_ASSERTIONS": "NO", "SWIFT_COMPILATION_MODE": "wholemodule", "MTL_ENABLE_DEBUG_INFO": "NO"}
target = {
 "CODE_SIGN_IDENTITY": '"-"', "CODE_SIGN_STYLE": "Manual", "DEVELOPMENT_TEAM": '""', "PROVISIONING_PROFILE_SPECIFIER": '""',
 "COMBINE_HIDPI_IMAGES": "YES", "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "0.1.0",
 "ENABLE_HARDENED_RUNTIME": "NO", "ENABLE_APP_SANDBOX": "NO",
 "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_FILE": "XcodeSupport/Info.plist",
 "INFOPLIST_KEY_CFBundleDisplayName": '"App Attest Decoder"',
 "INFOPLIST_KEY_LSApplicationCategoryType": '"public.app-category.developer-tools"',
 "INFOPLIST_KEY_NSHumanReadableCopyright": '"Copyright © 2026 Shankar Madeshvaran. MIT License."',
 "LD_RUNPATH_SEARCH_PATHS": '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/../Frameworks",\n\t\t\t\t)',
 "PRODUCT_BUNDLE_IDENTIFIER": "com.local.appattestdecoder", "PRODUCT_NAME": "AppAttestDecoder",
 "SWIFT_EMIT_LOC_STRINGS": "YES",
}
def cfg(id_, name, settings):
    body = "".join(f"\t\t\t\t{k} = {v};\n" for k, v in sorted(settings.items()))
    w(f"\t\t{id_} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {{\n{body}\t\t\t}};\n\t\t\tname = {name};\n\t\t}};\n")
cfg(PD, "Debug", {**common, **dbg}); cfg(PR, "Release", {**common, **rel})
cfg(TD, "Debug", target); cfg(TR, "Release", target)
w("/* End XCBuildConfiguration section */\n\n/* Begin XCConfigurationList section */\n")
for id_, kind, a, b in [(PCL, 'PBXProject "AppAttestDecoder"', PD, PR), (TCL, 'PBXNativeTarget "AppAttestDecoder"', TD, TR)]:
    w(f"\t\t{id_} /* Build configuration list for {kind} */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{a} /* Debug */,\n\t\t\t\t{b} /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n")
w(f"/* End XCConfigurationList section */\n\t}};\n\trootObject = {P} /* Project object */;\n}}\n")
os.makedirs(os.path.join(root, "AppAttestDecoder.xcodeproj/xcshareddata/xcschemes"), exist_ok=True)
open(os.path.join(root, "AppAttestDecoder.xcodeproj/project.pbxproj"), "w").write("".join(o))
ref = f'''<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{T}"
               BuildableName = "AppAttestDecoder.app"
               BlueprintName = "AppAttestDecoder"
               ReferencedContainer = "container:AppAttestDecoder.xcodeproj">
            </BuildableReference>'''
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            {ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
open(os.path.join(root, "AppAttestDecoder.xcodeproj/xcshareddata/xcschemes/AppAttestDecoder.xcscheme"), "w").write(scheme)
print(len(swift), "swift,", len(res), "resources")
