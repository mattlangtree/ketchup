//
//  KDocumentVersionedFile.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-8.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocumentVersionedFile.h"

@interface KDocumentVersionedFile()

@property (readwrite,strong) NSURL *fileUrl;
@property (readwrite) KDocumentVersionedFileStatus status;

@end

@implementation KDocumentVersionedFile

+ (id)fileWithUrl:(NSURL *)url status:(KDocumentVersionedFileStatus)status
{
  return [[[self class] alloc] initWithUrl:url status:status];
}

- (id)initWithUrl:(NSURL *)url status:(KDocumentVersionedFileStatus)status
{
  if (!(self = [super init]))
    return nil;

  self.fileUrl = url;
  self.status = status;
  
  return self;
}

- (id)init
{
  NSLog(@"cannot init KDocumentVersionedFile without params");
  return nil;
}

- (NSString *)humanReadibleStatus
{
  NSMutableArray *statusStrings = @[].mutableCopy;
  
  if (self.status & KFileStatusNone)
    [statusStrings addObject:@"None"];
  
  if (self.status & KFileStatusModified)
    [statusStrings addObject:@"M"];
  
  if (self.status & KFileStatusAdded)
    [statusStrings addObject:@"New"];
  
  if (self.status & KFileStatusDeleted)
    [statusStrings addObject:@"Deleted"];
  
  if (self.status & KFileStatusRenamed)
    [statusStrings addObject:@"Renamed"];
  
  if (self.status & KFileStatusCopied)
    [statusStrings addObject:@"Copied"];
  
  if (self.status & KFileStatusUpdated)
    [statusStrings addObject:@"Updated"];
  
  if (self.status & KFileStatusUntracked)
    [statusStrings addObject:@"?"];
  
  if (self.status & KFileStatusIgnored)
    [statusStrings addObject:@"Ignored"];
  
  if (self.status & KFileStatusConflicted)
    [statusStrings addObject:@"Conflicted"];
  
  if (self.status & KFileStatusIncomplete)
    [statusStrings addObject:@"Incomplete"];
  
  if (self.status & KFileStatusMerged)
    [statusStrings addObject:@"Merged"];
  
  if (self.status & KFileStatusMissing)
    [statusStrings addObject:@"Missing"];
  
  if (self.status & KFileStatusObstructed)
    [statusStrings addObject:@"Obstructed"];
  
  if (self.status & KFileStatusReplaced)
    [statusStrings addObject:@"Replaced"];

  
  return [statusStrings componentsJoinedByString:@", "];
}

- (BOOL)isWarningStatus
{
  if (self.status & KFileStatusUntracked)
    return YES;
  
  if (self.status & KFileStatusDeleted)
    return YES;
  
  if (self.status & KFileStatusConflicted)
    return YES;
  
  if (self.status & KFileStatusIncomplete)
    return YES;
  
  if (self.status & KFileStatusMissing)
    return YES;
  
  if (self.status & KFileStatusObstructed)
    return YES;
  
  if (self.status & KFileStatusReplaced)
    return YES;
  
  return NO;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"Versioned File: %@ - %@", self.fileUrl.path.stringByAbbreviatingWithTildeInPath, self.humanReadibleStatus];
}

@end
