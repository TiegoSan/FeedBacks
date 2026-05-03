#include <dlfcn.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <unistd.h>
#include <wchar.h>

typedef wchar_t *(*Py_DecodeLocaleFn)(const char *, size_t *);
typedef void (*PyMem_RawFreeFn)(void *);
typedef void (*Py_SetProgramNameFn)(const wchar_t *);
typedef void (*Py_SetPythonHomeFn)(const wchar_t *);
typedef void (*Py_InitializeFn)(void);
typedef int (*Py_IsInitializedFn)(void);
typedef void (*PySys_SetArgvExFn)(int, wchar_t **, int);
typedef int (*PyRun_SimpleFileExFlagsFn)(FILE *, const char *, int, void *);
typedef void (*Py_FinalizeFn)(void);
typedef void (*PyErr_PrintFn)(void);
typedef int (*PyErr_OccurredFn)(void);

typedef struct {
    Py_DecodeLocaleFn decode_locale;
    PyMem_RawFreeFn raw_free;
    Py_SetProgramNameFn set_program_name;
    Py_SetPythonHomeFn set_python_home;
    Py_InitializeFn initialize;
    Py_IsInitializedFn is_initialized;
    PySys_SetArgvExFn set_argv;
    PyRun_SimpleFileExFlagsFn run_file;
    Py_FinalizeFn finalize;
    PyErr_PrintFn err_print;
    PyErr_OccurredFn err_occurred;
} PythonAPI;

static int resolve_executable_path(char *buffer, size_t size) {
    uint32_t raw_size = (uint32_t)size;
    if (_NSGetExecutablePath(buffer, &raw_size) != 0) {
        return -1;
    }

    char resolved[PATH_MAX];
    if (realpath(buffer, resolved) == NULL) {
        return -1;
    }

    strncpy(buffer, resolved, size - 1);
    buffer[size - 1] = '\0';
    return 0;
}

static int parent_directory(char *path) {
    char *slash = strrchr(path, '/');
    if (slash == NULL) {
        return -1;
    }
    *slash = '\0';
    return 0;
}

static int build_python_paths(char *resource_root, size_t resource_root_size, char *python_home, size_t python_home_size, char *python_lib, size_t python_lib_size) {
    char executable_path[PATH_MAX];
    if (resolve_executable_path(executable_path, sizeof(executable_path)) != 0) {
        return -1;
    }

    if (parent_directory(executable_path) != 0) {
        return -1;
    }

    if (snprintf(resource_root, resource_root_size, "%s/../Resources", executable_path) >= (int)resource_root_size) {
        return -1;
    }

    if (snprintf(python_home, python_home_size, "%s/python-minimal", resource_root) >= (int)python_home_size) {
        return -1;
    }

    if (snprintf(python_lib, python_lib_size, "%s/lib/libpython3.10.dylib", python_home) >= (int)python_lib_size) {
        return -1;
    }

    return 0;
}

