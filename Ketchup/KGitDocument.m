//
//  KGitDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KGitDocument.h"
#import "KDocumentVersionedFile.h"
#import "KGitDiffOperation.h"

@interface KGitDocument()

@property (strong) NSArray *filesWithStatus;

@end


@implementation KGitDocument

- (id)init
{
  if ((self = [super init])) {

  }
  return self;
}

- (void)documentSpecificViewCustomisations
{
    CGFloat windowHeight = [self.window.contentView frame].size.height;
    CGFloat sidebarWidth = 250;
//    CGFloat contentWidth = [self.window.contentView frame].size.width - sidebarWidth;
//    CGFloat commitMessageHeight = 200;
    
  self.commitsView = [[NSView alloc] initWithFrame:NSMakeRect(0, windowHeight - 110, sidebarWidth, 70)];
  self.commitsView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.sidebarView addSubview:self.commitsView];
  
  self.commitsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.commitsLabel.backgroundColor = [NSColor clearColor];
  self.commitsLabel.editable = NO;
  self.commitsLabel.bordered = NO;
  self.commitsLabel.font = [NSFont fontWithName:@"HelveticaNeue-Bold" size:12.f];
  self.commitsLabel.textColor = [NSColor colorWithDeviceRed:0.44 green:0.49 blue:0.55 alpha:1.0];
  self.commitsLabel.shadow = [[NSShadow alloc] init];
  self.commitsLabel.shadow.shadowOffset = NSMakeSize(0, 1);
  self.commitsLabel.shadow.shadowBlurRadius = 0.25;
  self.commitsLabel.shadow.shadowColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
  self.commitsLabel.stringValue = @"UNSYNCED COMMITS";
  [self.commitsLabel sizeToFit];
  self.commitsLabel.frame = NSMakeRect(10, self.commitsView.frame.size.height - self.commitsLabel.frame.size.height, self.commitsLabel.frame.size.width, self.commitsLabel.frame.size.height);
  [self.commitsView addSubview:self.commitsLabel];

  [self updateCurrentBranch];
  
  NSMenu *branchMenu = [[NSMenu alloc] init];
  NSMenuItem *menuItem = [branchMenu addItemWithTitle:@"Edit .gitignore" action:@selector(showGitIgnore:) keyEquivalent:@""];
  
  self.currentBranchButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, 20)];
  [self.currentBranchButton setButtonType:NSMomentaryPushInButton];
  [self.currentBranchButton setBordered:NO];
  self.currentBranchButton.font = [NSFont fontWithName:@"HelveticaNeue-Bold" size:12.f];
  self.currentBranchButton.title = self.currentBranchString;
  [self.currentBranchButton sizeToFit];
  [self.currentBranchButton setMenu:branchMenu];
  self.currentBranchButton.frame = NSMakeRect(10, self.remoteView.frame.size.height - self.currentBranchButton.frame.size.height, self.currentBranchButton.frame.size.width, self.currentBranchButton.frame.size.height);
  
  [self.remoteStatusIconView setHidden:YES];
  [self.remoteView addSubview:self.currentBranchButton];
//  self.remoteView.layer.backgroundColor = [NSColor redColor].CGColor;
  self.remoteStatusField.frame = NSMakeRect(10, 3, sidebarWidth - 50, 20);
  self.remoteStatusField.font = [NSFont fontWithName:@"HelveticaNeue" size:12.f];
  
  [self updateUnsyncedCommits];

  self.unsyncedcommitsList = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.unsyncedcommitsList.backgroundColor = [NSColor clearColor];
  self.unsyncedcommitsList.editable = NO;
  self.unsyncedcommitsList.font = [NSFont fontWithName:@"HelveticaNeue" size:12.f];
  self.unsyncedcommitsList.textColor = [NSColor textColor];
  self.unsyncedcommitsList.string = [self.unsyncedCommits componentsJoinedByString:@"\n"];
  
  __block NSString *commitsListString = @"";
  [self.unsyncedCommits enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    commitsListString = [commitsListString stringByAppendingFormat:@"%@\n",[obj substringToIndex:MIN([obj length],20)]];
  }];
  
  self.unsyncedcommitsList.string = commitsListString;
  self.unsyncedcommitsList.frame = NSMakeRect(10, 0, sidebarWidth - 20, 40);
  [self.commitsView addSubview:self.unsyncedcommitsList];

  self.filesView.frame = NSMakeRect(0, 200, sidebarWidth, windowHeight - 300);
}

- (void)showGitIgnore:(id)sender
{
  NSString *currentDirectoryPath = self.fileURL.path;
  NSString *gitIgnorePath = [currentDirectoryPath stringByAppendingPathComponent:@"/.gitignore"];
  [[NSWorkspace sharedWorkspace] openFile:gitIgnorePath];
}

- (NSArray *)fetchFilesWithStatus
{
  [self.syncProgressIndicator setHidden:NO];
  [self.syncProgressIndicator startAnimation:self];

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
  
  [self.syncProgressIndicator setHidden:YES];
  [self.syncProgressIndicator stopAnimation:self];

  
  return files.copy;
}

