//
//  KGitDocument.h
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocument.h"

typedef NS_OPTIONS(NSUInteger, KDocumentWorkingCopyStatus) {
  kWorkingCopyStatusNone        = 0,         // no status
  kWorkingCopyStatusChecking    = 1 << 0,
  kWorkingCopyStatusSynced      = 1 << 1,
  kWorkingCopyStatusRemoteAhead = 1 << 2,
  kWorkingCopyStatusLocalAhead  = 1 << 3,
};

@interface KGitDocument : KDocument
{
  NSString *kWorkingCopyStatusNoneString;
  NSString *kWorkingCopyStatusCheckingString;
  NSString *kWorkingCopyStatusSyncedString;
  NSString *kWorkingCopyStatusRemoteAheadString;
  NSString *kWorkingCopyStatusLocalAheadString;
}

@property (nonatomic) KDocumentWorkingCopyStatus status;

@end
