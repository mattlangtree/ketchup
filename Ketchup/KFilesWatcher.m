//
//  KFilesWatcher.m
//  Ketchup
//
//  Created by Matt Langtree on 17/06/13.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KFilesWatcher.h"

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    [[NSNotificationCenter defaultCenter] postNotificationName:KFilesDidChangeNotification
                                                        object:nil];
}

@implementation KFilesWatcher

- (id)init
{
    self = [super init];
    if (self) {
        fm = [NSFileManager defaultManager];
    }
    return self;
}

+ (KFilesWatcher *)sharedWatcher
{
    static KFilesWatcher *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[KFilesWatcher alloc] init];
    });
    return sharedInstance;
}

- (void)startWatchingWithPath:(NSString *)watchPath
{
    startedWatchingTimestamp = [NSDate date];
    pathModificationDates = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"pathModificationDates"] mutableCopy];
    lastEventId = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastEventId"];

    NSArray *pathsToWatch = [NSArray arrayWithObject:watchPath];
    NSTimeInterval latency = 3.0;

	stream = FSEventStreamCreate(NULL,
	                             &fsevents_callback,
	                             NULL,
	                             (__bridge CFArrayRef) pathsToWatch,
	                             [lastEventId unsignedLongLongValue],
	                             (CFAbsoluteTime) latency,
	                             kFSEventStreamCreateFlagUseCFTypes
                                 );

	FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(stream);
}

- (void) registerDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *appDefaults = [NSDictionary
	                             dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedLongLong:kFSEventStreamEventIdSinceNow], [NSMutableDictionary new], nil]
	                             forKeys:[NSArray arrayWithObjects:@"lastEventId", @"pathModificationDates", nil]];
	[defaults registerDefaults:appDefaults];
}


- (void)updateLastModificationDateForPath: (NSString *)path
{
	[pathModificationDates setObject:[NSDate date] forKey:path];
}

- (NSDate *)lastModificationDateForPath: (NSString *)path
{
	if(nil != [pathModificationDates valueForKey:path]) {
		return [pathModificationDates valueForKey:path];
	}
	else{
		return startedWatchingTimestamp;
	}
}


- (void)updateLastEventId: (uint64_t) eventId
{
	lastEventId = [NSNumber numberWithUnsignedLongLong:eventId];
}

- (void)stopWatching
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:lastEventId forKey:@"lastEventId"];
	[defaults setObject:pathModificationDates forKey:@"pathModificationDates"];
	[defaults synchronize];
    FSEventStreamStop(stream);
    FSEventStreamInvalidate(stream);
}

@end

const NSString *KFilesDidChangeNotification = @"KFilesDidChangeNotification";
