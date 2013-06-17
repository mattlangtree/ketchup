//
//  KFilesWatcher.h
//  Ketchup
//
//  Created by Matt Langtree on 17/06/13.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KFilesWatcher : NSObject
{
    NSFileManager* fm;
    NSMutableDictionary* pathModificationDates;
    NSDate* startedWatchingTimestamp;
    NSNumber* lastEventId;
    FSEventStreamRef stream;
}

+ (KFilesWatcher *)sharedWatcher;
- (void)startWatchingWithPath:(NSString *)watchPath;
- (void)stopWatching;

@end

extern NSString *KFilesDidChangeNotification;