- (KDiffOperation *)diffOperationForFile:(KDocumentVersionedFile *)file
{
  return [KGitDiffOperation diffOperationWithFileUrl:file.fileUrl workingDirectoryURL:self.fileURL];
}

- (void)autoSyncButtonChanged:(id)sender
{
  if (self.commitAutoSyncButton.state == NSOnState) {
    [self.filesWithStatus enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      KDocumentVersionedFile *versionedFile = (KDocumentVersionedFile *)obj;
        versionedFile.includeInCommit = YES;
    }];
  }
  [self.filesOutlineView reloadData];

  self.commitButton.title = (self.commitAutoSyncButton.state == NSOnState) ? @"Commit and Sync" : @"Commit";
  [self.commitButton sizeToFit];
  self.commitButton.frame = self.commitButton.frame = NSMakeRect(self.sidebarView.frame.size.width - 16 - self.commitButton.frame.size.width, 4, self.commitButton.frame.size.width + 6, self.commitButton.frame.size.height + 1);

}


- (void)syncWithRemote:(id)sender
{
  [self.syncProgressIndicator setHidden:NO];
  [self.syncProgressIndicator startAnimation:self];

  self.status = kWorkingCopyStatusChecking;
  [self updateRemoteSyncStatus];

  [self pullFromRemote];
  
  [self pushToRemote];
  
  [self updateUnsyncedCommits];
  self.unsyncedcommitsList.string = [self.unsyncedCommits componentsJoinedByString:@"\n"];
  
  [self.syncProgressIndicator setHidden:YES];
  [self.syncProgressIndicator stopAnimation:self];
}

- (void)commit
{
  [self.syncProgressIndicator setHidden:NO];
  [self.syncProgressIndicator startAnimation:self];

  // Super does some extra view drawing..
  [super commit];

  if (self.commitAutoSyncButton.state == NSOffState) {
    [self partialAdd];
  }
  else {
    [self addFiles];
  }

  [self commitFiles];

  // Update unsynced commits prior to pushing (even if we aren't)
  [self updateUnsyncedCommits];
  self.unsyncedcommitsList.string = [self.unsyncedCommits componentsJoinedByString:@"\n"];

  // Super does some extra view drawing..
  [super commitDidFinish];
  
  if (self.commitAutoSyncButton.state == NSOnState) {
    [self pushToRemote];
  }
  
  // Update unsynced commits after pushing to ensure they actually went up as expected.
  [self updateUnsyncedCommits];
  self.unsyncedcommitsList.string = [self.unsyncedCommits componentsJoinedByString:@"\n"];
  
  self.filesWithStatus = [self fetchFilesWithStatus];
  [self.filesOutlineView reloadData];
  
  [self.commitTextView setString:@""];
  
  [self.syncProgressIndicator setHidden:YES];
  [self.syncProgressIndicator stopAnimation:self];
}

- (void)partialAdd
{
  NSLog(@"Current directory: %@",self.fileURL.path);
  
  NSMutableArray *filesList = [[NSMutableArray alloc] init];
  [self.filesWithStatus enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    KDocumentVersionedFile *versionedFile = (KDocumentVersionedFile *)obj;
    if (versionedFile.includeInCommit == YES) {
      [filesList addObject:versionedFile.fileUrl.path];
    }
  }];
  
  NSLog(@"filesList: %@",filesList);
  [filesList insertObject:@"add" atIndex:0];
  
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = filesList;
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

- (void)discardChangesInFile:(KDocumentVersionedFile *)versionedFile
{
    if (versionedFile.status == KFileStatusUntracked) {
        // I didn't want to write deletion code.. so delete the file yourself..
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[versionedFile.fileUrl]];

        return;
    }

    NSLog(@"Current directory: %@",self.fileURL.path);

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/git";
    task.arguments = @[@"checkout", versionedFile.fileUrl.path];
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

- (void)updateCurrentBranch
{
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"rev-parse", @"--symbolic-full-name",@"--abbrev-ref",@"HEAD"];
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
  self.currentBranchString = outputString;
}

- (void)updateUnsyncedCommits
{
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"log", @"origin/master..HEAD"];
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
  
  NSLog(@"output String: %@",outputString);
  
  NSArray *commitMessages = [outputString componentsSeparatedByString:@"\n\ncommit"];
  self.unsyncedCommits = [NSArray array];
  for (NSString *message in commitMessages) {
    NSMutableArray *linesMutable = [[message componentsSeparatedByString:@"\n"] mutableCopy];
      NSLog(@"linesMutable: %@",linesMutable);
    if ([linesMutable count] >= 5 ) {
        [linesMutable removeObjectAtIndex:0];
        [linesMutable removeObjectAtIndex:0];
        [linesMutable removeObjectAtIndex:0];
        [linesMutable removeObjectAtIndex:0];
      
      NSString *commitString = [linesMutable objectAtIndex:0];
      NSMutableString *mStr = [commitString mutableCopy];
      CFStringTrimWhitespace((CFMutableStringRef)mStr);
      
      commitString = [mStr copy];
      self.unsyncedCommits = [self.unsyncedCommits arrayByAddingObject:commitString];
    }
  }
  
  NSLog(@"unsynced commits: %@",self.unsyncedCommits);
  
}

@end
