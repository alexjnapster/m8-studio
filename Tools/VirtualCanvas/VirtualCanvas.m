// Original M8 Studio host. Private CoreGraphics ABI declarations informed by
// Chromium's BSD-licensed display test utility; see PROVENANCE.md and LICENSE.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ColorSync/ColorSync.h>
#import <signal.h>
#import <unistd.h>

@interface CGVirtualDisplayDescriptor:NSObject
@property(nonatomic) unsigned int vendorID, productID, serialNum, serialNumber;
@property(strong,nonatomic) NSString *name;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int maxPixelsWide, maxPixelsHigh;
@property(nonatomic) CGPoint redPrimary, greenPrimary, bluePrimary, whitePoint;
@property(strong,nonatomic) id queue;
@end
@interface CGVirtualDisplayMode:NSObject
- (id)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)rate;
@end
@interface CGVirtualDisplaySettings:NSObject
@property(strong,nonatomic) NSArray *modes;
@property(nonatomic) unsigned int hiDPI, rotation;
@end
@interface CGVirtualDisplay:NSObject
@property(readonly,nonatomic) unsigned int displayID;
- (id)initWithDescriptor:(id)descriptor;
- (BOOL)applySettings:(id)settings;
@end

static NSString *displayUUID(CGDirectDisplayID display) {
    CFUUIDRef value = CGDisplayCreateUUIDFromDisplayID(display);
    if (!value) return @"";
    NSString *result = CFBridgingRelease(CFUUIDCreateString(NULL,value)); CFRelease(value); return result;
}
static BOOL available(void) {
    return NSClassFromString(@"CGVirtualDisplay") && NSClassFromString(@"CGVirtualDisplayDescriptor") &&
           NSClassFromString(@"CGVirtualDisplaySettings") && NSClassFromString(@"CGVirtualDisplayMode");
}
static BOOL validWidth(NSInteger width) { return width>=1280 && width<=3072 && width%16==0; }
static void status(NSString *state, CGDirectDisplayID virtualID, NSString *detail) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"state":state,@"virtualID":@(virtualID),@"detail":detail ?: @""} options:0 error:nil];
    fwrite(data.bytes,1,data.length,stdout); fputc('\n',stdout); fflush(stdout);
#ifdef M8_CANVAS_DIAGNOSTICS
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/M8StudioCanvasTestHelper-events.jsonl"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0600}];
    NSFileHandle *log=[NSFileHandle fileHandleForWritingAtPath:path];
    [log seekToEndOfFile]; [log writeData:data]; [log writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]]; [log closeFile];
