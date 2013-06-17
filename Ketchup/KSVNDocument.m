//
//  KSVNDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KSVNDocument.h"
#import "KDocumentVersionedFile.h"

@interface KSVNDocument()

@property (strong) NSArray *filesWithStatus;

@end


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

- (NSArray *)changesInFile:(KDocumentVersionedFile *)file
{
  // run `svn diff file`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = self.svnLaunchPath;
  task.arguments = @[@"diff", file.fileUrl.path];
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
  
  NSString *textContent = [NSString stringWithUnknownData:outputData usedEncoding:NULL];
  if (!textContent) {
    NSLog(@"cannot diff file %@", file.fileUrl);
    return @[];
  }
  
  BOOL areScanningChangeset = NO;
  NSRange leftLineRange = NSMakeRange(0, 0);
  NSRange rightLineRange = NSMakeRange(0, 0);
  NSRegularExpression *changesetLineDeltaPattern = [NSRegularExpression regularExpressionWithPattern:@"([0-9]+)\\,([0-9]+)" options:0 error:NULL];
  NSMutableArray *changes = [NSMutableArray array];
  for (NSValue *rangeValue in [textContent lineEnumeratorForLinesInRange:NSMakeRange(0, textContent.length)]) {
    NSRange lineRange = rangeValue.rangeValue;
    
    if ([textContent characterAtIndex:lineRange.location] == '@' && [textContent characterAtIndex:lineRange.location + 1] == '@') {
      areScanningChangeset = YES;

      NSString *line = [textContent substringWithRange:lineRange];
      NSArray *matches = [changesetLineDeltaPattern matchesInString:line options:0 range:NSMakeRange(0, line.length)];
      
      leftLineRange.location = [[line substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:1]] integerValue];
      leftLineRange.length = [[line substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:2]] integerValue];
      
      rightLineRange.location = [[line substringWithRange:[[matches objectAtIndex:1] rangeAtIndex:1]] integerValue];
      rightLineRange.length = [[line substringWithRange:[[matches objectAtIndex:1] rangeAtIndex:2]] integerValue];
      
      [changes addObject:@{
       @"leftLineRange": @[[NSNumber numberWithUnsignedInteger:rightLineRange.location], [NSNumber numberWithUnsignedInteger:rightLineRange.length]],
       @"rightLineRange": @[[NSNumber numberWithUnsignedInteger:leftLineRange.location], [NSNumber numberWithUnsignedInteger:leftLineRange.length]]
       }];
      
      continue;
    }
  }
  
  NSLog(@"%@", changes);
  
  return changes.copy;
}

- (NSString *)syncButtonTitle
{
  return @"Update";
}

- (void)commit
{
  [self addFiles];
  [self commitFiles];
  
  self.filesWithStatus = [self fetchFilesWithStatus];
  [self.filesOutlineView reloadData];

  [self.commitTextView setString:@""];
}

- (void)addFiles
{
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSString *addCommand = [[self svnLaunchPath] stringByAppendingFormat:@" add * --force"];
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/bin/sh";
  task.arguments = @[@"-c",addCommand];
  task.currentDirectoryPath = self.fileURL.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  [task waitUntilExit];
  
  NSData *output = [[NSData alloc] initWithData:[[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile]];
  NSData *error = [[NSData alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile]];
  
  NSString *outputString = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
  NSString *errorString = [[NSString alloc] initWithData:error encoding:NSUTF8StringEncoding];
  
  if (errorString.length > 0) {
    NSLog(@"error happened: %@",errorString);
    return;
  }
  
  NSLog(@"outputString: %@",outputString);
  
}

- (void)commitFiles
{
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = [self svnLaunchPath];
  task.arguments = @[@"commit", @"-m",self.commitTextView.string];
  task.currentDirectoryPath = self.fileURL.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  [task waitUntilExit];
  
  NSData *output = [[NSData alloc] initWithData:[[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile]];
  NSData *error = [[NSData alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile]];
  
  NSString *outputString = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
  NSString *errorString = [[NSString alloc] initWithData:error encoding:NSUTF8StringEncoding];
  
  if (errorString.length > 0) {
    NSLog(@"error happened: %@",errorString);
    return;
  }
  
  NSLog(@"outputString: %@",outputString);
    
}


- (void)discardChangesInFile:(KDocumentVersionedFile *)versionedFile
{
    if (versionedFile.status == KFileStatusUntracked) {
        // I didn't want to write deletion code.. so delete the file yourself..
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[versionedFile.fileUrl]];

        return;
    }

    NSLog(@"Current directory: %@",self.fileURL.path);

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = [self svnLaunchPath];
    task.arguments = @[@"revert", versionedFile.fileUrl.path];
    task.currentDirectoryPath = self.fileURL.path;
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];

    [task launch];
    [task waitUntilExit];

    NSData *output = [[NSData alloc] initWithData:[[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile]];
    NSData *error = [[NSData alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile]];

    NSString *outputString = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
    NSString *errorString = [[NSString alloc] initWithData:error encoding:NSUTF8StringEncoding];

    if (errorString.length > 0) {
        NSLog(@"error happened: %@",errorString);
    }

    NSLog(@"outputString: %@",outputString);

    self.filesWithStatus = [self fetchFilesWithStatus];
    [self.filesOutlineView reloadData];
}

@end