static int load_python_api(const char *python_lib_path, PythonAPI *api) {
    void *handle = dlopen(python_lib_path, RTLD_NOW | RTLD_GLOBAL);
    if (handle == NULL) {
        fprintf(stderr, "Unable to load bundled libpython: %s\n", dlerror());
        return -1;
    }

    api->decode_locale = (Py_DecodeLocaleFn)dlsym(handle, "Py_DecodeLocale");
    api->raw_free = (PyMem_RawFreeFn)dlsym(handle, "PyMem_RawFree");
    api->set_program_name = (Py_SetProgramNameFn)dlsym(handle, "Py_SetProgramName");
    api->set_python_home = (Py_SetPythonHomeFn)dlsym(handle, "Py_SetPythonHome");
    api->initialize = (Py_InitializeFn)dlsym(handle, "Py_Initialize");
    api->is_initialized = (Py_IsInitializedFn)dlsym(handle, "Py_IsInitialized");
    api->set_argv = (PySys_SetArgvExFn)dlsym(handle, "PySys_SetArgvEx");
    api->run_file = (PyRun_SimpleFileExFlagsFn)dlsym(handle, "PyRun_SimpleFileExFlags");
    api->finalize = (Py_FinalizeFn)dlsym(handle, "Py_Finalize");
    api->err_print = (PyErr_PrintFn)dlsym(handle, "PyErr_Print");
    api->err_occurred = (PyErr_OccurredFn)dlsym(handle, "PyErr_Occurred");

    if (api->decode_locale == NULL || api->raw_free == NULL || api->set_program_name == NULL ||
        api->set_python_home == NULL || api->initialize == NULL || api->is_initialized == NULL ||
        api->set_argv == NULL || api->run_file == NULL || api->finalize == NULL ||
        api->err_print == NULL || api->err_occurred == NULL) {
        fprintf(stderr, "Bundled libpython is missing required symbols.\n");
        return -1;
    }

    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: FeedBacksPythonHelper /path/to/script.py [args...]\n");
        return 1;
    }

    char resource_root[PATH_MAX];
    char python_home[PATH_MAX];
    char python_lib[PATH_MAX];
    if (build_python_paths(resource_root, sizeof(resource_root), python_home, sizeof(python_home), python_lib, sizeof(python_lib)) != 0) {
        fprintf(stderr, "Unable to resolve bundled Python paths.\n");
        return 1;
    }

    char python_scripts[PATH_MAX];
    if (snprintf(python_scripts, sizeof(python_scripts), "%s/Python", resource_root) >= (int)sizeof(python_scripts)) {
        fprintf(stderr, "Unable to resolve embedded Python scripts directory.\n");
        return 1;
    }

    char python_path[PATH_MAX * 3];
    if (snprintf(
        python_path,
        sizeof(python_path),
        "%s:%s:%s/lib/python3.10/site-packages",
        python_scripts,
        resource_root,
        python_home
    ) >= (int)sizeof(python_path)) {
        fprintf(stderr, "Unable to resolve PYTHONPATH.\n");
        return 1;
    }

    setenv("PYTHONHOME", python_home, 1);
    setenv("PYTHONPATH", python_path, 1);
    setenv("PYTHONNOUSERSITE", "1", 1);
    setenv("PYTHONDONTWRITEBYTECODE", "1", 1);

    PythonAPI api;
    memset(&api, 0, sizeof(api));
    if (load_python_api(python_lib, &api) != 0) {
        return 1;
    }

    wchar_t *program_name = api.decode_locale(argv[0], NULL);
    wchar_t *python_home_w = api.decode_locale(python_home, NULL);
    if (program_name == NULL || python_home_w == NULL) {
        fprintf(stderr, "Unable to convert helper paths for Python runtime.\n");
        return 1;
    }

    api.set_program_name(program_name);
    api.set_python_home(python_home_w);
    api.initialize();

    if (!api.is_initialized()) {
        fprintf(stderr, "Bundled Python runtime failed to initialize.\n");
        api.raw_free(program_name);
        api.raw_free(python_home_w);
        return 1;
    }

    const int python_argc = argc - 1;
    wchar_t **python_argv = calloc((size_t)python_argc, sizeof(wchar_t *));
    if (python_argv == NULL) {
        fprintf(stderr, "Unable to allocate Python argv.\n");
        api.finalize();
        api.raw_free(program_name);
        api.raw_free(python_home_w);
        return 1;
    }

    bool argv_ok = true;
    for (int index = 0; index < python_argc; index++) {
        python_argv[index] = api.decode_locale(argv[index + 1], NULL);
        if (python_argv[index] == NULL) {
            argv_ok = false;
            break;
        }
    }

    if (!argv_ok) {
        fprintf(stderr, "Unable to convert Python script arguments.\n");
        for (int index = 0; index < python_argc; index++) {
            if (python_argv[index] != NULL) {
                api.raw_free(python_argv[index]);
            }
        }
        free(python_argv);
        api.finalize();
        api.raw_free(program_name);
        api.raw_free(python_home_w);
        return 1;
    }

    api.set_argv(python_argc, python_argv, 0);

    const char *script_path = argv[1];
    FILE *script = fopen(script_path, "r");
    if (script == NULL) {
        perror("Unable to open Python helper script");
        for (int index = 0; index < python_argc; index++) {
            api.raw_free(python_argv[index]);
        }
        free(python_argv);
        api.finalize();
        api.raw_free(program_name);
        api.raw_free(python_home_w);
        return 1;
    }

    int run_result = api.run_file(script, script_path, 1, NULL);
    if (run_result != 0 && api.err_occurred()) {
        api.err_print();
    }

    for (int index = 0; index < python_argc; index++) {
        api.raw_free(python_argv[index]);
    }
    free(python_argv);
    api.finalize();
    api.raw_free(program_name);
    api.raw_free(python_home_w);

    return run_result == 0 ? 0 : 1;
}