#endif
}
// A fresh process avoids CoreGraphics' stale mode snapshot in the creator.
static int configureMirror(int argc,const char *argv[]) {
    if (argc!=12) return 2;
    char *end=NULL;
    unsigned long rawTarget=strtoul(argv[2],&end,10); if (!end||*end||rawTarget==0||rawTarget>UINT32_MAX) return 2;
    NSString *uuid=[NSString stringWithUTF8String:argv[3]];
    unsigned long rawVirtual=strtoul(argv[4],&end,10); if (!end||*end||rawVirtual==0||rawVirtual>UINT32_MAX) return 2;
    long width=strtol(argv[5],&end,10); if (!end||*end||!validWidth(width)) return 2;
    long owner=strtol(argv[6],&end,10); if (!end||*end||owner!=getppid()||owner<=1) return 2;
    long expected[5];
    for (int i=0;i<5;i++) { expected[i]=strtol(argv[7+i],&end,10); if (!end||*end||expected[i]<1||expected[i]>(i==4 ? 240000:32768)) return 2; }
    CGDirectDisplayID target=(CGDirectDisplayID)rawTarget, virtualID=(CGDirectDisplayID)rawVirtual;
    if (![displayUUID(target) isEqual:uuid] || CGDisplayIsBuiltin(target) || CGDisplayIsInMirrorSet(target) ||
        CGDisplayVendorNumber(target)!=19501 || (CGDisplayModelNumber(target)!=29287 && CGDisplayModelNumber(target)!=29289) ||
        CGDisplayVendorNumber(virtualID)!=0x4D38 || CGDisplayModelNumber(virtualID)!=1 || !CGDisplayIsOnline(virtualID)) return 3;
    CGDisplayModeRef physicalMode=CGDisplayCopyDisplayMode(target);
    BOOL unchanged=physicalMode && CGDisplayModeGetWidth(physicalMode)==expected[0] && CGDisplayModeGetHeight(physicalMode)==expected[1] &&
                   CGDisplayModeGetPixelWidth(physicalMode)==expected[2] && CGDisplayModeGetPixelHeight(physicalMode)==expected[3] &&
                   fabs(CGDisplayModeGetRefreshRate(physicalMode)*1000-expected[4])<=1 &&
                   !CGDisplayIsAsleep(target) && fabs(CGDisplayRotation(target))<0.1;
    if (physicalMode) CGDisplayModeRelease(physicalMode);
    if (!unchanged) { status(@"failed",virtualID,@"The physical display changed during setup. No mirror was applied"); return 3; }
    CGDisplayModeRef desired=NULL;
    CFArrayRef modes=CGDisplayCopyAllDisplayModes(virtualID,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGDisplayShowDuplicateLowResolutionModes:@YES});
    if (modes) {
        NSMutableArray *reported=[NSMutableArray array];
        for (CFIndex i=0;i<CFArrayGetCount(modes);i++) {
            CGDisplayModeRef m=(CGDisplayModeRef)CFArrayGetValueAtIndex(modes,i);
            if (i<64) [reported addObject:[NSString stringWithFormat:@"%zux%zu render %zux%zu",CGDisplayModeGetWidth(m),CGDisplayModeGetHeight(m),CGDisplayModeGetPixelWidth(m),CGDisplayModeGetPixelHeight(m)]];
            if (!desired && CGDisplayModeGetWidth(m)==width && CGDisplayModeGetHeight(m)==width*9/16 &&
                CGDisplayModeGetPixelWidth(m)==width*2 && CGDisplayModeGetPixelHeight(m)==width*9/8) desired=CGDisplayModeRetain(m);
        }
        status(@"modes",virtualID,[reported componentsJoinedByString:@"; "]); CFRelease(modes);
    }
    if (!desired) { status(@"failed",virtualID,@"Requested 2x HiDPI mode was not reported"); return 4; }
    CGRect bounds=CGDisplayBounds(target);
    CGDisplayConfigRef config=NULL;
    CGError result=CGBeginDisplayConfiguration(&config);
    if (result==kCGErrorSuccess) result=CGConfigureDisplayWithDisplayMode(config,virtualID,desired,NULL);
    CGDisplayModeRelease(desired);
    if (result==kCGErrorSuccess) result=CGConfigureDisplayOrigin(config,virtualID,(int32_t)bounds.origin.x,(int32_t)bounds.origin.y);
    if (result==kCGErrorSuccess) result=CGConfigureDisplayMirrorOfDisplay(config,target,virtualID);
    if (result==kCGErrorSuccess) result=CGCompleteDisplayConfiguration(config,kCGConfigureForSession);
    else if (config) CGCancelDisplayConfiguration(config);
    if (result!=kCGErrorSuccess) { status(@"failed",virtualID,@"macOS refused the mirror configuration"); return 4; }
    if (CGDisplayMirrorsDisplay(target)!=virtualID) { status(@"failed",virtualID,@"Mirror direction was not confirmed"); return 5; }
    status(@"attached",virtualID,@""); return 0;
}
static volatile sig_atomic_t stopping = 0;
static void stopSignal(int number) { stopping=1; }
int main(int argc,const char *argv[]) { @autoreleasepool {
    if (argc>1 && strcmp(argv[1],"--configure")==0) return configureMirror(argc,argv);
    if (argc==2 && strcmp(argv[1],"--check")==0) { status(available() ? @"available":@"unavailable",0,@""); return available() ? 0:1; }
    if (argc==2 && strcmp(argv[1],"--self-test")==0) {
        if (!validWidth(1280)||!validWidth(2560)||!validWidth(3072)||validWidth(0)||validWidth(3073)||validWidth(1921)) return 1;
        puts("PASS bounded logical dimensions; no virtual display created"); return 0;
    }
    if (argc!=5 || !available()) { status(@"failed",0,@"Unsupported virtual display interface"); return 2; }
    char *end=NULL; unsigned long rawID=strtoul(argv[1],&end,10);
    if (!end || *end || rawID==0 || rawID>UINT32_MAX) return 2;
    CGDirectDisplayID target=(CGDirectDisplayID)rawID;
    NSString *uuid=[NSString stringWithUTF8String:argv[2]];
    long width=strtol(argv[3],&end,10); if (!end || *end || !validWidth(width)) return 2;
    long owner=strtol(argv[4],&end,10); if (!end || *end || owner!=getppid() || owner<=1) return 2;
    uint32_t vendor=CGDisplayVendorNumber(target), product=CGDisplayModelNumber(target);
    if (![displayUUID(target) isEqual:uuid] || !CGDisplayIsOnline(target) || CGDisplayIsBuiltin(target) ||
        CGDisplayIsAsleep(target) || CGDisplayIsInMirrorSet(target) || fabs(CGDisplayRotation(target))>0.1 ||
        vendor!=19501 || (product!=29287 && product!=29289)) {
        status(@"failed",0,@"Select an awake, unmirrored landscape M80B over HDMI or USB-C"); return 3;
    }
    CGDisplayModeRef oldMode=CGDisplayCopyDisplayMode(target);
    if (!oldMode) return 3;
    double rate=CGDisplayModeGetRefreshRate(oldMode);
    double aspect=(double)CGDisplayModeGetWidth(oldMode)/CGDisplayModeGetHeight(oldMode);
    if (!isfinite(rate) || !isfinite(aspect) || rate<59 || rate>60.5 || fabs(aspect-16.0/9.0)>0.02) {
        CFRelease(oldMode); status(@"failed",0,@"Use a reported 16:9 mode near 60 Hz first"); return 3;
    }
    CGRect oldBounds=CGDisplayBounds(target);
    CGVirtualDisplay *virtual=nil;
    CGDirectDisplayID virtualID=0;
    BOOL mirrored=NO, confirmed=NO, configurationApplied=NO;
    __block BOOL keep=NO, inputClosed=NO;
    NSTimer *runLoopAnchor=[NSTimer scheduledTimerWithTimeInterval:.05 repeats:YES block:^(NSTimer *timer) {}];
    signal(SIGTERM,stopSignal); signal(SIGINT,stopSignal); signal(SIGHUP,stopSignal); signal(SIGPIPE,SIG_IGN);
    @try {
        CGVirtualDisplayDescriptor *descriptor=[[NSClassFromString(@"CGVirtualDisplayDescriptor") alloc] init];
        descriptor.queue=dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE,0);
        descriptor.name=@"M8 Studio HiDPI Canvas";
        descriptor.vendorID=0x4D38; descriptor.productID=1;
        descriptor.serialNum=arc4random_uniform(UINT32_MAX-1)+1;
        if ([descriptor respondsToSelector:@selector(setSerialNumber:)]) descriptor.serialNumber=descriptor.serialNum;
        descriptor.maxPixelsWide=(unsigned int)width*2; descriptor.maxPixelsHigh=(unsigned int)(width*9/16)*2;
        CGSize physical=CGDisplayScreenSize(target);
        descriptor.sizeInMillimeters=physical.width>0 && physical.height>0 ? physical:CGSizeMake(697,392);
        // This describes an sRGB virtual source, not the target's measured primaries.
        descriptor.redPrimary=CGPointMake(.64,.33); descriptor.greenPrimary=CGPointMake(.30,.60);
        descriptor.bluePrimary=CGPointMake(.15,.06); descriptor.whitePoint=CGPointMake(.3127,.3290);
        virtual=[[NSClassFromString(@"CGVirtualDisplay") alloc] initWithDescriptor:descriptor];
        if (!virtual) @throw [NSException exceptionWithName:@"VirtualCanvas" reason:@"macOS refused virtual display creation" userInfo:nil];
        virtualID=virtual.displayID;
        CGVirtualDisplaySettings *settings=[[NSClassFromString(@"CGVirtualDisplaySettings") alloc] init];
        settings.hiDPI=1; settings.rotation=0;
        settings.modes=@[[[NSClassFromString(@"CGVirtualDisplayMode") alloc] initWithWidth:(unsigned int)width height:(unsigned int)(width*9/16) refreshRate:rate]];
        if (![virtual applySettings:settings]) @throw [NSException exceptionWithName:@"VirtualCanvas" reason:@"macOS rejected virtual HiDPI settings" userInfo:nil];
        // Creating the source after querying a physical display can leave the
        // creator unable to enumerate its modes. A separate, bounded configurator
        // gets a fresh CoreGraphics snapshot; the lifetime host owns recovery.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]];
        NSTask *worker=[[NSTask alloc] init];
        worker.executableURL=[NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments.firstObject];
        worker.arguments=@[@"--configure",[NSString stringWithFormat:@"%u",target],uuid,[NSString stringWithFormat:@"%u",virtualID],
                          [NSString stringWithFormat:@"%ld",width],[NSString stringWithFormat:@"%d",getpid()],
                          [NSString stringWithFormat:@"%zu",CGDisplayModeGetWidth(oldMode)],[NSString stringWithFormat:@"%zu",CGDisplayModeGetHeight(oldMode)],
                          [NSString stringWithFormat:@"%zu",CGDisplayModeGetPixelWidth(oldMode)],[NSString stringWithFormat:@"%zu",CGDisplayModeGetPixelHeight(oldMode)],
                          [NSString stringWithFormat:@"%.0f",rate*1000]];
        worker.standardOutput=[NSFileHandle fileHandleWithStandardOutput]; worker.standardError=[NSFileHandle fileHandleWithStandardError];
        NSError *launchError=nil;
        if (![worker launchAndReturnError:&launchError]) @throw [NSException exceptionWithName:@"VirtualCanvas" reason:@"Could not start the independent mode configurator" userInfo:nil];
        NSDate *workerDeadline=[NSDate dateWithTimeIntervalSinceNow:5];
        while (worker.running && !stopping && getppid()==owner && [workerDeadline timeIntervalSinceNow]>0)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
        if (worker.running) { [worker terminate]; [worker waitUntilExit]; }
        configurationApplied=worker.terminationStatus==0 || worker.terminationStatus==5 || CGDisplayMirrorsDisplay(target)==virtualID || CGDisplayMirrorsDisplay(virtualID)==target;
        if (worker.terminationStatus!=0) @throw [NSException exceptionWithName:@"VirtualCanvas" reason:@"Independent mirror setup did not complete" userInfo:nil];
        mirrored=CGDisplayMirrorsDisplay(target)==virtualID;
        if (!mirrored) @throw [NSException exceptionWithName:@"VirtualCanvas" reason:@"Mirror direction was not confirmed" userInfo:nil];
        status(@"preview",virtualID,@""); confirmed=YES;
        NSFileHandle *input=[NSFileHandle fileHandleWithStandardInput];
        NSMutableString *commands=[NSMutableString string];
        input.readabilityHandler=^(NSFileHandle *handle) {
            NSData *data=handle.availableData;
            NSString *command=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            dispatch_async(dispatch_get_main_queue(),^{
                if (!data.length) inputClosed=YES;
                if (command) [commands appendString:command];
                if (commands.length>128) inputClosed=YES;
                NSRange newline;
                while ((newline=[commands rangeOfString:@"\n"]).location!=NSNotFound) {
                    NSString *line=[commands substringToIndex:newline.location];
                    [commands deleteCharactersInRange:NSMakeRange(0,newline.location+1)];
                    if ([line isEqual:@"keep"]) keep=YES;
                    else inputClosed=YES;
                }
            });
        };
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:20];
        BOOL reportedKeep=NO;
        while (!stopping && !inputClosed && getppid()==owner && kill((pid_t)owner,0)==0 && CGDisplayIsOnline(target) && !CGDisplayIsAsleep(target) &&
               [displayUUID(target) isEqual:uuid] && CGDisplayMirrorsDisplay(target)==virtualID) {
            if (!keep && [deadline timeIntervalSinceNow]<=0) break;
            if (keep && !reportedKeep) { status(@"active",virtualID,@""); reportedKeep=YES; }
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.10]];
        }
        input.readabilityHandler=nil;
    } @catch(NSException *exception) { status(@"failed",virtualID,exception.reason); }
    // Removing our source ends its mirror even after the parent app has crashed.
    BOOL shouldRestore=configurationApplied && (!confirmed || CGDisplayMirrorsDisplay(target)==virtualID);
    virtual=nil;
    BOOL restored=YES;
    if (shouldRestore && [displayUUID(target) isEqual:uuid] && CGDisplayIsOnline(target)) {
        CGDisplayConfigRef restore=NULL;
        CGError result=CGBeginDisplayConfiguration(&restore);
        if (result==kCGErrorSuccess) result=CGConfigureDisplayMirrorOfDisplay(restore,target,kCGNullDirectDisplay);
        if (result==kCGErrorSuccess) result=CGConfigureDisplayWithDisplayMode(restore,target,oldMode,NULL);
        if (result==kCGErrorSuccess) result=CGConfigureDisplayOrigin(restore,target,(int32_t)oldBounds.origin.x,(int32_t)oldBounds.origin.y);
        if (result==kCGErrorSuccess) result=CGCompleteDisplayConfiguration(restore,kCGConfigureForSession);
        else if (restore) CGCancelDisplayConfiguration(restore);
        restored=result==kCGErrorSuccess;
    }
    [runLoopAnchor invalidate];
    CGDisplayModeRelease(oldMode);
    status(restored ? @"stopped":@"restoreFailed",virtualID,restored ? @"":@"Open macOS Displays to restore the arrangement");
    return confirmed && restored ? 0:4;
} }
