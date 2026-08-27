#include "flutter_window.h"

#include <aclapi.h>
#include <optional>
#include <shellapi.h>
#include <tlhelp32.h>
#include <userenv.h>
#include <windows.h>

#include <algorithm>
#include <cwchar>
#include <cwctype>
#include <filesystem>
#include <iterator>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

#pragma comment(lib, "Advapi32.lib")
#pragma comment(lib, "Userenv.lib")

namespace {

bool HardenPrivatePath(const std::wstring& raw_path, DWORD* error_code) {
  const DWORD required =
      ::GetFullPathNameW(raw_path.c_str(), 0, nullptr, nullptr);
  if (required == 0) {
    *error_code = ::GetLastError();
    return false;
  }
  std::vector<wchar_t> full_buffer(required);
  if (::GetFullPathNameW(raw_path.c_str(), required, full_buffer.data(),
                         nullptr) == 0) {
    *error_code = ::GetLastError();
    return false;
  }
  std::wstring full_path(full_buffer.data());
  if (full_path.size() <= 3) {
    *error_code = ERROR_INVALID_PARAMETER;
    return false;
  }
  const DWORD attributes = ::GetFileAttributesW(full_path.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES ||
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
    *error_code = attributes == INVALID_FILE_ATTRIBUTES
                      ? ::GetLastError()
                      : ERROR_REPARSE_TAG_INVALID;
    return false;
  }

  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) {
    *error_code = ::GetLastError();
    return false;
  }
  DWORD token_size = 0;
  ::GetTokenInformation(token, TokenUser, nullptr, 0, &token_size);
  if (token_size == 0 || ::GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
    *error_code = ::GetLastError();
    ::CloseHandle(token);
    return false;
  }
  std::vector<BYTE> token_buffer(token_size);
  if (!::GetTokenInformation(token, TokenUser, token_buffer.data(),
                             token_size, &token_size)) {
    *error_code = ::GetLastError();
    ::CloseHandle(token);
    return false;
  }
  ::CloseHandle(token);
  const auto* token_user =
      reinterpret_cast<const TOKEN_USER*>(token_buffer.data());

  BYTE system_sid[SECURITY_MAX_SID_SIZE] = {};
  DWORD system_sid_size = sizeof(system_sid);
  BYTE administrators_sid[SECURITY_MAX_SID_SIZE] = {};
  DWORD administrators_sid_size = sizeof(administrators_sid);
  if (!::CreateWellKnownSid(WinLocalSystemSid, nullptr, system_sid,
                            &system_sid_size) ||
      !::CreateWellKnownSid(WinBuiltinAdministratorsSid, nullptr,
                            administrators_sid,
                            &administrators_sid_size)) {
    *error_code = ::GetLastError();
    return false;
  }

