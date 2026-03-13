#include <cstring>
#include <iostream>

#include "my_application.h"

namespace {

constexpr const char *kHelpText =
    "Decent Bench 0.1.0\n"
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
    "      Apply a headless import plan. Only valid with --in and --out.\n"
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
    "  Headless import execution is not implemented yet in this build.\n";

constexpr const char *kHeadlessImportUnavailableText =
    "Headless import mode is not implemented yet in this build.\n"
    "\n"
    "Planned syntax:\n"
    "  dbench --in <source-path> --out <target.ddb> [--plan <plan.json>] "
    "[--silent]\n"
    "\n"
    "Use `dbench --help` for details.\n";

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

} // namespace

int main(int argc, char **argv) {
  if (HasArg(argc, argv, "-h", "--help")) {
    std::cout << kHelpText;
    return 0;
  }
  if (HasArg(argc, argv, "-v", "--version")) {
    std::cout << "Decent Bench 0.1.0" << std::endl;
    return 0;
  }
  if (HasHeadlessArg(argc, argv)) {
    std::cerr << kHeadlessImportUnavailableText;
    return 2;
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
