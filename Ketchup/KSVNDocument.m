//
//  KSVNDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KSVNDocument.h"
#import "KDocumentVersionedFile.h"
#import "KChange.h"
#import "KSVNDiffOperation.h"

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

      if ([error rangeOfString:@"E155036"].location != NSNotFound) {
          NSAlert *alert = [[NSAlert alloc] init];
          [alert addButtonWithTitle:@"OK"];
          [alert setMessageText:@"Repository is too old"];
          [alert setInformativeText:@"For Ketchup to use this repository you need to run `svn upgrade` from the command line."];
          [alert setAlertStyle:NSInformationalAlertStyle];
          [alert runModal];
      }

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
    NSURL *fileUrl = ([filePathString characterAtIndex:0] == '/') ? [NSURL fileURLWithPath:filePathString] : [self.fileURL URLByAppendingPathComponent:filePathString];
    if (!fileUrl) {
      NSLog(@"cannot find file '%@' in '%@'", filePathString, entry);
      return @[];
    }
    
    // record the file
    [files addObject:[KDocumentVersionedFile fileWithUrl:fileUrl status:status]];
  }
  
  return files.copy;
}

- (NSString *)baseContentsOfFile:(KDocumentVersionedFile *)file
{
  // run `svn cat -r HEAD file`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = self.svnLaunchPath;
  task.arguments = @[@"cat", @"-r", @"BASE", file.fileUrl.path];
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

- (KDiffOperation *)diffOperationForFile:(KDocumentVersionedFile *)file
{
  return [KSVNDiffOperation diffOperationWithFileUrl:file.fileUrl];
}

- (NSString *)syncButtonTitle
{
  return @"Update";
}

- (void)autoSyncButtonChanged:(id)sender
{
  self.commitButton.title = (self.commitAutoSyncButton.state == NSOnState) ? @"Update & Commit" : @"Commit";
  [self.commitButton sizeToFit];
  self.commitButton.frame = self.commitButton.frame = NSMakeRect(self.sidebarView.frame.size.width - 16 - self.commitButton.frame.size.width, 4, self.commitButton.frame.size.width + 6, self.commitButton.frame.size.height + 1);
}

- (void)syncWithRemote:(id)sender
{
  self.status = kWorkingCopyStatusChecking;
  [self updateRemoteSyncStatus];
  
  [self pullFromRemote];
  
  [self commitFiles];
}


- (void)commit
{
  // Super does some extra view drawing..
  [super commit];
  
  [self addFiles];
  [self commitFiles];
  
  self.filesWithStatus = [self fetchFilesWithStatus];
  [self.filesOutlineView reloadData];

  [self.commitTextView setString:@""];

  // Super does some extra view drawing..
  [super commitDidFinish];
}

- (void)addFiles
{
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSMutableArray *filesList = [[NSMutableArray alloc] init];
  [self.filesWithStatus enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      KDocumentVersionedFile *versionedFile = (KDocumentVersionedFile *)obj;
      if (versionedFile.includeInCommit == YES && versionedFile.status == KFileStatusUntracked) {
          [filesList addObject:versionedFile.fileUrl.path];
      }
  }];
  
  if ([filesList count] == 0) {
    return;
  }
  
  NSTask *task = [[NSTask alloc] init];

  if ([self.filesWithStatus count] == [filesList count]) {
    task.launchPath = @"/bin/sh";
    NSString *addCommand = [[self svnLaunchPath] stringByAppendingFormat:@" add * --force"];
    task.arguments = @[@"-c",addCommand];
  }
  else {
    task.launchPath = [self svnLaunchPath];
    [filesList insertObject:@"add" atIndex:0];
    task.arguments = filesList;
  }
  
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
  NSMutableArray *filesList = [[NSMutableArray alloc] init];
  [self.filesWithStatus enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    KDocumentVersionedFile *versionedFile = (KDocumentVersionedFile *)obj;
    if (versionedFile.includeInCommit == YES) {
      [filesList addObject:versionedFile.fileUrl.path];
    }
  }];
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = [self svnLaunchPath];
  NSArray *arguments = @[@"commit", @"-m",self.commitTextView.string];
  
  if ([self.filesWithStatus count] != [filesList count]) {
    arguments = [arguments arrayByAddingObjectsFromArray:filesList];
    task.arguments = arguments;
  }
  else {
    task.arguments = arguments;
  }
  
  NSLog(@"Current directory: %@",self.fileURL.path);
  
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

- (void)pullFromRemote
{
  // Need to add logic in here to make sure that the authentication dialog is
  // shown if the user hasn't authenticated with git yet.
  
  //  [self showAuthenticationDialog:self.commitButton];
  //  return;
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = [self svnLaunchPath];
  task.arguments = @[@"update"];
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
  
  self.status = kWorkingCopyStatusSynced;
  [self updateRemoteSyncStatus];
  
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