  const DWORD inheritance =
      (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0
          ? SUB_CONTAINERS_AND_OBJECTS_INHERIT
          : NO_INHERITANCE;
  EXPLICIT_ACCESSW entries[3] = {};
  auto configure_entry = [inheritance](EXPLICIT_ACCESSW* entry, PSID sid,
                                       TRUSTEE_TYPE trustee_type) {
    entry->grfAccessPermissions = GENERIC_ALL;
    entry->grfAccessMode = SET_ACCESS;
    entry->grfInheritance = inheritance;
    entry->Trustee.pMultipleTrustee = nullptr;
    entry->Trustee.MultipleTrusteeOperation = NO_MULTIPLE_TRUSTEE;
    entry->Trustee.TrusteeForm = TRUSTEE_IS_SID;
    entry->Trustee.TrusteeType = trustee_type;
    entry->Trustee.ptstrName = reinterpret_cast<LPWSTR>(sid);
  };
  configure_entry(&entries[0], token_user->User.Sid, TRUSTEE_IS_USER);
  configure_entry(&entries[1], system_sid, TRUSTEE_IS_WELL_KNOWN_GROUP);
  configure_entry(&entries[2], administrators_sid,
                  TRUSTEE_IS_WELL_KNOWN_GROUP);

  PACL private_acl = nullptr;
  DWORD result = ::SetEntriesInAclW(3, entries, nullptr, &private_acl);
  if (result != ERROR_SUCCESS) {
    *error_code = result;
    return false;
  }
  result = ::SetNamedSecurityInfoW(
      full_path.data(), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION, nullptr,
      nullptr, private_acl, nullptr);
  ::LocalFree(private_acl);
  if (result != ERROR_SUCCESS) {
    *error_code = result;
    return false;
  }
  *error_code = ERROR_SUCCESS;
  return true;
}

HANDLE CreateKillOnCloseJobForProcess(DWORD process_id, DWORD* error_code) {
  HANDLE job = ::CreateJobObjectW(nullptr, nullptr);
  if (job == nullptr) {
    *error_code = ::GetLastError();
    return nullptr;
  }
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!::SetInformationJobObject(job, JobObjectExtendedLimitInformation,
                                 &limits, sizeof(limits))) {
    *error_code = ::GetLastError();
    ::CloseHandle(job);
    return nullptr;
  }
  HANDLE process = ::OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE |
                                     PROCESS_QUERY_LIMITED_INFORMATION,
                                 FALSE, process_id);
  if (process == nullptr) {
    *error_code = ::GetLastError();
    ::CloseHandle(job);
    return nullptr;
  }
  const BOOL assigned = ::AssignProcessToJobObject(job, process);
  *error_code = assigned ? ERROR_SUCCESS : ::GetLastError();
  ::CloseHandle(process);
  if (!assigned) {
    ::CloseHandle(job);
    return nullptr;
  }
  return job;
}

bool EndsWithIgnoreCase(const std::wstring& value,
                        const std::wstring& suffix) {
  if (value.size() < suffix.size()) {
    return false;
  }
  return ::CompareStringOrdinal(
             value.data() + value.size() - suffix.size(),
             static_cast<int>(suffix.size()), suffix.data(),
             static_cast<int>(suffix.size()), TRUE) == CSTR_EQUAL;
}

bool ContainsIgnoreCase(const std::wstring& value,
                        const std::wstring& needle) {
  std::wstring lowered_value = value;
  std::wstring lowered_needle = needle;
  std::transform(lowered_value.begin(), lowered_value.end(),
                 lowered_value.begin(),
                 [](wchar_t character) { return std::towlower(character); });
  std::transform(lowered_needle.begin(), lowered_needle.end(),
                 lowered_needle.begin(),
                 [](wchar_t character) { return std::towlower(character); });
  return lowered_value.find(lowered_needle) != std::wstring::npos;
}

bool ResolveFullPath(const std::wstring& raw_path, std::wstring* full_path,
                     DWORD* error_code) {
  const DWORD required =
      ::GetFullPathNameW(raw_path.c_str(), 0, nullptr, nullptr);
  if (required == 0) {
    *error_code = ::GetLastError();
    return false;
  }
  std::vector<wchar_t> buffer(required);
  if (::GetFullPathNameW(raw_path.c_str(), required, buffer.data(), nullptr) ==
      0) {
    *error_code = ::GetLastError();
    return false;
  }
  *full_path = std::wstring(buffer.data());
  return true;
}

bool IsFixedManagedUrl(const std::wstring& url,
                       const std::wstring& expected_path) {
  constexpr wchar_t kPrefix[] = L"http://127.0.0.1:";
  if (url.rfind(kPrefix, 0) != 0) {
    return false;
  }
  const size_t port_start = std::size(kPrefix) - 1;
  const size_t path_start = url.find(L'/', port_start);
  if (path_start == std::wstring::npos ||
      url.substr(path_start) != expected_path) {
    return false;
  }
  const std::wstring port_text =
      url.substr(port_start, path_start - port_start);
  if (port_text.empty() ||
      !std::all_of(port_text.begin(), port_text.end(), iswdigit)) {
    return false;
  }
  unsigned long port = 0;
  for (const wchar_t digit : port_text) {
    port = port * 10 + static_cast<unsigned long>(digit - L'0');
    if (port > 65535) {
      return false;
    }
  }
  return port > 0;
}

