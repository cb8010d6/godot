// Local diagnostic launcher. Debugs only its own child and contains its descendants.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

static std::string utf8(const std::wstring &value) {
    if (value.empty()) return {};
    int bytes = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    std::string result(static_cast<size_t>(bytes), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), bytes, nullptr, nullptr);
    return result;
}

static std::wstring quote(const std::wstring &value) {
    std::wstring result = L"\"";
    size_t slashes = 0;
    for (wchar_t c : value) {
        if (c == L'\\') { ++slashes; continue; }
        result.append(slashes * (c == L'"' ? 2 : 1), L'\\');
        slashes = 0;
        if (c == L'"') result += L'\\';
        result += c;
    }
    result.append(slashes * 2, L'\\');
    return result + L'"';
}

static std::string file_path(HANDLE file) {
    std::vector<wchar_t> buffer(32768);
    DWORD size = GetFinalPathNameByHandleW(file, buffer.data(), static_cast<DWORD>(buffer.size()), FILE_NAME_NORMALIZED);
    return size && size < buffer.size() ? utf8(std::wstring(buffer.data(), size)) : "<unresolved>";
}

int wmain(int argc, wchar_t **argv) {
    if (argc < 3) { std::cerr << "Usage: debug_capture <debug-log> <native-exe> [args...]\n"; return 2; }
    std::ofstream log{std::filesystem::path(argv[1])};
    if (!log) return 3;
    HANDLE job = CreateJobObjectW(nullptr, nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!job || !SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) return 4;
    std::wstring command;
    for (int i = 2; i < argc; ++i) { if (i != 2) command += L' '; command += quote(argv[i]); }
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    PROCESS_INFORMATION process{};
    DWORD flags = DEBUG_ONLY_THIS_PROCESS | CREATE_SUSPENDED | CREATE_NO_WINDOW;
    if (!CreateProcessW(argv[2], command.data(), nullptr, nullptr, TRUE, flags, nullptr, nullptr, &startup, &process)) {
        log << "CreateProcess error=" << GetLastError() << '\n'; CloseHandle(job); return 5;
    }
    if (!AssignProcessToJobObject(job, process.hProcess)) {
        log << "AssignJob error=" << GetLastError() << '\n';
        TerminateProcess(process.hProcess, 126); CloseHandle(process.hThread); CloseHandle(process.hProcess); CloseHandle(job); return 6;
    }
    log << "CHILD pid=" << process.dwProcessId << " exe=" << utf8(argv[2]) << '\n';
    ResumeThread(process.hThread);
    ULONGLONG start = GetTickCount64();
    DWORD exit_code = 124;
    bool done = false;
    while (!done) {
        DEBUG_EVENT event{};
        if (!WaitForDebugEventEx(&event, 100)) {
            if (GetTickCount64() - start > 180000) { TerminateJobObject(job, 124); log << "TIMEOUT\n"; }
            continue;
        }
        DWORD disposition = DBG_CONTINUE;
        switch (event.dwDebugEventCode) {
            case CREATE_PROCESS_DEBUG_EVENT:
                if (event.u.CreateProcessInfo.hFile) CloseHandle(event.u.CreateProcessInfo.hFile);
                break;
            case LOAD_DLL_DEBUG_EVENT:
                if (event.u.LoadDll.hFile) {
                    log << "MODULE base=" << event.u.LoadDll.lpBaseOfDll << " file=" << file_path(event.u.LoadDll.hFile) << '\n';
                    CloseHandle(event.u.LoadDll.hFile);
                }
                break;
            case OUTPUT_DEBUG_STRING_EVENT: {
                auto &data = event.u.DebugString;
                size_t count = std::min<size_t>(data.nDebugStringLength, 32767);
                SIZE_T read = 0;
                if (data.fUnicode) {
                    std::vector<wchar_t> buffer(count + 1);
                    if (ReadProcessMemory(process.hProcess, data.lpDebugStringData, buffer.data(), count * sizeof(wchar_t), &read))
                        log << "ODS " << utf8(std::wstring(buffer.data(), wcsnlen_s(buffer.data(), count))) << '\n';
                } else {
                    std::vector<char> buffer(count + 1);
                    if (ReadProcessMemory(process.hProcess, data.lpDebugStringData, buffer.data(), count, &read))
                        log << "ODS " << buffer.data() << '\n';
                }
                break;
            }
            case EXCEPTION_DEBUG_EVENT:
                log << "EXCEPTION code=0x" << std::hex << event.u.Exception.ExceptionRecord.ExceptionCode
                    << " first=" << event.u.Exception.dwFirstChance << std::dec << '\n';
                if (event.u.Exception.ExceptionRecord.ExceptionCode != EXCEPTION_BREAKPOINT)
                    disposition = DBG_EXCEPTION_NOT_HANDLED;
                break;
            case EXIT_PROCESS_DEBUG_EVENT:
                exit_code = event.u.ExitProcess.dwExitCode;
                log << "EXIT code=" << exit_code << '\n'; done = true; break;
            default: break;
        }
        log.flush();
        ContinueDebugEvent(event.dwProcessId, event.dwThreadId, disposition);
    }
    CloseHandle(process.hThread); CloseHandle(process.hProcess); CloseHandle(job);
    return static_cast<int>(exit_code);
}
