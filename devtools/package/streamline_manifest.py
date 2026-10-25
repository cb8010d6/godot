#!/usr/bin/env python3
"""Read the shared Streamline release manifest without downloading any files.

The editor installer and game exporter compile the same header. Packaging uses
this parser instead of copying arbitrary sl.* or nvngx_* DLLs from bin/.
"""

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

STRING_FIELDS = (
    "SDK_VERSION",
    "DOWNLOAD_URL",
    "DOWNLOAD_FILE",
    "DOWNLOAD_SHA256",
    "RELEASE_URL",
    "LICENSE_URL",
    "THIRD_PARTY_URL",
    "ZIP_DIR",
)
REQUIRED_FILES = {
    "sl.interposer.dll",
    "sl.common.dll",
    "sl.dlss.dll",
    "sl.dlss_d.dll",
    "sl.dlss_g.dll",
    "sl.reflex.dll",
    "sl.pcl.dll",
    "nvngx_dlss.dll",
    "nvngx_dlssd.dll",
    "nvngx_dlssg.dll",
    "NvLowLatencyVk.dll",
    "nvngx_dlss.license.txt",
    "reflex.license.txt",
    "nis.license.txt",
}


def parse_manifest(source, sdk_version):
    """Reject drift, unsafe paths and incomplete feature sets before packaging."""
    result = {}
    for field in STRING_FIELDS:
        matches = re.findall(r"\b" + field + r'\s*=\s*"([^"\n]+)"\s*;', source)
        if len(matches) != 1:
            raise ValueError("Expected one string literal for " + field)
        result[field.lower()] = matches[0]
    size = re.findall(r"\bDOWNLOAD_SIZE\s*=\s*(\d+)\s*;", source)
    if len(size) != 1 or not 0 < int(size[0]) <= 2**31 - 1:
        raise ValueError("DOWNLOAD_SIZE must fit HTTPRequest's positive 32-bit body limit")
    result["download_size"] = int(size[0])
    version = result["sdk_version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or version != sdk_version:
        raise ValueError("Runtime release and vendored SDK header versions differ")
    release = "https://github.com/NVIDIA-RTX/Streamline/releases/"
    filename = "streamline-sdk-v" + version + ".zip"
    if (
        result["download_file"] != filename
        or result["download_url"] != release + "download/v" + version + "/" + filename
    ):
        raise ValueError("Download URL and filename must pin the compiled SDK version")
    if result["release_url"] != release + "tag/v" + version:
        raise ValueError("Release URL must pin the compiled SDK version")
    source_url = "https://github.com/NVIDIA-RTX/Streamline/blob/v" + version + "/"
    if (
        result["license_url"] != source_url + "license.txt"
        or result["third_party_url"] != source_url + "3rd-party-licenses.md"
    ):
        raise ValueError("License links must pin the compiled SDK version")
    if not re.fullmatch(r"[a-f0-9]{64}", result["download_sha256"]):
        raise ValueError("Expected a SHA-256 digest")
    if result["zip_dir"] != "bin/x64/":
        raise ValueError("Only the x64 release runtime directory is supported")
    arrays = re.findall(r"\bRUNTIME_FILES\[\]\s*=\s*\{([^}]+)\};", source)
    if len(arrays) != 1:
        raise ValueError("Expected one runtime file list")
    files = []
    for line in arrays[0].splitlines():
        line = line.strip()
        if not line:
            continue
        match = re.fullmatch(r'"([A-Za-z0-9_.-]+)",', line)
        if not match or not match[1].lower().endswith((".dll", ".license.txt")):
            raise ValueError("Runtime files must be release DLL/license basenames")
        files.append(match[1])
    if len(files) != len({name.lower() for name in files}):
        raise ValueError("Duplicate Windows runtime filename")
    if not REQUIRED_FILES.issubset(files):
        raise ValueError("Runtime file list omits an existing DLSS/Reflex feature or license")
    result["runtime_files"] = files
    # Preserve the existing private package's deliberate Nsight Perf exclusion.
    result["private_runtime_files"] = [name for name in files if name != "sl.nvperf.dll"]
    return result


def load_manifest(root):
    header = (root / "thirdparty/streamline/include/sl_version.h").read_text(encoding="utf-8")
    values = [
        re.search(r"^#define SL_VERSION_" + field + r"\s+(\d+)\s*$", header, re.MULTILINE)
        for field in ("MAJOR", "MINOR", "PATCH")
    ]
    if any(value is None for value in values):
        raise ValueError("Missing SDK version definitions")
    version = ".".join(value[1] for value in values)
    return parse_manifest((root / "drivers/streamline/streamline_runtime.h").read_text(encoding="utf-8"), version)


def validate_archive_members(archive, manifest):
    """Development DLLs must never stand in for required signed release files."""
    for filename in manifest["runtime_files"]:
        name = manifest["zip_dir"] + filename
        matches = [info for info in archive.infolist() if info.filename == name]
        if len(matches) != 1 or matches[0].is_dir() or matches[0].file_size == 0:
            raise ValueError("Missing, duplicate or empty release archive entry: " + name)


def validate_vendored_sdk(archive, vendor_root):
    """Allow Git's CRLF-to-LF conversion, but reject mixed or edited SDK files."""
    headers = [
        info
        for info in archive.infolist()
        if not info.is_dir() and re.fullmatch(r"include/(?:[^/]+/)*[^/]+\.h", info.filename)
    ]
    archive_headers = {info.filename[len("include/") :]: info for info in headers}
    if not headers or len(headers) != len(archive_headers):
        raise ValueError("SDK archive has missing or duplicate public headers")
    include_root = vendor_root / "include"
    vendored_headers = {
        path.relative_to(include_root).as_posix(): path for path in include_root.rglob("*.h") if path.is_file()
    }
    if archive_headers.keys() != vendored_headers.keys():
        missing = sorted(archive_headers.keys() - vendored_headers.keys())
        unexpected = sorted(vendored_headers.keys() - archive_headers.keys())
        raise ValueError(
            f"Vendored SDK header inventory differs from the release (missing: {missing}, extra: {unexpected})"
        )
    for name, info in archive_headers.items():
        if archive.read(info).replace(b"\r\n", b"\n") != vendored_headers[name].read_bytes().replace(b"\r\n", b"\n"):
            raise ValueError("Vendored SDK header differs from the release: " + name)
    licenses = [info for info in archive.infolist() if info.filename == "license.txt" and not info.is_dir()]
    license_path = vendor_root / "LICENSE.txt"
    if len(licenses) != 1 or not license_path.is_file():
        raise ValueError("SDK archive or vendored SDK has a missing or duplicate license")
    if archive.read(licenses[0]).replace(b"\r\n", b"\n") != license_path.read_bytes().replace(b"\r\n", b"\n"):
        raise ValueError("Vendored SDK license differs from the release")


def validate_archive(path, manifest, vendor_root=None):
    if path.stat().st_size != manifest["download_size"]:
        raise ValueError("Archive size differs from the pinned release")
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != manifest["download_sha256"]:
        raise ValueError("Archive SHA-256 differs from the pinned release")
    with zipfile.ZipFile(path) as archive:
        validate_archive_members(archive, manifest)
        if vendor_root is not None:
            validate_vendored_sdk(archive, vendor_root)


def validate_public_package(path):
    """Public editor and export-template archives must exclude NVIDIA runtimes."""
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            name = entry.filename.replace("\\", "/").rsplit("/", 1)[-1].lower()
            if name.endswith(".dll") and (name.startswith(("sl.", "nvngx_")) or name == "nvlowlatencyvk.dll"):
                raise ValueError("NVIDIA runtime is forbidden in a public package: " + entry.filename)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument(
        "--archive", type=Path, help="Validate an SDK ZIP and compare vendored headers/license (offline)"
    )
    parser.add_argument(
        "--public-package", type=Path, help="Reject NVIDIA runtime DLLs in a public editor ZIP or template TPZ"
    )
    args = parser.parse_args()
    try:
        manifest = load_manifest(args.root)
        if args.archive:
            validate_archive(args.archive, manifest, args.root / "thirdparty/streamline")
        if args.public_package:
            validate_public_package(args.public_package)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, str(error) + "\n")
    if args.public_package:
        print("Public package contains no NVIDIA runtime DLLs.")
    else:
        print(json.dumps(manifest))


if __name__ == "__main__":
    main()