bool IsFixedAppServerWebSocketUrl(const std::wstring& url) {
  constexpr wchar_t kPrefix[] = L"ws://127.0.0.1:";
  if (url.rfind(kPrefix, 0) != 0) {
    return false;
  }
  const size_t port_start = std::size(kPrefix) - 1;
  const size_t path_start = url.find(L'/', port_start);
  const size_t port_end =
      path_start == std::wstring::npos ? url.size() : path_start;
  if (path_start != std::wstring::npos && url.substr(path_start) != L"/") {
    return false;
  }
  const std::wstring port_text =
      url.substr(port_start, port_end - port_start);
  if (port_text.empty() ||
      !std::all_of(port_text.begin(), port_text.end(), iswdigit)) {
    return false;
  }
  unsigned long port = 0;
  for (const wchar_t digit : port_text) {
    port = port * 10 + static_cast<unsigned long>(digit - L'0');
    if (port > 65535) {
      return false;
    }
  }
  return port > 0;
}

HANDLE OpenInteractiveShellToken(DWORD* error_code) {
  const DWORD active_session = ::WTSGetActiveConsoleSessionId();
  if (active_session == 0xFFFFFFFF) {
    *error_code = ERROR_NO_SUCH_LOGON_SESSION;
    return nullptr;
  }
  HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    *error_code = ::GetLastError();
    return nullptr;
  }
  PROCESSENTRY32W entry = {};
  entry.dwSize = sizeof(entry);
  HANDLE token = nullptr;
  if (::Process32FirstW(snapshot, &entry)) {
    do {
      if (_wcsicmp(entry.szExeFile, L"explorer.exe") != 0) {
        continue;
      }
      DWORD session = 0;
      if (!::ProcessIdToSessionId(entry.th32ProcessID, &session) ||
          session != active_session) {
        continue;
      }
      HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                     entry.th32ProcessID);
      if (process == nullptr) {
        *error_code = ::GetLastError();
        continue;
      }
      const BOOL opened = ::OpenProcessToken(
          process, TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_ASSIGN_PRIMARY,
          &token);
      *error_code = opened ? ERROR_SUCCESS : ::GetLastError();
      ::CloseHandle(process);
      if (opened) {
        break;
      }
    } while (::Process32NextW(snapshot, &entry));
  }
  ::CloseHandle(snapshot);
  if (token == nullptr && *error_code == ERROR_SUCCESS) {
    *error_code = ERROR_NO_SUCH_LOGON_SESSION;
  }
  return token;
}

bool EnvironmentEntryHasKey(const std::wstring& entry,
                            const std::wstring& key) {
  return entry.size() > key.size() && entry[key.size()] == L'=' &&
         ::CompareStringOrdinal(entry.data(), static_cast<int>(key.size()),
                                key.data(), static_cast<int>(key.size()),
                                TRUE) == CSTR_EQUAL;
}

