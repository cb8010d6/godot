// Diagnostic-only; never part of the proposed runtime correction.
#pragma once
#include "core/os/os.h"
#include "core/string/print_string.h"

inline String acceptance_d3d12_module(const void *p_address) {
	HMODULE module = nullptr;
	if (!p_address || !GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
			reinterpret_cast<LPCWSTR>(p_address), &module)) {
		return "<not resolved>";
	}
	wchar_t path[32768]{};
	DWORD size = GetModuleFileNameW(module, path, 32768);
	return size ? String::utf16(reinterpret_cast<const char16_t *>(path), size) : String("<no path>");
}

inline void acceptance_d3d12_pointer(const char *p_name, const void *p_address) {
	print_line(vformat("[ACCEPTANCE-D3D12] %s address=%s owner=%s", p_name,
			String::num_uint64(reinterpret_cast<uintptr_t>(p_address), 16), acceptance_d3d12_module(p_address)));
}

inline void acceptance_d3d12_modules() {
	for (const wchar_t *name : {L"d3d12.dll", L"D3D12Core.dll", L"d3d12SDKLayers.dll", L"sl.interposer.dll"}) {
		HMODULE module = GetModuleHandleW(name);
		print_line(vformat("[ACCEPTANCE-D3D12] module=%s path=%s", String::utf16(reinterpret_cast<const char16_t *>(name)),
				module ? acceptance_d3d12_module(module) : String("<not loaded>")));
	}
}
