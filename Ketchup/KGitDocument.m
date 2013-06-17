//
//  KGitDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KGitDocument.h"
#import "KDocumentVersionedFile.h"

@interface KGitDocument()

@property (strong) NSArray *filesWithStatus;

@end


@implementation KGitDocument

- (id)init
{
  if ((self = [super init])) {

    kWorkingCopyStatusNoneString = NSLocalizedString(@"Checking Status", nil);
    kWorkingCopyStatusCheckingString = NSLocalizedString(@"Checking Status", nil);
    kWorkingCopyStatusSyncedString = NSLocalizedString(@"Synced with Remote", nil);
    kWorkingCopyStatusRemoteAheadString = NSLocalizedString(@"Remote contains newer commits", nil);
    kWorkingCopyStatusLocalAheadString = NSLocalizedString(@"Local contains newer commits", nil);
    
    self.status = kWorkingCopyStatusNone;
    [self updateRemoteSyncStatus];
  }
  return self;
}

- (void)updateRemoteSyncStatus
{
  switch (self.status) {
    case kWorkingCopyStatusNone:
      self.remoteStatusField.stringValue = kWorkingCopyStatusNoneString;
      break;
    case kWorkingCopyStatusChecking:
      self.remoteStatusField.stringValue = kWorkingCopyStatusCheckingString;
      break;
    case kWorkingCopyStatusSynced:
      self.remoteStatusField.stringValue = kWorkingCopyStatusSyncedString;
      break;
    case kWorkingCopyStatusRemoteAhead:
      self.remoteStatusField.stringValue = kWorkingCopyStatusRemoteAheadString;
      break;
    case kWorkingCopyStatusLocalAhead:
      self.remoteStatusField.stringValue = kWorkingCopyStatusLocalAheadString;
      break;      
  }
}

