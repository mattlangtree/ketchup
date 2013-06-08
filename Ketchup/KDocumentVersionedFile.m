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

- (NSString *)description
{
  NSMutableString *desc = [NSMutableString string];
  
  [desc appendString:@"<KDocumentVersionedFile "];
  [desc appendString:self.fileUrl.path.description];
  [desc appendString:@">"];
  
  if (self.status & KFileStatusNone)
    [desc appendString:@" KFileStatusNone"];
  
  if (self.status & KFileStatusModified)
    [desc appendString:@" KFileStatusModified"];
  
  if (self.status & KFileStatusAdded)
    [desc appendString:@" KFileStatusAdded"];
  
  if (self.status & KFileStatusDeleted)
    [desc appendString:@" KFileStatusDeleted"];
  
  if (self.status & KFileStatusRenamed)
    [desc appendString:@" KFileStatusRenamed"];
  
  if (self.status & KFileStatusCopied)
    [desc appendString:@" KFileStatusCopied"];
  
  if (self.status & KFileStatusUpdated)
    [desc appendString:@" KFileStatusUpdated"];
  
  if (self.status & KFileStatusUntracked)
    [desc appendString:@" KFileStatusUntracked"];
  
  if (self.status & KFileStatusIgnored)
    [desc appendString:@" KFileStatusIgnored"];
  
  return desc.copy;
}

@end
