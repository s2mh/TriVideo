//
//  ViewController.m
//  TriVideo
//
//  Created by 颜为晨 on 06/03/2017.
//  Copyright © 2017 s2mh. All rights reserved.
//

#import "ViewController.h"

#import "QBImagePickerController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVKit/AVKit.h>

@interface ViewController () <QBImagePickerControllerDelegate>
//@interface ViewController () <QBImagePickerControllerDelegate, AVPlayerViewControllerDelegate>

@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property (nonatomic, strong) NSMutableArray<AVPlayerItem *> *playerItems;
@property (nonatomic, strong) NSMutableArray<AVAsset *> *assetItems;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    [super touchesEnded:touches withEvent:event];
//    
//    QBImagePickerController *ipc = [QBImagePickerController new];
//    ipc.delegate = self;
//    ipc.mediaType = QBImagePickerMediaTypeVideo;
//    ipc.allowsMultipleSelection = YES;
//    ipc.showsNumberOfSelectedAssets = YES;
//    ipc.maximumNumberOfSelection = 3;
////    ipc.minimumNumberOfSelection = 3;
//    
//    [self presentViewController:ipc animated:YES completion:^{}];
//}


- (IBAction)selectVideos:(id)sender {
    QBImagePickerController *ipc = [QBImagePickerController new];
    ipc.delegate = self;
    ipc.mediaType = QBImagePickerMediaTypeVideo;
    ipc.allowsMultipleSelection = YES;
    ipc.showsNumberOfSelectedAssets = YES;
    ipc.maximumNumberOfSelection = 3;
    //    ipc.minimumNumberOfSelection = 3;
    
    [self presentViewController:ipc animated:YES completion:^{}];
}


#pragma mark - QBImagePickerControllerDelegate

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets
{
    [imagePickerController dismissViewControllerAnimated:YES completion:nil];
    if (!assets.count) {
        return;
    } else {
        [self.playerItems removeAllObjects];
        [self.assetItems removeAllObjects];
    }
    
//    [self handleAssetAtIndex:0 inArray:assets];
    [self mergeAssetAtIndex:0 inArray:assets];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [imagePickerController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Private

- (void)playVideoWithURL:(NSURL *)url {
    AVPlayerViewController *avpvc = [[AVPlayerViewController alloc] init];
    avpvc.player = [AVPlayer playerWithURL:url];
    avpvc.allowsPictureInPicturePlayback = YES;
    [self presentViewController:avpvc animated:YES completion:nil];
}

- (void)playVideoWithQueuePlayer:(AVQueuePlayer *)queuePlayer {
    AVPlayerViewController *avpvc = [[AVPlayerViewController alloc] init];
    avpvc.player = queuePlayer;
    avpvc.allowsPictureInPicturePlayback = YES;
    [self presentViewController:avpvc animated:YES completion:nil];
}

- (void)handleAssetAtIndex:(NSUInteger)index inArray:(NSArray *)assets {
    __weak typeof(self) weakSelf = self;
    if (index < assets.count) {
        PHAsset *asset = assets[index];
        [self.imageManager requestPlayerItemForVideo:asset
                                             options:nil
                                       resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
                                           if ([playerItem isKindOfClass:[AVPlayerItem class]]) {
                                               [weakSelf.playerItems addObject:playerItem];
                                               [weakSelf handleAssetAtIndex:(index + 1) inArray:assets];
                                           } else {
                                               NSLog(@"invalid video %ld", index);
                                           }
                                       }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playVideoWithQueuePlayer:[AVQueuePlayer queuePlayerWithItems:self.playerItems]];
        });
    }
}


- (void)mergeAssetAtIndex:(NSUInteger)index inArray:(NSArray *)assets {
    __weak typeof(self) weakSelf = self;
    if (index < assets.count) {
        PHAsset *asset = assets[index];
        [self.imageManager requestAVAssetForVideo:asset
                                             options:nil
                                       resultHandler:^(AVAsset *__nullable asset, AVAudioMix *__nullable audioMix, NSDictionary *__nullable info) {
                                           if ([asset isKindOfClass:[AVAsset class]]) {
                                               [weakSelf.assetItems addObject:asset];
                                               [weakSelf mergeAssetAtIndex:(index + 1) inArray:assets];
                                           } else {
                                               NSLog(@"invalid video %ld", index);
                                           }
                                       }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self mergeVideoInArray:self.assetItems];
        });
    }
}

- (void)mergeVideoInArray:(NSArray<AVAsset *> *)assets {
    
//     AVAsset *firstAsset = ;
//     AVAsset *secondAsset;
//     AVAsset *audioAsset;
    
    
    // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    // 2 - Video track
    AVMutableCompositionTrack *track = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                   preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTime startTime = kCMTimeZero;
    for (AVAsset *asset in assets) {
        [track insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                       ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
        startTime = CMTimeAdd(startTime, asset.duration);
    }
    
//    // 3 - Audio track
//    if (audioAsset!=nil){
//        AVMutableCompositionTrack *AudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
//                                                                            preferredTrackID:kCMPersistentTrackID_Invalid];
//        [AudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, secondAsset.duration))
//                            ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
//    }
    // 4 - Get path
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSLog(@"documentsDirectory %@", documentsDirectory);
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"mergeVideo-%d.mov",arc4random() % 1000]];
    NSURL *url = [NSURL fileURLWithPath:myPathDocs];
    // 5 - Create exporter
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL=url;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"status dd %ld *** %@", (long)exporter.status, exporter.error);
            [self exportDidFinish:exporter];
        });
    }];
    NSLog(@"status aa %ld *** %@", (long)exporter.status, exporter.error);
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
                [self playVideoWithURL:outputURL];
            } else {
                NSLog(@"Failed to add asset: %@", error);
            }
        }];
    }
}

#pragma mark - Accessor

- (PHCachingImageManager *)imageManager{
    if (!_imageManager) {
        _imageManager = [PHCachingImageManager new];
    }
    return _imageManager;
}

- (NSMutableArray<AVPlayerItem *> *)playerItems {
    if (!_playerItems) {
        _playerItems = [NSMutableArray array];
    }
    return  _playerItems;
}

- (NSMutableArray<AVAsset *> *)assetItems {
    if (!_assetItems) {
        _assetItems = [NSMutableArray array];
    }
    return  _assetItems;
}

@end