bool LaunchManagedCodex(const std::wstring& raw_executable,
                        const std::wstring& raw_working_directory,
                        const std::wstring& chatgpt_base_url,
                        const std::wstring& openai_base_url,
                        const std::wstring& app_server_websocket_url,
                        DWORD* process_id, DWORD* error_code) {
  std::wstring executable;
  std::wstring working_directory;
  if (!ResolveFullPath(raw_executable, &executable, error_code) ||
      !ResolveFullPath(raw_working_directory, &working_directory,
                       error_code)) {
    return false;
  }
  const DWORD attributes = ::GetFileAttributesW(executable.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES ||
      (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0 ||
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
      !EndsWithIgnoreCase(executable, L"\\app\\ChatGPT.exe") ||
      !ContainsIgnoreCase(executable, L"\\WindowsApps\\OpenAI.Codex_") ||
      ::CompareStringOrdinal(
          std::filesystem::path(executable).parent_path().c_str(), -1,
          working_directory.c_str(), -1, TRUE) != CSTR_EQUAL) {
    *error_code = ERROR_INVALID_PARAMETER;
    return false;
  }
  const bool has_chatgpt_route = !chatgpt_base_url.empty();
  const bool has_openai_route = !openai_base_url.empty();
  const bool has_websocket = !app_server_websocket_url.empty();
  if (has_chatgpt_route != has_openai_route ||
      (has_chatgpt_route &&
       (!IsFixedManagedUrl(chatgpt_base_url,
                           L"/backend-api/codex-managed") ||
        !IsFixedManagedUrl(openai_base_url,
                           L"/backend-api/codex-managed/v1"))) ||
      (has_websocket &&
       !IsFixedAppServerWebSocketUrl(app_server_websocket_url)) ||
      (!has_chatgpt_route && !has_websocket)) {
    *error_code = ERROR_INVALID_PARAMETER;
    return false;
  }

  HANDLE user_token = OpenInteractiveShellToken(error_code);
  if (user_token == nullptr) {
    return false;
  }
  LPVOID base_environment = nullptr;
  if (!::CreateEnvironmentBlock(&base_environment, user_token, FALSE)) {
    *error_code = ::GetLastError();
    ::CloseHandle(user_token);
    return false;
  }

  constexpr wchar_t kChatGptKey[] =
      L"CODEX_APP_SERVER_CHATGPT_BASE_URL";
  constexpr wchar_t kOpenAiKey[] = L"CODEX_APP_SERVER_OPENAI_BASE_URL";
  constexpr wchar_t kWebSocketKey[] = L"CODEX_APP_SERVER_WS_URL";
  std::vector<std::wstring> entries;
  const wchar_t* cursor = static_cast<const wchar_t*>(base_environment);
  while (*cursor != L'\0') {
    std::wstring entry(cursor);
    if (!EnvironmentEntryHasKey(entry, kChatGptKey) &&
        !EnvironmentEntryHasKey(entry, kOpenAiKey) &&
        !EnvironmentEntryHasKey(entry, kWebSocketKey)) {
      entries.push_back(std::move(entry));
    }
    cursor += std::wcslen(cursor) + 1;
  }
  ::DestroyEnvironmentBlock(base_environment);
  if (has_chatgpt_route) {
    entries.push_back(std::wstring(kChatGptKey) + L"=" + chatgpt_base_url);
    entries.push_back(std::wstring(kOpenAiKey) + L"=" + openai_base_url);
  }
  if (has_websocket) {
    entries.push_back(std::wstring(kWebSocketKey) + L"=" +
                      app_server_websocket_url);
  }
  std::sort(entries.begin(), entries.end(),
            [](const std::wstring& left, const std::wstring& right) {
              return ::CompareStringOrdinal(
                         left.c_str(), -1, right.c_str(), -1, TRUE) ==
                     CSTR_LESS_THAN;
            });
  size_t block_size = 1;
  for (const auto& entry : entries) {
    block_size += entry.size() + 1;
  }
  std::vector<wchar_t> environment;
  environment.reserve(block_size);
  for (const auto& entry : entries) {
    environment.insert(environment.end(), entry.begin(), entry.end());
    environment.push_back(L'\0');
  }
  environment.push_back(L'\0');

  STARTUPINFOW startup = {};
  startup.cb = sizeof(startup);
  startup.lpDesktop = const_cast<LPWSTR>(L"winsta0\\default");
  PROCESS_INFORMATION process = {};
  const BOOL created = ::CreateProcessWithTokenW(
      user_token, LOGON_WITH_PROFILE, executable.c_str(), nullptr,
      CREATE_UNICODE_ENVIRONMENT | CREATE_NEW_PROCESS_GROUP,
      environment.data(), working_directory.c_str(), &startup, &process);
  *error_code = created ? ERROR_SUCCESS : ::GetLastError();
  ::CloseHandle(user_token);
  std::fill(environment.begin(), environment.end(), L'\0');
  if (!created) {
    return false;
  }
  *process_id = process.dwProcessId;
  ::CloseHandle(process.hThread);
  ::CloseHandle(process.hProcess);
  return true;
}

const std::string* ReadStringArgument(const flutter::EncodableMap& arguments,
                                      const char* key) {
  const auto iterator =
      arguments.find(flutter::EncodableValue(std::string(key)));
  if (iterator == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&iterator->second);
}

bool IsCanonicalUuid(const std::string& value) {
  if (value.size() != 36) {
    return false;
  }
  for (size_t index = 0; index < value.size(); ++index) {
    const bool hyphen =
        index == 8 || index == 13 || index == 18 || index == 23;
    if (hyphen) {
      if (value[index] != '-') {
        return false;
      }
      continue;
    }
    const char character = value[index];
    const bool is_hex =
        (character >= '0' && character <= '9') ||
        (character >= 'a' && character <= 'f') ||
        (character >= 'A' && character <= 'F');
    if (!is_hex) {
      return false;
    }
  }
  return true;
}

bool IsSafeRuntimeSessionId(const std::string& value) {
  if (value.empty() || value.size() > 256) {
    return false;
  }
  for (size_t index = 0; index < value.size(); ++index) {
    const unsigned char character =
        static_cast<unsigned char>(value[index]);
    const bool alpha_numeric =
        (character >= '0' && character <= '9') ||
        (character >= 'a' && character <= 'z') ||
        (character >= 'A' && character <= 'Z');
    const bool punctuation = character == '.' || character == '_' ||
                             character == ':' || character == '-';
    if ((!alpha_numeric && !punctuation) ||
        (index == 0 && !alpha_numeric)) {
      return false;
    }
  }
  return true;
}

std::optional<std::wstring> ReadEnvironmentPath(const wchar_t* name) {
  const DWORD required = ::GetEnvironmentVariableW(name, nullptr, 0);
  if (required == 0) {
    return std::nullopt;
  }
  std::vector<wchar_t> buffer(required);
  if (::GetEnvironmentVariableW(name, buffer.data(), required) == 0) {
    return std::nullopt;
  }
  return std::wstring(buffer.data());
}

bool IsExecutableFile(const std::wstring& path) {
  const DWORD attributes = ::GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

std::optional<std::wstring> SearchExecutable(const wchar_t* name) {
  const DWORD required = ::SearchPathW(nullptr, name, nullptr, 0, nullptr,
                                       nullptr);
  if (required == 0) {
    return std::nullopt;
  }
  std::vector<wchar_t> buffer(required + 1);
  if (::SearchPathW(nullptr, name, nullptr,
                    static_cast<DWORD>(buffer.size()), buffer.data(),
                    nullptr) == 0) {
    return std::nullopt;
  }
  return std::wstring(buffer.data());
}

std::optional<std::wstring> ResolveRuntimeExecutable(
    const std::string& runtime) {
  std::vector<std::filesystem::path> candidates;
  const auto local_app_data = ReadEnvironmentPath(L"LOCALAPPDATA");
  const auto user_profile = ReadEnvironmentPath(L"USERPROFILE");
  if (runtime == "hermes") {
    if (local_app_data.has_value()) {
      candidates.push_back(std::filesystem::path(*local_app_data) / L"hermes" /
                           L"bin" / L"hermes.exe");
      candidates.push_back(std::filesystem::path(*local_app_data) / L"hermes" /
                           L"hermes-agent" / L"venv" / L"Scripts" /
                           L"hermes.exe");
    }
  } else if (runtime == "opencode") {
    if (user_profile.has_value()) {
      candidates.push_back(std::filesystem::path(*user_profile) / L".config" /
                           L"opencode" / L"bin" / L"opencode-cli.exe");
      candidates.push_back(std::filesystem::path(*user_profile) / L".config" /
                           L"opencode" / L"bin" / L"opencode.exe");
    }
    if (local_app_data.has_value()) {
      candidates.push_back(std::filesystem::path(*local_app_data) / L"opencode" /
                           L"bin" / L"opencode-cli.exe");
    }
  }
  for (const auto& candidate : candidates) {
    if (IsExecutableFile(candidate.wstring())) {
      return candidate.wstring();
    }
  }
  if (runtime == "hermes") {
    return SearchExecutable(L"hermes.exe");
  }
  if (runtime == "opencode") {
    auto executable = SearchExecutable(L"opencode-cli.exe");
    return executable.has_value() ? executable
                                  : SearchExecutable(L"opencode.exe");
  }
  return std::nullopt;
}

std::wstring QuoteWindowsArgument(const std::wstring& value) {
  if (!value.empty() &&
      value.find_first_of(L" \t\n\v\"") == std::wstring::npos) {
    return value;
  }
  std::wstring quoted = L"\"";
  size_t backslashes = 0;
  for (const wchar_t character : value) {
    if (character == L'\\') {
      ++backslashes;
      continue;
    }
    if (character == L'\"') {
      quoted.append(backslashes * 2 + 1, L'\\');
      quoted.push_back(L'\"');
      backslashes = 0;
      continue;
    }
    quoted.append(backslashes, L'\\');
    backslashes = 0;
    quoted.push_back(character);
  }
  quoted.append(backslashes * 2, L'\\');
  quoted.push_back(L'\"');
  return quoted;
}

bool ResolveRuntimeWorkingDirectory(
    const std::string* raw_working_directory,
    const std::wstring& executable,
    std::wstring* working_directory,
    DWORD* error_code) {
  if (raw_working_directory != nullptr &&
      !raw_working_directory->empty()) {
    if (!ResolveFullPath(Utf16FromUtf8(*raw_working_directory),
                         working_directory, error_code)) {
      return false;
    }
    const DWORD attributes =
        ::GetFileAttributesW(working_directory->c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES ||
        (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
      *error_code = attributes == INVALID_FILE_ATTRIBUTES
                        ? ::GetLastError()
                        : ERROR_DIRECTORY;
      return false;
    }
    return true;
  }
  const auto user_profile = ReadEnvironmentPath(L"USERPROFILE");
  if (user_profile.has_value()) {
    const DWORD attributes = ::GetFileAttributesW(user_profile->c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
      *working_directory = *user_profile;
      return true;
    }
  }
  *working_directory =
      std::filesystem::path(executable).parent_path().wstring();
  return true;
}

bool LaunchRuntimeSession(const std::string& runtime,
                          const std::string& session_id,
                          const std::string* raw_working_directory,
                          DWORD* process_id,
                          DWORD* error_code) {
  const auto executable = ResolveRuntimeExecutable(runtime);
  if (!executable.has_value()) {
    *error_code = ERROR_FILE_NOT_FOUND;
    return false;
  }
  std::wstring working_directory;
  if (!ResolveRuntimeWorkingDirectory(raw_working_directory, *executable,
                                      &working_directory, error_code)) {
    return false;
  }
  const std::wstring native_session_id = Utf16FromUtf8(session_id);
  std::vector<std::wstring> arguments;
  if (runtime == "hermes") {
    arguments = {L"--resume", native_session_id, L"--in",
                 working_directory, L"--tui"};
  } else if (runtime == "opencode") {
    if (raw_working_directory != nullptr &&
        !raw_working_directory->empty()) {
      arguments.push_back(working_directory);
    }
    arguments.push_back(L"--session");
    arguments.push_back(native_session_id);
  } else {
    *error_code = ERROR_INVALID_PARAMETER;
    return false;
  }
  std::wstring command_line = QuoteWindowsArgument(*executable);
  for (const auto& argument : arguments) {
    command_line.push_back(L' ');
    command_line += QuoteWindowsArgument(argument);
  }
  std::vector<wchar_t> mutable_command(command_line.begin(),
                                       command_line.end());
  mutable_command.push_back(L'\0');
  STARTUPINFOW startup = {};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process = {};
  const BOOL created = ::CreateProcessW(
      executable->c_str(), mutable_command.data(), nullptr, nullptr, FALSE,
      CREATE_NEW_CONSOLE | CREATE_NEW_PROCESS_GROUP, nullptr,
      working_directory.c_str(), &startup, &process);
  *error_code = created ? ERROR_SUCCESS : ::GetLastError();
  std::fill(mutable_command.begin(), mutable_command.end(), L'\0');
  if (!created) {
    return false;
  }
  *process_id = process.dwProcessId;
  ::CloseHandle(process.hThread);
  ::CloseHandle(process.hProcess);
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  platform_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "openhub/native",
          &flutter::StandardMethodCodec::GetInstance());
  platform_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "allowWindowClose") {
          close_allowed_ = true;
          close_requested_ = false;
          const HWND window = GetHandle();
          if (window != nullptr) {
            ::PostMessageW(window, WM_CLOSE, 0, 0);
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "bindOwnedProcess") {
          const auto* value = std::get_if<int32_t>(call.arguments());
          if (value == nullptr || *value <= 0) {
            result->Error("invalid_process", "Expected a positive process ID.");
            return;
          }
          DWORD error_code = ERROR_SUCCESS;
          HANDLE job = CreateKillOnCloseJobForProcess(
              static_cast<DWORD>(*value), &error_code);
          if (job == nullptr) {
            result->Error("job_assignment_failed",
                          "Windows could not bind the owned sidecar to the app lifetime.",
                          flutter::EncodableValue(
                              static_cast<int32_t>(error_code)));
            return;
          }
          if (owned_process_job_ != nullptr) {
            ::CloseHandle(owned_process_job_);
          }
          owned_process_job_ = job;
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "hardenPrivatePath") {
          const auto* value = std::get_if<std::string>(call.arguments());
          if (value == nullptr || value->empty() || value->size() > 32768) {
            result->Error("invalid_path",
                          "Expected a bounded absolute path string.");
            return;
          }
          DWORD error_code = ERROR_SUCCESS;
          if (!HardenPrivatePath(Utf16FromUtf8(*value), &error_code)) {
            result->Error("acl_failed",
                          "Windows could not apply the private ACL.",
                          flutter::EncodableValue(
                              static_cast<int32_t>(error_code)));
            return;
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "launchManagedCodex") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid_launch",
                          "Expected managed Codex launch arguments.");
            return;
          }
          const std::string* executable =
              ReadStringArgument(*arguments, "executablePath");
          const std::string* working_directory =
              ReadStringArgument(*arguments, "workingDirectory");
          const std::string* chatgpt_base_url =
              ReadStringArgument(*arguments, "chatGptBaseUrl");
          const std::string* openai_base_url =
              ReadStringArgument(*arguments, "openAiBaseUrl");
          const std::string* app_server_websocket_url =
              ReadStringArgument(*arguments, "appServerWebSocketUrl");
          if (executable == nullptr || working_directory == nullptr) {
            result->Error("invalid_launch",
                          "Managed Codex launch arguments are incomplete.");
            return;
          }
          DWORD process_id = 0;
          DWORD error_code = ERROR_SUCCESS;
          if (!LaunchManagedCodex(
                  Utf16FromUtf8(*executable),
                  Utf16FromUtf8(*working_directory),
                  chatgpt_base_url == nullptr ? L"" :
                      Utf16FromUtf8(*chatgpt_base_url),
                  openai_base_url == nullptr ? L"" :
                      Utf16FromUtf8(*openai_base_url),
                  app_server_websocket_url == nullptr ? L"" :
                      Utf16FromUtf8(*app_server_websocket_url), &process_id,
                  &error_code)) {
            result->Error(
                "managed_launch_failed",
                "Windows could not launch Codex with the process-scoped route.",
                flutter::EncodableValue(static_cast<int32_t>(error_code)));
            return;
          }
          result->Success(
              flutter::EncodableValue(static_cast<int32_t>(process_id)));
          return;
        }
        if (call.method_name() == "openCodexThread") {
          const auto* value = std::get_if<std::string>(call.arguments());
          if (value == nullptr || !IsCanonicalUuid(*value)) {
            result->Error("invalid_thread",
                          "Expected a canonical Codex thread UUID.");
            return;
          }
          const std::wstring url =
              L"codex://threads/" + Utf16FromUtf8(*value);
          const auto opened = reinterpret_cast<intptr_t>(
              ::ShellExecuteW(nullptr, L"open", url.c_str(), nullptr, nullptr,
                              SW_SHOWNORMAL));
          if (opened <= 32) {
            result->Error("open_failed",
                          "Windows could not open the Codex task.");
            return;
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "openRuntimeSession") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid_session",
                          "Expected runtime session launch arguments.");
            return;
          }
          const std::string* runtime =
              ReadStringArgument(*arguments, "runtime");
          const std::string* session_id =
              ReadStringArgument(*arguments, "sessionId");
          const std::string* working_directory =
              ReadStringArgument(*arguments, "workingDirectory");
          if (runtime == nullptr || session_id == nullptr ||
              (*runtime != "hermes" && *runtime != "opencode") ||
              !IsSafeRuntimeSessionId(*session_id)) {
            result->Error("invalid_session",
                          "Expected a supported runtime and bounded session ID.");
            return;
          }
          DWORD process_id = 0;
          DWORD error_code = ERROR_SUCCESS;
          if (!LaunchRuntimeSession(*runtime, *session_id,
                                    working_directory, &process_id,
                                    &error_code)) {
            result->Error(
                "open_failed",
                "Windows could not launch the selected runtime session.",
                flutter::EncodableValue(static_cast<int32_t>(error_code)));
            return;
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() != "openExternalUrl") {
          result->NotImplemented();
          return;
        }
        const auto* value = std::get_if<std::string>(call.arguments());
        if (value == nullptr || value->size() > 8192) {
          result->Error("invalid_url", "Expected a bounded URL string.");
          return;
        }
        std::wstring url = Utf16FromUtf8(*value);
        std::wstring lowered = url;
        std::transform(lowered.begin(), lowered.end(), lowered.begin(),
                       [](wchar_t character) { return std::towlower(character); });
        if (url.empty() ||
            (lowered.rfind(L"https://", 0) != 0 &&
             lowered.rfind(L"http://", 0) != 0)) {
          result->Error("invalid_url", "Only HTTP(S) URLs may be opened.");
          return;
        }
        const auto opened = reinterpret_cast<intptr_t>(
            ::ShellExecuteW(nullptr, L"open", url.c_str(), nullptr, nullptr,
                            SW_SHOWNORMAL));
        if (opened <= 32) {
          result->Error("open_failed", "Windows could not open the URL.");
          return;
        }
        result->Success(flutter::EncodableValue(true));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (owned_process_job_ != nullptr) {
    ::CloseHandle(owned_process_job_);
    owned_process_job_ = nullptr;
  }
  if (flutter_controller_) {
    platform_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE && !close_allowed_ && platform_channel_) {
    if (!close_requested_) {
      close_requested_ = true;
      platform_channel_->InvokeMethod("requestClose", nullptr);
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
