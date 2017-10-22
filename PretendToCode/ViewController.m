//
//  ViewController.m
//  PretendToCode
//
//  Created by Huanming Hu  on 2017/10/21.
//  Copyright © 2017年 huhuanming. All rights reserved.
//

#define K_KEYCHAIN_SERVICE_NAME @"K_PretendToCode"
#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadFromKeyChian];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)clearAllRepo:(id)sender {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSArray *fileNames = [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];
    for (NSString *fileName in fileNames) {
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
        [fileManager removeItemAtPath:filePath error:nil];
    }
}

- (IBAction)onUrlEditingEnd:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.nameTextFiled becomeFirstResponder];
    });
}

- (IBAction)onNameEditingEnd:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.passwordTextFiled becomeFirstResponder];
    });
}

- (IBAction)onPasswordEditingEnd:(id)sender {
    NSString *accountName = self.nameTextFiled.text;
    NSString *accountPassword = self.passwordTextFiled.text;
    [self saveToKeyChain];
    
    NSString* url = self.urlTextField.text;
    GTRepository* repo = nil;
    NSError* error = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL* appDocsDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL* localURL = [NSURL URLWithString:url.lastPathComponent relativeToURL:appDocsDir];
    
    
    if (![fileManager fileExistsAtPath:localURL.path isDirectory:nil]) {
        repo = [GTRepository cloneFromURL:[NSURL URLWithString:url] toWorkingDirectory:localURL options:@{GTRepositoryCloneOptionsTransportFlags: @YES} error:&error transferProgressBlock:nil];
        if (error) {
            NSLog(@"%@", error);
        }
    } else {
        repo = [GTRepository repositoryWithURL:localURL error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
        
    }
    GTReference* headReference = [repo headReferenceWithError:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    GTCommit* headCommit = [repo lookUpObjectByOID:headReference.OID error:&error];
    NSLog(@"%@", headCommit.message);
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    
    
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    
    GTEnumerator *commitEnum = [[GTEnumerator alloc] initWithRepository:repo error:nil];
    [commitEnum pushSHA:[headReference targetOID].SHA error:nil];
    
    GTCommit *parentCommit = [commitEnum nextObject];
    
    NSInteger days = 0;
   
    if([parentCommit.message rangeOfString:@"Pretent To Code: day"].location != NSNotFound) {
        days = [[[parentCommit.message componentsSeparatedByString:@" "] lastObject] intValue] + 1;
    } else {
        GTCommit *lastPretentToCodeCommit;
        while(lastPretentToCodeCommit = [commitEnum nextObject]) {
            if([lastPretentToCodeCommit.message rangeOfString:@"Pretent To Code: day"].location != NSNotFound) {
                days = [[[lastPretentToCodeCommit.message componentsSeparatedByString:@" "] lastObject] intValue] + 1;
                break;
            }
        }
    }
    
    
    GTTreeBuilder *builder = [[GTTreeBuilder alloc] initWithTree:headCommit.tree repository:repo error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    
    [builder addEntryWithData:[[NSString stringWithFormat:@"%ld", days] dataUsingEncoding:NSUTF8StringEncoding] fileName:@".pretent_to_code" fileMode:GTFileModeBlob error:&error];

    GTTree *tree = [builder writeTree:&error];
    
    GTSignature *committer = [[GTSignature alloc] initWithName:@"huhuanming" email:@"workboring@gmail.com" time:[NSDate date]];
    [repo createCommitWithTree:tree message:[NSString stringWithFormat:@"Pretent To Code: day %ld", days] author:committer committer:committer parents:@[ parentCommit ] updatingReferenceNamed:headReference.resolvedReference.name error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }
    
    GTBranch *branch = [GTBranch branchWithReference:headReference repository:repo];
    GTConfiguration *configuration = [repo configurationWithError:&error];
    GTRemote *remote = configuration.remotes[0];
    GTCredentialProvider *provider = [GTCredentialProvider providerWithBlock:^GTCredential * _Nullable(GTCredentialType type, NSString * _Nonnull URL, NSString * _Nonnull userName) {
        return [GTCredential credentialWithUserName:accountName password:accountPassword error:nil];
    }];
    [repo pushBranch:branch toRemote:remote withOptions:@{@"GTRepositoryRemoteOptionsCredentialProvider": provider} error:&error progress:nil];
    
    if (error) {
        NSLog(@"%@", error.localizedDescription);
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"ERROR" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle:@"SUCCESS" message:[NSString stringWithFormat:@"Pretent To Code: day %ld", days] preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void)loadFromKeyChian {
    id ret = nil;
    NSMutableDictionary *keychainQuery = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          (id)kSecClassGenericPassword,(id)kSecClass,
                                          K_KEYCHAIN_SERVICE_NAME, (id)kSecAttrService,
                                          K_KEYCHAIN_SERVICE_NAME, (id)kSecAttrAccount,
                                          (id)kSecAttrAccessibleAfterFirstUnlock,(id)kSecAttrAccessible,
                                          nil];
    [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    CFDataRef keyData = NULL;
    if (SecItemCopyMatching((CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        @try {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
            if(ret) {
                if(ret[@"repo"]) {
                    [self.urlTextField setText:ret[@"repo"]];
                }
                if(ret[@"account"]) {
                    [self.nameTextFiled setText:ret[@"account"]];
                }
                if(ret[@"password"]) {
                    [self.passwordTextFiled setText:ret[@"password"]];
                }
            }
        } @catch (NSException *e) {
            NSLog(@"Unarchive of %@ failed: %@", K_KEYCHAIN_SERVICE_NAME, e);
        } @finally {
        }
    }
    if (keyData) {
        CFRelease(keyData);
    }
}

- (void)saveToKeyChain {
    NSMutableDictionary *keychainQuery = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          (id)kSecClassGenericPassword,(id)kSecClass,
                                          K_KEYCHAIN_SERVICE_NAME, (id)kSecAttrService,
                                          K_KEYCHAIN_SERVICE_NAME, (id)kSecAttrAccount,
                                          (id)kSecAttrAccessibleAfterFirstUnlock,(id)kSecAttrAccessible,
                                          nil];
    SecItemDelete((CFDictionaryRef)keychainQuery);
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:@{@"repo": self.urlTextField.text, @"account": self.nameTextFiled.text, @"password": self.passwordTextFiled.text}] forKey:(id)kSecValueData];
    SecItemAdd((CFDictionaryRef)keychainQuery, NULL);
}

@end
