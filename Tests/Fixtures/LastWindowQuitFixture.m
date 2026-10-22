#import <AppKit/AppKit.h>
#import <signal.h>
#import <spawn.h>

extern char **environ;

@interface LastWindowQuitFixtureDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) dispatch_source_t closeSource;
@property(nonatomic, strong) dispatch_source_t minimizeSource;
@end

@implementation LastWindowQuitFixtureDelegate

static void WriteFixtureState(NSString *state) {
    const char *path = getenv("QUITX_FIXTURE_STATE_FILE");
    if (path == NULL) { return; }
    NSString *filePath = [NSString stringWithUTF8String:path];
    [state writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [[NSProcessInfo processInfo] disableAutomaticTermination:@"QuitX fixture"];
    [[NSProcessInfo processInfo] disableSuddenTermination];

    NSRect frame = NSMakeRect(200, 200, 480, 280);
    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable |
                             NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"QuitX Last Window Integration Fixture";
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    WriteFixtureState(@"open");

    const char *spawnBackend = getenv("QUITX_FIXTURE_SPAWN_BACKEND");
    NSString *backend = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"QuitXFixtureBackend"];
    if (spawnBackend != NULL && strcmp(spawnBackend, "1") == 0 && backend != nil) {
        pid_t child = 0;
        char *argv[] = { (char *)backend.fileSystemRepresentation, NULL };
        posix_spawn(&child, backend.fileSystemRepresentation, NULL, NULL, argv, environ);
    }

    signal(SIGUSR1, SIG_IGN);
    self.closeSource = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_SIGNAL,
        SIGUSR1,
        0,
        dispatch_get_main_queue()
    );
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.closeSource, ^{
        [weakSelf.window performClose:nil];
    });
    dispatch_resume(self.closeSource);

    signal(SIGUSR2, SIG_IGN);
    self.minimizeSource = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_SIGNAL,
        SIGUSR2,
        0,
        dispatch_get_main_queue()
    );
    dispatch_source_set_event_handler(self.minimizeSource, ^{
        NSWindow *window = weakSelf.window;
        if (window.isMiniaturized) {
            [window deminiaturize:nil];
            [window makeKeyAndOrderFront:nil];
        } else {
            [window miniaturize:nil];
        }
    });
    dispatch_resume(self.minimizeSource);
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
    (void)notification;
    WriteFixtureState(@"minimized");
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    (void)notification;
    WriteFixtureState(@"open");
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    const char *hide = getenv("QUITX_FIXTURE_HIDE_ON_CLOSE");
    if (hide != NULL && strcmp(hide, "1") == 0) {
        [sender orderOut:nil];
        WriteFixtureState(@"closed");
        return NO;
    }
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    WriteFixtureState(@"closed");
    const char *accessory = getenv("QUITX_FIXTURE_ACCESSORY_ON_CLOSE");
    if (accessory != NULL && strcmp(accessory, "1") == 0) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    const char *allowed = getenv("QUITX_FIXTURE_QUIT_SENDER");
    if (allowed != NULL) {
        NSAppleEventDescriptor *event = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
        pid_t senderPid = (pid_t)[[event attributeDescriptorForKeyword:keySenderPIDAttr] int32Value];
        if (event != nil && senderPid != 0 && senderPid != (pid_t)atoi(allowed)) {
            return NSTerminateCancel;
        }
    }
    static int quitRequests = 0;
    quitRequests += 1;
    const char *background = getenv("QUITX_FIXTURE_BACKGROUND_ON_FIRST_QUIT");
    if (background != NULL && strcmp(background, "1") == 0 && quitRequests == 1) {
        [self.window orderOut:nil];
        WriteFixtureState(@"background");
        return NSTerminateCancel;
    }
    const char *refuse = getenv("QUITX_FIXTURE_REFUSE_QUIT");
    if (refuse != NULL && strcmp(refuse, "1") == 0) {
        return NSTerminateCancel;
    }
    return NSTerminateNow;
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        LastWindowQuitFixtureDelegate *delegate = [[LastWindowQuitFixtureDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
