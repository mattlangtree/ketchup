//
//  KGitDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KGitDocument.h"

@implementation KGitDocument

- (void)commit
{
  [self addFiles];
  [self commitFiles];
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


@end
