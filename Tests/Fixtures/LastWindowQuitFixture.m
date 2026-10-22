#import <AppKit/AppKit.h>
#import <signal.h>

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

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    WriteFixtureState(@"closed");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
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
