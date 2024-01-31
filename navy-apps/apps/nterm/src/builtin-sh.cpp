#include <nterm.h>
#include <stdarg.h>
#include <unistd.h>
#include <SDL.h>

char handle_key(SDL_Event *ev);

static void sh_printf(const char *format, ...) {
  static char buf[256] = {};
  va_list ap;
  va_start(ap, format);
  int len = vsnprintf(buf, 256, format, ap);
  va_end(ap);
  term->write(buf, len);
}

static void sh_banner() {
  sh_printf("Built-in Shell in NTerm (NJU Terminal)\n\n");
}

static void sh_prompt() {
  sh_printf("sh> ");
}

static void sh_command_not_found(const char *cmd) {
  sh_printf("sh: command not found: %s\n", cmd);
}

static void sh_help() {
  sh_printf("Usage:\n");
  sh_printf("  q - quit\n");
  sh_printf("  h - show this help\n");
  sh_printf("  <cmd> - execute command\n");
}

static void sh_handle_cmd(const char *cmd) {
  char command[64];
  strcpy(command, cmd);
  command[strlen(command) - 1] = '\0';

  if (strcmp(command, "exit") == 0 || strcmp(command, "q") == 0) {
    exit(0);
  } else if (strcmp(command, "help") == 0) {
    sh_help();
  }
  int ret = execvp(command, NULL);
}

int setenv (const char *name, const char *value, int rewrite)
{
  return _setenv_r (_REENT, name, value, rewrite);
}

void builtin_sh_run() {
  sh_banner();
  sh_prompt();

  setenv("PATH", "/bin", 0);
  while (1) {
    SDL_Event ev;
    if (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_KEYUP || ev.type == SDL_KEYDOWN) {
        const char *res = term->keypress(handle_key(&ev));
        if (res) {
          sh_handle_cmd(res);
          sh_prompt();
        }
      }
    }
    refresh_terminal();
  }
}