- (NSArray *)fetchFilesWithStatus
{
  // run `git status --percelain -z`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"status", @"-z"];
  task.currentDirectoryPath = self.fileURL.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  [task waitUntilExit];
  
  // grab the output data, and check for an error
  NSData *outputData = [[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSString *error = [[NSString alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  if (error.length > 0) {
    NSLog(@"Git error: %@", error);
    return @[];
  }
  
  // parse the output (NULL separated list of files)
  NSData *nullData = [[NSData alloc] initWithBytes:"\0" length:1];
  NSUInteger scanLocation = 0;
  NSUInteger dataLength = outputData.length;
  NSCharacterSet *whitespaceCharacters = [NSCharacterSet whitespaceCharacterSet];
  NSMutableArray *files = [NSMutableArray array];

  BOOL isRenamedFile = NO;

  while (scanLocation < dataLength) {
    NSUInteger nullLocation = [outputData rangeOfData:nullData options:0 range:NSMakeRange(scanLocation, dataLength - scanLocation)].location;
    if (nullLocation == NSNotFound)
      nullLocation = dataLength - 1;
    
    // decode the data
    NSData *scanData = [outputData subdataWithRange:NSMakeRange(scanLocation, nullLocation - scanLocation)];
    NSString *scanString = [[NSString alloc] initWithData:scanData encoding:NSUTF8StringEncoding];
    
    // trim leading whitespace
    NSUInteger nonWhitespaceLocation = [scanString rangeOfCharacterFromSet:whitespaceCharacters.invertedSet].location;
    if (nonWhitespaceLocation == NSNotFound) {
      NSLog(@"failed to parse git output");
      return @[];
    }
    if (nonWhitespaceLocation > 0) {
      scanString = [scanString substringFromIndex:nonWhitespaceLocation];
    }

    // Handle special case where files are renamed.
    if (isRenamedFile) {
      KDocumentVersionedFile *file = (KDocumentVersionedFile *)[files lastObject];

      NSURL *fileUrl = [self.fileURL URLByAppendingPathComponent:scanString];
      if (!fileUrl) {
        NSLog(@"cannot find file '%@'", scanString);
        return @[];
      }
      file.previousFileUrl = fileUrl;
      scanLocation = nullLocation + 1;
      isRenamedFile = NO;
      continue;
    }

    // find the first whitespace char (everything before it is the "status" of a file
    NSUInteger whitespaceLocation = [scanString rangeOfCharacterFromSet:whitespaceCharacters].location;
    if (whitespaceLocation == NSNotFound) {
      NSLog(@"failed to parse git output");
      return @[];
    }
    nonWhitespaceLocation = [scanString rangeOfCharacterFromSet:whitespaceCharacters.invertedSet options:0 range:NSMakeRange(whitespaceLocation, scanString.length - whitespaceLocation)].location;
    if (nonWhitespaceLocation == NSNotFound) {
      NSLog(@"failed to parse git output");
      return @[];
    }
    NSString *statusString = [scanString substringToIndex:whitespaceLocation];
    NSString *filePathString = [scanString substringFromIndex:nonWhitespaceLocation];
    
    // decode the status
    KDocumentVersionedFileStatus status = 0;
    for (NSUInteger statusIndex = 0; statusIndex < statusString.length; statusIndex++) {
      switch ([statusString characterAtIndex:statusIndex]) {
        case 'M':
          status |= KFileStatusModified;
          break;
        case 'A':
          status |= KFileStatusAdded;
          break;
        case 'D':
          status |= KFileStatusDeleted;
          break;
        case 'R':
          status |= KFileStatusRenamed;
          break;
        case 'C':
          status |= KFileStatusCopied;
          break;
        case 'U':
          status |= KFileStatusUpdated;
          break;
        case '?':
          status |= KFileStatusUntracked;
          break;
        case '!':
          status |= KFileStatusIgnored;
        default:
          NSLog(@"failed to parse git status: '%@'", statusString);
          return @[];
          break;
      }
    }

    if (status == KFileStatusRenamed) {
      isRenamedFile = YES;
    }
    
    // create a url and make sure it actually exists (to see if we decoded the string properly)
    NSURL *fileUrl = [self.fileURL URLByAppendingPathComponent:filePathString];
    if (!fileUrl) {
      NSLog(@"cannot find file '%@' in '%@'", filePathString, scanString);
      return @[];
    }
    
    // record it, and move on to the text file
    [files addObject:[KDocumentVersionedFile fileWithUrl:fileUrl status:status]];
    
    scanLocation = nullLocation + 1;
  }
  
  return files.copy;
}

- (void)autoSyncButtonChanged:(id)sender
{
  self.commitButton.title = (self.commitAutoSyncButton.state == NSOnState) ? @"Commit and Sync" : @"Commit";
  [self.commitButton sizeToFit];
  self.commitButton.frame = self.commitButton.frame = NSMakeRect(self.sidebarView.frame.size.width - 16 - self.commitButton.frame.size.width, 4, self.commitButton.frame.size.width + 6, self.commitButton.frame.size.height + 1);

}


- (void)syncWithRemote:(id)sender
{
  self.status = kWorkingCopyStatusChecking;
  [self updateRemoteSyncStatus];

  [self pullFromRemote];
  
  [self pushToRemote];
}

- (void)commit
{
  [self addFiles];
  [self commitFiles];
  
  if (self.commitAutoSyncButton.state == NSOnState) {
    [self pushToRemote];
  }
  
  self.filesWithStatus = [self fetchFilesWithStatus];
  [self.filesOutlineView reloadData];
  
  [self.commitTextView setString:@""];
}

- (void)addFiles
{
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"add", @"-A"];
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
}

- (void)commitFiles
{
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
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

    if (([errorString rangeOfString:@"Aborting commit due to empty commit message."].length != NSNotFound)) {
      NSAlert *alert = [[NSAlert alloc] init];
      [alert addButtonWithTitle:@"OK"];
      [alert setMessageText:@"Please enter a commit message."];
      [alert setAlertStyle:NSCriticalAlertStyle];
      [alert beginSheetModalForWindow:self.window
                        modalDelegate:self
                       didEndSelector:nil
                          contextInfo:NULL];
    }
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
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"pull", @"origin",@"master"];
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

- (void)pushToRemote
{
  // Need to add logic in here to make sure that the authentication dialog is
  // shown if the user hasn't authenticated with git yet.
  
  //  [self showAuthenticationDialog:self.commitButton];
  //  return;
  
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"push", @"origin",@"master",@"--porcelain"];
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
  
  self.status = kWorkingCopyStatusSynced;
  [self updateRemoteSyncStatus];
  
}

@end
