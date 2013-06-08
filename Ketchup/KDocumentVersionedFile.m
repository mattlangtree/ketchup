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
    [statusStrings addObject:@"Modified"];
  
  if (self.status & KFileStatusAdded)
    [statusStrings addObject:@"Added"];
  
  if (self.status & KFileStatusDeleted)
    [statusStrings addObject:@"Deleted"];
  
  if (self.status & KFileStatusRenamed)
    [statusStrings addObject:@"Renamed"];
  
  if (self.status & KFileStatusCopied)
    [statusStrings addObject:@"Copied"];
  
  if (self.status & KFileStatusUpdated)
    [statusStrings addObject:@"Updated"];
  
  if (self.status & KFileStatusUntracked)
    [statusStrings addObject:@"Untracked"];
  
  if (self.status & KFileStatusIgnored)
    [statusStrings addObject:@"Ignored"];
  
  return [statusStrings componentsJoinedByString:@", "];
}

- (BOOL)isWarningStatus
{
  if (self.status & KFileStatusUntracked)
    return YES;
  if (self.status & KFileStatusDeleted)
    return YES;
  
  return NO;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"Versioned File: %@ - %@", self.fileUrl.path.stringByAbbreviatingWithTildeInPath, self.humanReadibleStatus];
}

@end
