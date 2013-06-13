//
//  KDocumentVersionedFile.h
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-8.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, KDocumentVersionedFileStatus) {
  KFileStatusNone       = 0,         // no status
  KFileStatusModified   = 1 << 0,    // 'M'
  KFileStatusAdded      = 1 << 1,    // 'A'
  KFileStatusDeleted    = 1 << 2,    // 'D'
  KFileStatusRenamed    = 1 << 3,    // 'R' in git. not supported in svn
  KFileStatusCopied     = 1 << 4,    // 'C' in git. not supported in svn
  KFileStatusUpdated    = 1 << 5,    // 'U'
  KFileStatusUntracked  = 1 << 6,    // '?'
  KFileStatusIgnored    = 1 << 7,    // '!' in git
  KFileStatusConflicted = 1 << 8,
  KFileStatusIncomplete = 1 << 9,
  KFileStatusMerged     = 1 << 10,
  KFileStatusMissing    = 1 << 11,
  KFileStatusObstructed = 1 << 12,
  KFileStatusReplaced   = 1 << 13
};

@interface KDocumentVersionedFile : NSObject

@property (readonly) NSURL *fileUrl;
@property (nonatomic,strong) NSURL *previousFileUrl;
@property (readonly) KDocumentVersionedFileStatus status;
@property (readonly) NSString *humanReadibleStatus;
@property (readonly) BOOL isWarningStatus; // status is deleted, conflict, untracked, etc

+ (id)fileWithUrl:(NSURL *)url status:(KDocumentVersionedFileStatus)status;
- (id)initWithUrl:(NSURL *)url status:(KDocumentVersionedFileStatus)status;

@end
