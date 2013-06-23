//
//  KSyncronizedScrollView.h
//  Ketchup
//
//  Created by Abhi Beckert on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KSyncronizedScrollView : NSScrollView
{
  NSScrollView* synchronizedScrollView; // not retained
}

- (void)setSynchronizedScrollView:(NSScrollView*)scrollview;
- (void)stopSynchronizing;
- (void)synchronizedViewContentBoundsDidChange:(NSNotification *)notification;

@end
