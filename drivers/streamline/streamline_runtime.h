/**************************************************************************/
/*  streamline_runtime.h                                                  */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#pragma once

#include <cstdint>

// One release manifest for the editor installer, game export and private
// packaging. Public editor/template packages never contain these runtimes.
// Keep the literals machine-readable for devtools/package/streamline_manifest.py.
namespace StreamlineRuntime {

inline constexpr const char *SDK_VERSION = "2.14.16";
inline constexpr const char *DOWNLOAD_URL = "https://github.com/NVIDIA-RTX/Streamline/releases/download/v2.14.16/streamline-sdk-v2.14.16.zip";
inline constexpr const char *DOWNLOAD_FILE = "streamline-sdk-v2.14.16.zip";
inline constexpr const char *DOWNLOAD_SHA256 = "32041e51db0cab709a271b72a352281b690c2abbd669a827809401a5dd23956b";
inline constexpr int64_t DOWNLOAD_SIZE = 276016170;
inline constexpr const char *RELEASE_URL = "https://github.com/NVIDIA-RTX/Streamline/releases/tag/v2.14.16";
inline constexpr const char *LICENSE_URL = "https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/license.txt";
inline constexpr const char *THIRD_PARTY_URL = "https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/3rd-party-licenses.md";

// Signed x64 release files only. Never use bin/x64/development or debug DLLs.
inline constexpr const char *ZIP_DIR = "bin/x64/";
inline constexpr const char *RUNTIME_FILES[] = {
	"sl.interposer.dll",
	"sl.common.dll",
	"sl.dlss.dll",
	"sl.dlss_d.dll",
	"sl.dlss_g.dll",
	"sl.reflex.dll",
	"sl.pcl.dll",
	"sl.nis.dll",
	"sl.deepdvc.dll",
	"sl.directsr.dll",
	"sl.nvperf.dll",
	"nvngx_dlss.dll",
	"nvngx_dlssd.dll",
	"nvngx_dlssg.dll",
	"nvngx_deepdvc.dll",
	"NvLowLatencyVk.dll",
	"nvngx_dlss.license.txt",
	"reflex.license.txt",
	"nis.license.txt",
};
inline constexpr int FILE_COUNT = sizeof(RUNTIME_FILES) / sizeof(RUNTIME_FILES[0]);

} // namespace StreamlineRuntime
