#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/time.h>

static int evtdev = -1;
static int fbdev = -1;
static int screen_w = 0, screen_h = 0;
static int canvas_x = 0, canvas_y = 0;

uint32_t NDL_GetTicks() {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

int NDL_PollEvent(char *buf, int len) {
  int ret = read(evtdev, buf, len);
  return ret;
}

void NDL_OpenCanvas(int *w, int *h) {
  if (getenv("NWM_APP")) {
    int fbctl = 4;
    fbdev = 5;
    screen_w = *w; screen_h = *h;
    char buf[64];
    int len = sprintf(buf, "%d %d", screen_w, screen_h);
    // let NWM resize the window and create the frame buffer
    write(fbctl, buf, len);
    while (1) {
      // 3 = evtdev
      int nread = read(3, buf, sizeof(buf) - 1);
      if (nread <= 0) continue;
      buf[nread] = '\0';
      if (strcmp(buf, "mmap ok") == 0) break;
    }
    close(fbctl);
  }
  if (*w == 0 || *w > screen_w) 
  {
    *w = screen_w;
  }
  if (*h == 0 || *h > screen_h) 
  {
    *h = screen_h;
  }
  if (*w < screen_w && *h < screen_h) {
    canvas_x = (screen_w - *w) / 2;
    canvas_y = (screen_h - *h) / 2;
  }
}

void NDL_DrawRect(uint32_t *pixels, int x, int y, int w, int h) {
  for (int i = 0; i < h; i++) {
    lseek(fbdev, ((y + i + canvas_y) * screen_w + x + canvas_x), SEEK_SET);
    write(fbdev, pixels + i * w, w);
  }
}

void NDL_OpenAudio(int freq, int channels, int samples) {
}

void NDL_CloseAudio() {
}

int NDL_PlayAudio(void *buf, int len) {
  return 0;
}

int NDL_QueryAudio() {
  return 0;
}

int NDL_Init(uint32_t flags) {
  if (getenv("NWM_APP")) {
    evtdev = 3;
  }
  evtdev = open("/dev/events", 0, 'r');
  fbdev = open("/dev/fb", 0, 'w');
  size_t dispinfo_buf[128];
  int dispinfo = open("/proc/dispinfo", 0, 'r');
  read(dispinfo, dispinfo_buf, sizeof(dispinfo_buf));
  sscanf((char *)dispinfo_buf, "WIDTH: %d\nHEIGHT: %d", &screen_w, &screen_h);
  close(dispinfo);

  return 0;
}

void NDL_Quit() {
  close(evtdev);
  close(fbdev);
}
