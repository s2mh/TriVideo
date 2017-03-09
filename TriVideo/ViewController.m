//
//  ViewController.m
//  TriVideo
//
//  Created by 颜为晨 on 06/03/2017.
//  Copyright © 2017 s2mh. All rights reserved.
//

#import <AVKit/AVKit.h>

#import "ViewController.h"
#import "MyVideoEditor.h"

#import "QBImagePickerController.h"


@interface ViewController () <QBImagePickerControllerDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, strong) NSMutableArray<AVAsset *> *assets;

@property (nonatomic, strong) MyVideoEditor *editor;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.tintColor = [UIColor greenColor];
}


- (IBAction)selectVideos:(id)sender {
    QBImagePickerController *ipc = [QBImagePickerController new];
    ipc.delegate = self;
    ipc.mediaType = QBImagePickerMediaTypeVideo;
    ipc.allowsMultipleSelection = YES;
    ipc.showsNumberOfSelectedAssets = YES;
    ipc.maximumNumberOfSelection = 3;
    ipc.minimumNumberOfSelection = 3;
    
    [self presentViewController:ipc animated:YES completion:^{}];
}

- (IBAction)playEditedVideo:(id)sender {
    if (!self.assets.count) {
        [[[UIAlertView alloc] initWithTitle:@"Please select 3 videos!"
                                    message:nil
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    } else {
        [self playVideo];
    }
}

#pragma mark - QBImagePickerControllerDelegate

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets
{
    [imagePickerController dismissViewControllerAnimated:YES completion:nil];
    if (!assets.count) {
        return;
    } else {
        [self.assets removeAllObjects];
    }
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    [assets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_enter(dispatchGroup);
        PHAsset *asset = assets[idx];
        [self handleAsset:asset inGroup:dispatchGroup];
    }];
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^(){
        [self editVideo];
    });
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [imagePickerController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [self playVideo];
    }
}

#pragma mark - Private

- (void)handleAsset:(PHAsset *)asset inGroup:(dispatch_group_t)group {
    __weak typeof(self) weakSelf = self;
    [self.imageManager requestAVAssetForVideo:asset
                                      options:nil
                                resultHandler:^(AVAsset *__nullable asset, AVAudioMix *__nullable audioMix, NSDictionary *__nullable info) {
                                    dispatch_group_leave(group);
                                    
                                    if ([asset isKindOfClass:[AVAsset class]]) {
                                        [weakSelf.assets addObject:asset];
                                    } else {
                                        NSLog(@"invalid video %ld", (unsigned long)index);
                                    }
                                }];
}

- (void)exportVideo {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"MyEditedVideo-%d.mov",arc4random() % 1000]];
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];
    AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:self.editor.playerItem.asset
                                                                       presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = url;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportDidFinish:exporter];
        });
    }];
}


- (void)exportDidFinish:(AVAssetExportSession *)session {
    if (session.status == AVAssetExportSessionStatusCompleted) {
        NSURL *outputURL = session.outputURL;
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHFetchResult<PHAssetCollection *> *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                                                  subtype:PHAssetCollectionSubtypeSmartAlbumVideos
                                                                                                  options:nil];
            PHAssetCollection *album = [albums firstObject];
            // Request creating an asset from the image.
            PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputURL];
            // Request editing the album.
            PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
            // Get a placeholder for the new asset and add it to the album editing request.
            PHObjectPlaceholder *assetPlaceholder = [createAssetRequest placeholderForCreatedAsset];
            [albumChangeRequest addAssets:@[assetPlaceholder]];
        } completionHandler:^(BOOL success, NSError *error) {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:@"A TriVideo has been created and saved!"
                                                message:nil
                                               delegate:self
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:@"Open", nil] show];
                });
            } else {
                NSLog(@"Failed to add asset: %@", error);
            }
        }];
    }
}

- (void)editVideo {
    [self.editor edit];
    [self exportVideo];
}

- (void)playVideo {
    AVPlayerItem *editedPlayerItem = [self.editor playerItem];
    if (!editedPlayerItem) {
        return;
    }
    
    AVPlayerViewController *avpvc = [[AVPlayerViewController alloc] init];
    avpvc.player = [AVPlayer playerWithPlayerItem:editedPlayerItem];
    avpvc.allowsPictureInPicturePlayback = YES;
    [self presentViewController:avpvc animated:YES completion:nil];
}

#pragma mark - Accessor

- (PHCachingImageManager *)imageManager{
    if (!_imageManager) {
        _imageManager = [PHCachingImageManager new];
    }
    return _imageManager;
}

- (NSMutableArray<AVAsset *> *)assets {
    if (!_assets) {
        _assets = [NSMutableArray array];
    }
    return  _assets;
}

- (MyVideoEditor *)editor {
    if (!_editor) {
        _editor = [[MyVideoEditor alloc] init];
        _editor.clips = self.assets;
        _editor.videoHeight = 300.0f;
        _editor.videoWidth = 400.0f;
    }
    return _editor;
}

@end
