//
//  KGitDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KGitDocument.h"
#import "KDocumentVersionedFile.h"

@implementation KGitDocument

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

- (void)commit
{
  [self addFiles];
  [self commitFiles];
  [self pushFiles];
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
    return;
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
    return;
  }
  
  NSLog(@"outputString: %@",outputString);
  
}

- (void)pushFiles
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
    return;
  }
  
  NSLog(@"outputString: %@",outputString);
  
}

@end
