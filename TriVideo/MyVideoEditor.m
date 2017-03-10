//
//  MyVideoEditor.m
//  TriVideo
//
//  Created by 颜为晨 on 09/03/2017.
//  Copyright © 2017 s2mh. All rights reserved.
//

#import "MyVideoEditor.h"
#import <UIKit/UIKit.h>

@interface MyVideoEditor ()

@property (nonatomic, readwrite, strong) AVMutableComposition *composition;
@property (nonatomic, readwrite, strong) AVMutableVideoComposition *videoComposition;

@end

@implementation MyVideoEditor

- (AVPlayerItem *)playerItem {
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
    playerItem.videoComposition = self.videoComposition;
    
    return playerItem;
}

- (void)edit {
    if (!self.clips.count) {
        return;
    }
    CGSize videoSize = CGSizeMake(self.videoWidth, self.videoHeight);
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    composition.naturalSize = videoSize;
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    if (videoComposition) {
        videoComposition.frameDuration = CMTimeMake(1, 30);
        videoComposition.renderSize = videoSize;
    }
    
    [self buildComposition:composition videoComposition:videoComposition];
    
    self.composition = composition;
    self.videoComposition = videoComposition;
}

- (void)buildComposition:(AVMutableComposition *)composition videoComposition:(AVMutableVideoComposition *)videoComposition {
    
    NSUInteger count = self.clips.count;
    
    NSMutableArray<AVMutableCompositionTrack *> *compositionVideoTracks = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; ++i) {
        AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                    preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionVideoTracks addObject:compositionVideoTrack];
    }
    
    CMTimeRange targetTimeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(3, 1));
    NSMutableArray<NSValue *> *naturalSizeValues = [NSMutableArray arrayWithCapacity:count];

    
    [compositionVideoTracks enumerateObjectsUsingBlock:^(AVMutableCompositionTrack * _Nonnull compositionVideoTrack, NSUInteger idx, BOOL * _Nonnull stop) {
        AVAsset *asset = [self.clips objectAtIndex:idx];
        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        
        [compositionVideoTrack insertTimeRange:targetTimeRange
                                       ofTrack:clipVideoTrack
                                        atTime:kCMTimeZero
                                         error:nil];
        [naturalSizeValues addObject:[NSValue valueWithCGSize:clipVideoTrack.naturalSize]];
    }];
    
    AVMutableVideoCompositionInstruction *compositionInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    compositionInstruction.timeRange = targetTimeRange;
    
    NSMutableArray<AVMutableVideoCompositionLayerInstruction *> *layerInstructions = [NSMutableArray arrayWithCapacity:count];
    
    CGFloat clipX = 0.0f;
    CGFloat clipY = 0.0f;
    CGFloat clipWidth  = self.videoWidth  / (count - 1);
    CGFloat clipHeight = self.videoHeight / 2;
    
    for (NSInteger i = 0; i < count; ++i) {
        CGRect clipFrame = CGRectMake(clipX,
                                      clipY,
                                      ((i == 0) ? self.videoWidth : clipWidth),
                                      clipHeight);
        
        AVMutableCompositionTrack *compositionVideoTrack = compositionVideoTracks[i];
        AVMutableVideoCompositionLayerInstruction *compositionLayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
        
        CGSize naturalSize = compositionVideoTrack.naturalSize;
        CGAffineTransform portraitTransform = CGAffineTransformMake(0, 1, -1, 0, naturalSize.height, 0);
        CGRect portraitFrame = (CGRect){CGPointZero, naturalSize.height, naturalSize.width};
        CGAffineTransform translatedAndScaledTransform = [self makeTransformFromRect:portraitFrame toRect:clipFrame];
        CGAffineTransform clipTransform = CGAffineTransformConcat(portraitTransform, translatedAndScaledTransform);
        
        [compositionLayerInstruction setTransform:clipTransform atTime:kCMTimeZero];
        [layerInstructions addObject:compositionLayerInstruction];
        
        if (i == 0) {
            clipY += clipHeight;
        } else {
            clipX += clipWidth;
        }
    }
    compositionInstruction.layerInstructions = layerInstructions;
    videoComposition.instructions = @[compositionInstruction];
}

- (CGAffineTransform)makeTransformFromRect:(CGRect)fromRect toRect:(CGRect)toRect {    
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(toRect.size.width  / fromRect.size.width,
                                                                  toRect.size.height / fromRect.size.height);
    CGRect scaledFrame = CGRectApplyAffineTransform(fromRect, scaleTransform);
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(CGRectGetMinX(toRect) - CGRectGetMinX(scaledFrame),
                                                                            CGRectGetMinY(toRect) - CGRectGetMinY(scaledFrame));
    return CGAffineTransformConcat(scaleTransform, translateTransform);
    
}

@end
