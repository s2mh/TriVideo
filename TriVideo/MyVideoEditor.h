//
//  MyVideoEditor.h
//  TriVideo
//
//  Created by 颜为晨 on 09/03/2017.
//  Copyright © 2017 s2mh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface MyVideoEditor : NSObject

@property (nonatomic, copy) NSArray<AVAsset *> *clips;

@property (nonatomic, assign) CGFloat videoWidth;
@property (nonatomic, assign) CGFloat videoHeight;
@property (nonatomic, assign) CMTime videoTimeLength;

@property (nonatomic, readonly, strong) AVMutableComposition *composition;
@property (nonatomic, readonly, strong) AVMutableVideoComposition *videoComposition;
@property (nonatomic, readonly, strong) AVPlayerItem *playerItem;

- (void)edit;

@end
