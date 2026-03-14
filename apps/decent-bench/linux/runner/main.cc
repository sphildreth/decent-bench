#include <cstring>
#include <iostream>
#include <vector>

#include <unistd.h>

#include "my_application.h"

namespace {

constexpr const char *kHelpText =
    "Decent Bench 1.0.0\n"
    "\n"
    "Usage:\n"
    "  dbench\n"
    "  dbench /path/to/workspace.ddb\n"
    "  dbench --import <path>\n"
    "  dbench --in <source-path> --out <target.ddb> [--plan <plan.json>] "
    "[--silent]\n"
    "\n"
    "Options:\n"
    "  -h, --help\n"
    "      Show this help text and exit.\n"
    "  -v, --version\n"
    "      Show the application version and exit.\n"
    "  --import <path>\n"
    "      Launch the interactive import wizard for <path>.\n"
    "  --import=<path>\n"
    "      Same as above, using the inline form.\n"
    "  --in <path>\n"
    "      Run a headless import from <path>. Requires --out.\n"
    "  --in=<path>\n"
    "      Same as above, using the inline form.\n"
    "  --out <path.ddb>\n"
    "      Write the headless import result to <path.ddb>. Requires --in.\n"
    "  --out=<path.ddb>\n"
    "      Same as above, using the inline form.\n"
    "  --plan <path.json>\n"
    "      Reserved for future headless import plan support. Parsed now, but "
    "rejected at execution time.\n"
    "  --plan=<path.json>\n"
    "      Same as above, using the inline form.\n"
    "  --silent\n"
    "      Suppress headless progress output. Only valid with --in and --out.\n"
    "\n"
    "Examples:\n"
    "  dbench\n"
    "  dbench /path/to/workspace.ddb\n"
    "  dbench --import /path/to/source.sqlite\n"
    "  dbench --import=/path/to/report.xlsx\n"
    "  dbench --in /path/to/source.xlsx --out /tmp/import.ddb\n"
    "  dbench --in /path/to/source.sqlite --out /tmp/import.ddb --plan "
    "/tmp/import-plan.json\n"
    "\n"
    "Notes:\n"
    "  Passing a .ddb path opens that database in the desktop UI.\n"
    "  --import always opens the interactive import wizard.\n"
    "  --in/--out are reserved for headless import.\n"
    "  Headless import writes progress to stderr and a final JSON summary to "
    "stdout.\n"
    "  --plan is reserved for future plan-file execution and is not "
    "implemented yet.\n";

bool HasArg(int argc, char **argv, const char *short_name,
            const char *long_name) {
  for (int i = 1; i < argc; ++i) {
    if (std::strcmp(argv[i], short_name) == 0 ||
        std::strcmp(argv[i], long_name) == 0) {
      return true;
    }
  }
  return false;
}

bool IsOptionOrInlineValue(const char *arg, const char *long_name) {
  const auto option_length = std::strlen(long_name);
  return std::strcmp(arg, long_name) == 0 ||
         (std::strncmp(arg, long_name, option_length) == 0 &&
          arg[option_length] == '=');
}

bool HasHeadlessArg(int argc, char **argv) {
  for (int i = 1; i < argc; ++i) {
    if (IsOptionOrInlineValue(argv[i], "--in") ||
        IsOptionOrInlineValue(argv[i], "--out") ||
        IsOptionOrInlineValue(argv[i], "--plan") ||
        std::strcmp(argv[i], "--silent") == 0) {
      return true;
    }
  }
  return false;
}

int RunHeadlessHelper(int argc, char **argv) {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar *executable_path =
      g_file_read_link("/proc/self/exe", &error);
  if (executable_path == nullptr) {
    std::cerr << "Failed to resolve the running executable path";
    if (error != nullptr && error->message != nullptr) {
      std::cerr << ": " << error->message;
    }
    std::cerr << std::endl;
    return 1;
  }

  g_autofree gchar *bundle_dir = g_path_get_dirname(executable_path);
  g_autofree gchar *helper_path =
      g_build_filename(bundle_dir, "bin", "dbench_headless", nullptr);

  std::vector<char *> helper_argv;
  helper_argv.reserve(static_cast<size_t>(argc) + 1);
  helper_argv.push_back(helper_path);
  for (int i = 1; i < argc; ++i) {
    helper_argv.push_back(argv[i]);
  }
  helper_argv.push_back(nullptr);

  execv(helper_path, helper_argv.data());

  std::cerr << "Failed to launch bundled headless import helper at "
            << helper_path << std::endl;
  return 1;
}

} // namespace

int main(int argc, char **argv) {
  if (HasArg(argc, argv, "-h", "--help")) {
    std::cout << kHelpText;
    return 0;
  }
  if (HasArg(argc, argv, "-v", "--version")) {
    std::cout << "Decent Bench 1.0.0" << std::endl;
    return 0;
  }
  if (HasHeadlessArg(argc, argv)) {
    return RunHeadlessHelper(argc, argv);
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
