//
//  KSVNDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KSVNDocument.h"
#import "KDocumentVersionedFile.h"

@implementation KSVNDocument

- (NSString *)svnLaunchPath
{
  static NSString *path = nil;
  
  if (path)
    return path;
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/svn"]) {
    path = @"/usr/local/bin/svn";
  } else {
    path = @"/usr/bin/svn";
  }
  
  return path;
}

- (NSArray *)fetchFilesWithStatus
{
  // run `svn status --xml`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = self.svnLaunchPath;
  task.arguments = @[@"status", @"--xml"];
  task.currentDirectoryPath = self.fileURL.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  [task waitUntilExit];
  
  // grab the output data, and check for an error
  NSData *outputData = [[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSString *error = [[NSString alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  if (error.length > 0) {
    NSLog(@"Svn error: %@", error);
    return @[];
  }
  
  // parse xml
  NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithData:outputData options:0 error:NULL];
  if (!xmlDoc) {
    NSLog(@"failed to parse svn output");
    return @[];
  }
  
  // process entries
  NSArray *entries = [xmlDoc nodesForXPath:@"./status/target/entry" error:NULL];
  
  NSMutableArray *files = [NSMutableArray array];
  for (NSXMLNode *entry in entries) {
    // decode the status
    KDocumentVersionedFileStatus status = 0;
    
    for (NSXMLNode *statusNode in [entry nodesForXPath:@"wc-status/@item" error:NULL]) {
      NSString *statusString = statusNode.stringValue;
      
      if ([statusString isEqualToString:@"added"]) {
        status |= KFileStatusAdded;
      } else if ([statusString isEqualToString:@"conflicted"]) {
        status |= KFileStatusConflicted;
      } else if ([statusString isEqualToString:@"deleted"]) {
        status |= KFileStatusDeleted;
      } else if ([statusString isEqualToString:@"external"]) {
        continue; // skip over entries with this status
      } else if ([statusString isEqualToString:@"ignored"]) {
        status |= KFileStatusIgnored;
      } else if ([statusString isEqualToString:@"incomplete"]) {
        status |= KFileStatusIncomplete;
      } else if ([statusString isEqualToString:@"merged"]) {
        status |= KFileStatusMerged;
      } else if ([statusString isEqualToString:@"missing"]) {
        status |= KFileStatusMissing;
      } else if ([statusString isEqualToString:@"modified"]) {
        status |= KFileStatusModified;
      } else if ([statusString isEqualToString:@"none"]) {
        status |= KFileStatusNone;
      } else if ([statusString isEqualToString:@"normal"]) {
        status |= KFileStatusNone;
      } else if ([statusString isEqualToString:@"obstructed"]) {
        status |= KFileStatusObstructed;
      } else if ([statusString isEqualToString:@"replaced"]) {
        status |= KFileStatusReplaced;
      } else if ([statusString isEqualToString:@"unversioned"]) {
        status |= KFileStatusUntracked;
      } else {
        NSLog(@"unknown svn status: %@", statusString);
        return @[];
      }
    }
    if (status == 0) // this means the file has no status or we are ignoring files with this status
      continue;
    
    // create a url and make sure it actually exists (to see if we decoded the string properly)
    NSArray *paths = [entry nodesForXPath:@"@path" error:NULL];
    
    if (paths.count != 1)
      NSLog(@"failed to parse svn entry %@", entry);
    
    NSString *filePathString = [[paths objectAtIndex:0] stringValue];
    NSURL *fileUrl = [self.fileURL URLByAppendingPathComponent:filePathString];
    if (!fileUrl) {
      NSLog(@"cannot find file '%@' in '%@'", filePathString, entry);
      return @[];
    }
    
    // record the file
    [files addObject:[KDocumentVersionedFile fileWithUrl:fileUrl status:status]];
  }
  
  return files.copy;
}

- (NSString *)headContentsOfFile:(KDocumentVersionedFile *)file
{
  // run `svn cat -r HEAD file`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = self.svnLaunchPath;
  task.arguments = @[@"cat", @"-r", @"HEAD", file.fileUrl.path];
  task.currentDirectoryPath = self.fileURL.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  [task waitUntilExit];
  
  // grab the output data, and check for an error
  NSData *outputData = [[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSString *error = [[NSString alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  if (error.length > 0) {
    NSLog(@"Svn error: %@", error);
    return @"";
  }
  
  NSString *textContent = [NSString stringWithUnknownData:outputData usedEncoding:NULL];
  if (!textContent) {
    NSLog(@"cannot read file %@", file.fileUrl);
    return @"";
  }
  
  return textContent;
}

- (NSString *)syncButtonTitle
{
  return @"Update";
}

- (void)commit
{
  NSLog(@"Commit not implemented for SVN yet.");
}

@end
