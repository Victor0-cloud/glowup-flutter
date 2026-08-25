#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// One attempt at bringing |target| to the foreground even when this
// process's thread isn't the one currently owning foreground input focus
// (Windows normally blocks SetForegroundWindow in that case). Mirrors the
// AttachThreadInput + SetForegroundWindow technique already verified
// manually via PowerShell for this app.
bool BringWindowToForegroundOnce(HWND target) {
  if (IsIconic(target)) {
    ShowWindow(target, SW_RESTORE);
  }
  ShowWindow(target, SW_SHOW);

  HWND foreground = GetForegroundWindow();
  DWORD foreground_thread =
      foreground ? GetWindowThreadProcessId(foreground, nullptr) : 0;
  DWORD current_thread = GetCurrentThreadId();

  bool attached = false;
  if (foreground_thread != 0 && foreground_thread != current_thread) {
    attached = AttachThreadInput(current_thread, foreground_thread, TRUE) != 0;
  }

  BOOL result = SetForegroundWindow(target);
  ShowWindow(target, SW_SHOW);

  if (attached) {
    AttachThreadInput(current_thread, foreground_thread, FALSE);
  }

  return result != 0 && IsWindowVisible(target) && !IsIconic(target) &&
         GetForegroundWindow() == target;
}

// Used only to return focus to the app after the OS-launched OAuth browser
// hands control back post sign-in. Observed in practice: a single
// SetForegroundWindow attempt right when the browser closes sometimes loses
// a race against the OS's own focus handling (the app window ends up
// minimized, or in rarer cases genuinely hidden, even though this process
// never crashed) — retried a few times with short delays so a losing first
// attempt still self-corrects instead of requiring the window to be shown
// manually.
bool BringWindowToForeground(HWND target) {
  if (!target) {
    return false;
  }
  const int kMaxAttempts = 5;
  const DWORD kDelayMs = 150;
  bool succeeded = false;
  for (int attempt = 0; attempt < kMaxAttempts; ++attempt) {
    if (BringWindowToForegroundOnce(target)) {
      succeeded = true;
    }
    if (attempt < kMaxAttempts - 1) {
      Sleep(kDelayMs);
    }
  }
  // Always leave the window in its best-known-good visible/foreground
  // state, even if the very last attempt in the loop happened to lose a
  // late race.
  BringWindowToForegroundOnce(target);
  return succeeded;
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

  foreground_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "glow_up/window_foreground",
          &flutter::StandardMethodCodec::GetInstance());
  foreground_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name().compare("bringToFront") == 0) {
          bool success = BringWindowToForeground(GetHandle());
          result->Success(flutter::EncodableValue(success));
        } else {
          result->NotImplemented();
        }
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
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
