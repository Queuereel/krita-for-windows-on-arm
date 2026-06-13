# -*- coding: utf-8 -*-
# Copyright Hannah von Reth <vonreth@kde.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

import glob
import os
from pathlib import Path

import info
import utils
from CraftCore import CraftCore
from Package.AutoToolsPackageBase import AutoToolsPackageBase
from Package.MSBuildPackageBase import MSBuildPackageBase
from Utils import CraftHash


class subinfo(info.infoclass):
    def setTargets(self):
        for ver in ["5.2.3"]:
            self.targets[ver] = f"http://tukaani.org/xz/xz-{ver}.tar.xz"
            self.targetInstSrc[ver] = f"xz-{ver}"

        self.targetDigests["5.2.3"] = (["7876096b053ad598c31f6df35f7de5cd9ff2ba3162e5a5554e4fc198447e0347"], CraftHash.HashAlgorithm.SHA256)

        self.description = "free general-purpose data compression software with high compression ratio"
        self.webpage = "https://tukaani.org/xz"
        self.defaultTarget = ver

    def setDependencies(self):
        self.runtimeDependencies["virtual/base"] = None

    def registerOptions(self):
        self.options.dynamic.registerOption("buildPrograms", not CraftCore.compiler.isAndroid)


class PackageMSBuild(MSBuildPackageBase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.subinfo.options.configure.projectFile = self.sourceDir() / "windows/xz_win.sln"
        self.msbuildTargets = ["liblzma_dll"]

    def configure(self):
        # The bundled xz 5.2.3 MSBuild solution/projects only define Win32 and x64
        # platforms. On arm64 we inject ARM64 configs (cloned from x64) so MSBuild
        # accepts Release|ARM64. Done here (post-unpack) so it survives re-extraction.
        if CraftCore.compiler.architecture == CraftCore.compiler.Architecture.arm64:
            if not self._injectArm64Configs():
                return False
        return super().configure()

    def _injectArm64Configs(self):
        import copy
        import xml.etree.ElementTree as ET

        windir = self.sourceDir() / "windows"
        ns = "http://schemas.microsoft.com/developer/msbuild/2003"
        ET.register_namespace("", ns)
        q = lambda t: f"{{{ns}}}{t}"

        for proj in ["liblzma.vcxproj", "liblzma_dll.vcxproj"]:
            path = windir / proj
            tree = ET.parse(path)
            root = tree.getroot()
            if any((pc.get("Include") or "").endswith("|ARM64") for pc in root.iter(q("ProjectConfiguration"))):
                continue  # already injected
            for ig in root.findall(q("ItemGroup")):
                if ig.get("Label") == "ProjectConfigurations":
                    for pc in list(ig.findall(q("ProjectConfiguration"))):
                        inc = pc.get("Include")
                        if inc.endswith("|x64"):
                            npc = copy.deepcopy(pc)
                            npc.set("Include", inc[:-4] + "|ARM64")
                            plat = npc.find(q("Platform"))
                            if plat is not None:
                                plat.text = "ARM64"
                            ig.append(npc)
            new_children = []
            for child in list(root):
                new_children.append(child)
                cond = child.get("Condition")
                if cond and "|x64'" in cond:
                    nchild = copy.deepcopy(child)
                    nchild.set("Condition", cond.replace("|x64'", "|ARM64'"))
                    for plat in nchild.iter(q("Platform")):
                        if plat.text == "x64":
                            plat.text = "ARM64"
                    for tm in nchild.iter(q("TargetMachine")):
                        if tm.text == "MachineX64":
                            tm.text = "MachineARM64"
                    new_children.append(nchild)
            root[:] = new_children
            tree.write(path, encoding="utf-8", xml_declaration=True)

        sln = windir / "xz_win.sln"
        text = sln.read_text(encoding="utf-8-sig")
        if "|ARM64" not in text:
            out = []
            for line in text.splitlines():
                out.append(line)
                if "|x64" in line:
                    out.append(line.replace("x64", "ARM64"))
            sln.write_text("\n".join(out) + "\n", encoding="utf-8-sig")
        return True

    def install(self):
        if not super().install(installHeaders=False):
            return False

        headerDir = self.sourceDir() / "src/liblzma/api"
        includeDir = self.installDir() / "include"
        header = glob.glob(os.path.join(headerDir, "**/*.h"), recursive=True)
        for h in header:
            h = Path(h)
            utils.copyFile(h, includeDir / h.relative_to(headerDir), linkOnly=False)
        return True


class PackageAutotools(AutoToolsPackageBase):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.subinfo.options.configure.autoreconf = False
        if not self.subinfo.options.dynamic.buildPrograms:
            self.subinfo.options.configure.args += ["--disable-xz", "--disable-lzmadec", "--disable-lzmainfo", "--disable-scripts", "--disable-xzdec"]


if CraftCore.compiler.isMSVC():

    class Package(PackageMSBuild):
        pass

else:

    class Package(PackageAutotools):
        pass
