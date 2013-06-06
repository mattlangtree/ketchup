//
//  KDocumentController.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocumentController.h"

@implementation KDocumentController

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)types
{
  openPanel.canChooseDirectories = YES;
  return [super runModalOpenPanel:openPanel forTypes:types];
}

- (Class)documentClassForType:(NSString *)typeName
{
  if ([typeName isEqualToString:@"Git Repository"])
    return NSClassFromString(@"KGitDocument");
  
  if ([typeName isEqualToString:@"SVN Checkout"])
    return NSClassFromString(@"KSVNDocument");
  
  [NSException raise:@"error" format:@"Unknown document type: %@", typeName];
  
  return NULL;
}

- (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)outError
{
  // is it a git repository, or an svn checkout?
  NSURL *gitUrl = [url URLByAppendingPathComponent:@".git"];
  NSURL *svnUrl = [url URLByAppendingPathComponent:@".svn"];
  BOOL isDirectory;
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:gitUrl.path isDirectory:&isDirectory]) {
    if (isDirectory) {
      return @"Git Repository";
    }
  }
  if ([[NSFileManager defaultManager] fileExistsAtPath:svnUrl.path isDirectory:&isDirectory]) {
    if (isDirectory) {
      return @"SVN Checkout";
    }
  }
  
  // parent class will robably fail with an error, but give it a chance
  NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : @"There is no git repository or svn checkout at the specified path", NSURLErrorKey: svnUrl };
  
  *outError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:0 userInfo:errorDictionary];
  
  return nil;
}

@end