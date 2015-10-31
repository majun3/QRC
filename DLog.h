#ifdef DEBUG
    #define DLog(fmt, ...) NSLog((@"QRC: ================= %s[%d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
    #define DLog(...)
#endif
#define ALog(fmt, ...) NSLog((@"QRC: " fmt), ##__VA_ARGS__);