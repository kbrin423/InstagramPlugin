#import <Cordova/CDV.h>
#import "CDVInstagramPlugin.h"
#import <Photos/Photos.h>

static NSString *InstagramId = @"com.burbn.instagram";
static NSString *localId;

@implementation CDVInstagramPlugin

@synthesize toInstagram;
@synthesize callbackId;
@synthesize interactionController;

- (void) receiveSaveImageNotification:(NSNotification *) notification{
    if ([[notification name] isEqualToString:@"ImageSaved"]){
        NSURL *instagramURL = [NSURL URLWithString:[NSString stringWithFormat:@"instagram://library?AssetPath=%@", localId]];
        [[UIApplication sharedApplication] openURL:instagramURL];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)isInstalled:(CDVInvokedUrlCommand*)command {
    self.callbackId = command.callbackId;
    CDVPluginResult *result;
    
    NSURL *instagramURL = [NSURL URLWithString:@"instagram://app"];
    if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
    }
}

void addImageToCameraRoll(UIImage *image) {
    NSString *albumName = @"Swello Instagram Album";

    void (^saveBlock)(PHAssetCollection *assetCollection) = ^void(PHAssetCollection *assetCollection) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetChangeRequest *assetChangeRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            PHAssetCollectionChangeRequest *assetCollectionChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
            [assetCollectionChangeRequest addAssets:@[[assetChangeRequest placeholderForCreatedAsset]]];
            localId = [[assetChangeRequest placeholderForCreatedAsset] localIdentifier];

        } completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"Error creating asset: %@", error);
            } else {
                [[NSNotificationCenter defaultCenter]
                postNotificationName:@"ImageSaved"
                object:nil];
            }
        }];
    };

    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.predicate = [NSPredicate predicateWithFormat:@"localizedTitle = %@", albumName];
    PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:fetchOptions];
    if (fetchResult.count > 0) {
        saveBlock(fetchResult.firstObject);
    } else {
        __block PHObjectPlaceholder *albumPlaceholder;
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *changeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
            albumPlaceholder = changeRequest.placeholderForCreatedAssetCollection;

        } completionHandler:^(BOOL success, NSError *error) {
            if (success) {
                PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[albumPlaceholder.localIdentifier] options:nil];
                
                if (fetchResult.count > 0) {
                    saveBlock(fetchResult.firstObject);
                }
            } else {
                NSLog(@"Error creating album: %@", error);
            }
        }];
    }
}

- (void)share:(CDVInvokedUrlCommand*)command {
    self.callbackId = command.callbackId;
    self.toInstagram = FALSE;
    NSString  *objectAtIndex0 = [command argumentAtIndex:0];
    NSString *caption = [command argumentAtIndex:1];
    
    CDVPluginResult *result;
    
    NSURL *instagramURL = [NSURL URLWithString:@"instagram://app"];
    if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
        
        NSLog(@"open in instagram");
        
        NSData *imageObj = [[NSData alloc] initWithBase64EncodedString:objectAtIndex0 options:0];
        NSString *tmpDir = NSTemporaryDirectory();
        NSString *path = [tmpDir stringByAppendingPathComponent:@"instagram.ig"];
        UIImage *image = [UIImage imageWithData:imageObj];
        
        // Convert UIImage object into NSData (a wrapper for a stream of bytes) formatted according to JPG spec
        NSData *imageData = UIImageJPEGRepresentation(image, 1);
        [imageData writeToFile:path atomically:true];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(receiveSaveImageNotification:)
            name:@"ImageSaved"
            object:nil];
        
        self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:path]];
        if (caption) {
            self.interactionController .annotation = @{@"InstagramCaption" : caption};
        }
        
        addImageToCameraRoll(image);
        
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:1];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
    }
}

- (void)shareAsset:(CDVInvokedUrlCommand*)command {
    self.callbackId = command.callbackId;
    NSString    *localIdentifier = [command argumentAtIndex:0];
    
    CDVPluginResult *result;
    
    NSURL *instagramURL = [NSURL URLWithString:@"instagram://app"];
    if ([[UIApplication sharedApplication] canOpenURL:instagramURL]) {
        NSLog(@"open asset in instagram");
        
		NSString *localIdentifierEscaped = [localIdentifier stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
		NSURL *instagramShareURL   = [NSURL URLWithString:[NSString stringWithFormat:@"instagram://library?LocalIdentifier=%@", localIdentifierEscaped]];
		
		[[UIApplication sharedApplication] openURL:instagramShareURL];

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
        
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:1];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
    }
}

- (void) documentInteractionController: (UIDocumentInteractionController *) controller willBeginSendingToApplication: (NSString *) application {
    if ([application isEqualToString:InstagramId]) {
        self.toInstagram = TRUE;
    }
}

- (void) documentInteractionControllerDidDismissOpenInMenu: (UIDocumentInteractionController *) controller {
    CDVPluginResult *result;
    
    if (self.toInstagram) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:2];
        [self.commandDelegate sendPluginResult:result callbackId: self.callbackId];
    }
}

@end
