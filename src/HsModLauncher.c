#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void set_env(const char *key, const char *value) {
    if (setenv(key, value, 1) != 0) {
        fprintf(stderr, "setenv(%s) failed: %s\n", key, strerror(errno));
    }
}

int main(int argc, char **argv) {
    const char *root = "/Applications/Hearthstone";
    const char *game =
#ifdef HSMOD_REAL_GAME
        HSMOD_REAL_GAME;
#else
        "/Applications/Hearthstone/Hearthstone.app/Contents/MacOS/Hearthstone";
#endif

    FILE *log = fopen("/tmp/hsmod-launcher.log", "a");
    if (log) {
        dup2(fileno(log), STDERR_FILENO);
        dup2(fileno(log), STDOUT_FILENO);
        fprintf(stderr, "\n--- HsModLauncher start ---\n");
    }

    if (chdir(root) != 0) {
        fprintf(stderr, "chdir(%s) failed: %s\n", root, strerror(errno));
        return 1;
    }

    set_env("DOORSTOP_ENABLED", "1");
    set_env("DOORSTOP_TARGET_ASSEMBLY", "/Applications/Hearthstone/BepInEx/core/BepInEx.Preloader.dll");
    set_env("DOORSTOP_BOOT_CONFIG_OVERRIDE", "");
    set_env("DOORSTOP_IGNORE_DISABLED_ENV", "0");
    set_env("DOORSTOP_MONO_DLL_SEARCH_PATH_OVERRIDE", "/Applications/Hearthstone/BepInEx/unstripped_corlib");
    set_env("DOORSTOP_MONO_DEBUG_ENABLED", "0");
    set_env("DOORSTOP_MONO_DEBUG_ADDRESS", "127.0.0.1:10000");
    set_env("DOORSTOP_MONO_DEBUG_SUSPEND", "0");
    set_env("DOORSTOP_CLR_RUNTIME_CORECLR_PATH", ".dylib");
    set_env("DOORSTOP_CLR_CORLIB_DIR", "");
    set_env("DYLD_LIBRARY_PATH", "/Applications/Hearthstone");
    set_env("DYLD_INSERT_LIBRARIES", "/Applications/Hearthstone/libdoorstop.dylib");
    set_env("ARCHPREFERENCE", "x86_64,arm64");
    set_env("__CFBundleIdentifier", "unity.Blizzard");
    set_env("XPC_SERVICE_NAME", "application.unity.Blizzard");
    set_env("XPC_FLAGS", "1");

    char **child_argv = calloc((size_t)argc + 1, sizeof(char *));
    if (!child_argv) {
        fprintf(stderr, "calloc failed\n");
        return 1;
    }
    child_argv[0] = (char *)game;
    for (int i = 1; i < argc; i++) {
        child_argv[i] = argv[i];
    }

    fprintf(stderr, "exec %s", game);
    for (int i = 1; i < argc; i++) {
        fprintf(stderr, " %s", argv[i]);
    }
    fprintf(stderr, "\n");

    execv(game, child_argv);
    fprintf(stderr, "execv failed: %s\n", strerror(errno));
    return 1;
}
