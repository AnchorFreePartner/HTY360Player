//
//  HTY360PlayerVC.m
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

#import "HTY360PlayerVC.h"
#import "HTYGLKVC.h"
#import "HTYSlider.h"

#define ONE_FRAME_DURATION 0.033
#define HIDE_CONTROL_DELAY 3.0
#define DEFAULT_VIEW_ALPHA 0.6

NSString * const kTracksKey = @"tracks";
NSString * const kPlayableKey = @"playable";
NSString * const kRateKey = @"rate";
NSString * const kCurrentItemKey = @"currentItem";
NSString * const kStatusKey = @"status";

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerItemStatusContext = &AVPlayerItemStatusContext;

@interface HTY360PlayerVC ()

@property (strong, nonatomic) IBOutlet UIView *playerControlBackgroundView;
@property (strong, nonatomic) IBOutlet UIButton *playButton;
@property (strong, nonatomic) IBOutlet HTYSlider *progressSlider;
@property (strong, nonatomic) IBOutlet UIButton *backButton;
@property (strong, nonatomic) IBOutlet UIButton *gyroButton;
@property (strong, nonatomic) HTYGLKVC *glkViewController;
@property (strong, nonatomic) AVPlayerItemVideoOutput* videoOutput;
@property (strong, nonatomic) AVPlayer* player;
@property (strong, nonatomic) AVPlayerItem* playerItem;
@property (strong, nonatomic) id timeObserver;
@property (assign, nonatomic) CGFloat mRestoreAfterScrubbingRate;
@property (assign, nonatomic) BOOL seekToZeroBeforePlay;
@property (assign, nonatomic) BOOL rateEventAppear;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *bandwithLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bandwithLeading;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@property (strong, nonatomic) NSTimer *bufferTimer;

@end

@implementation HTY360PlayerVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil url:(NSURL*)url {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setVideoURL:url];
    }
    return self;
}


- (void)viewDidLoad {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    self.autoPlay = YES;
    self.loopVideo = YES;
    self.rateEventAppear = NO;
    
    [self setupVideoPlaybackForURL:_videoURL];
    [self configureGLKView];
    [self configurePlayButton];
    [self configureProgressSlider];
    [self configureControleBackgroundView];
    [self configureBackButton];
    [self configureGyroButton];
    
#if SHOW_DEBUG_LABEL
    self.debugView.hidden = NO;
#endif
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self pause];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self updatePlayButton];
    [self.player seekToTime:[self.player currentTime]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.playerControlBackgroundView = nil;
    self.playButton = nil;
    self.progressSlider = nil;
    self.backButton = nil;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    @try {
        [self removePlayerTimeObserver];
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];
        [self.playerItem removeOutput:self.videoOutput];
        [self.player removeObserver:self forKeyPath:kCurrentItemKey];
        [self.player removeObserver:self forKeyPath:kRateKey];
    } @catch(id anException) {
        //do nothing
    }
    
    self.videoOutput = nil;
    self.playerItem = nil;
    self.player = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self updatePlayButton];
}

#pragma mark - video communication

- (CVPixelBufferRef)retrievePixelBufferToDraw {
    if (self.videoOutput == nil) {
        return nil;
    }
    
    CMTime currentTime = [self.playerItem currentTime];
    return [self.videoOutput copyPixelBufferForItemTime:currentTime itemTimeForDisplay:nil];
}

#pragma mark - video setting

- (void)setupVideoPlaybackForURL:(NSURL*)url {
    NSDictionary *pixelBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixelBuffAttributes];
    
    self.player = [[AVPlayer alloc] init];
    
    // Do not take mute button into account
    NSError *error = nil;
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                                          error:&error];
    if (!success) {
        NSLog(@"Could not use AVAudioSessionCategoryPlayback", nil);
    }
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];    
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:[[asset URL] path]]) {
        //NSLog(@"file does not exist");
    }
    
    NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];    
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        NSLog(@"loadValuesAsynchronouslyForKeys", nil);
        dispatch_async( dispatch_get_main_queue(),
                       ^{
                           /* Make sure that the value of each key has loaded successfully. */
                           for (NSString *thisKey in requestedKeys) {
                               NSError *error = nil;
                               AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
                               if (keyStatus == AVKeyValueStatusFailed) {
                                   [self assetFailedToPrepareForPlayback:error];
                                   return;
                               }
                           }
                           
                           NSError* error = nil;
                           AVKeyValueStatus status = [asset statusOfValueForKey:kTracksKey error:&error];
                           if (status == AVKeyValueStatusLoaded) {
                               self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
                               [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
                               
                               /* When the player item has played to its end time we'll toggle
                                the movie controller Pause button to be the Play button */
                               [[NSNotificationCenter defaultCenter] addObserver:self
                                                                        selector:@selector(playerItemDidReachEnd:)
                                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                                          object:self.playerItem];
                               
                               self.seekToZeroBeforePlay = NO;
                               
                               [self.playerItem addObserver:self
                                                 forKeyPath:kStatusKey
                                                    options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                                    context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
                               
                               [self.player addObserver:self
                                             forKeyPath:kCurrentItemKey
                                                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                                context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
                               
                               [self.player addObserver:self
                                             forKeyPath:kRateKey
                                                options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                                context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
                               
                               
                               [self initScrubberTimer];
                               [self initBufferTimer];
                               [self syncScrubber];
                           } else {
                               NSLog(@"%@ Failed to load the tracks.", self);
                           }
                       });
    }];
}

#pragma mark - rendering glk view management

- (void)configureGLKView {
    self.glkViewController = [[HTYGLKVC alloc] init];
    self.glkViewController.videoPlayerController = self;
    self.glkViewController.view.frame = self.view.bounds;
    [self.view insertSubview:self.glkViewController.view belowSubview:self.playerControlBackgroundView];
    [self addChildViewController:self.glkViewController];
    [self.glkViewController didMoveToParentViewController:self];
}

#pragma mark - play button management

- (void)configurePlayButton{
    self.playButton.backgroundColor = [UIColor clearColor];
    self.playButton.showsTouchWhenHighlighted = YES;
    
    [self disablePlayerButtons];
    [self updatePlayButton];
}

- (IBAction)playButtonTouched:(id)sender {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if ([self isPlaying]) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)updatePlayButton {
    [self.playButton setImage:[UIImage imageNamed:[self isPlaying] ? @"playback_pause" : @"playback_play"]
                     forState:UIControlStateNormal];
}

- (void)play {
    if ([self isPlaying])
        return;
    /* If we are at the end of the movie, we must seek to the beginning first
     before starting playback. */
    if (YES == self.seekToZeroBeforePlay) {
        self.seekToZeroBeforePlay = NO;
        [self.player seekToTime:kCMTimeZero];
    }
    
    self.playButton.selected = NO;
    [self.activityIndicator stopAnimating];
    [self updatePlayButton];
    [self.player play];
    
    [self scheduleHideControls];
}

- (void)pause {
    if (![self isPlaying])
        return;
    
    self.playButton.selected = YES;
    [self updatePlayButton];
    [self.player pause];
    
    [self scheduleHideControls];
}

#pragma mark - progress slider management

- (void)configureProgressSlider {
    [self.progressSlider setup];
}

#pragma mark - back and gyro button management

- (void)configureBackButton {
    self.backButton.backgroundColor = [UIColor clearColor];
    self.backButton.showsTouchWhenHighlighted = YES;
}

- (void)configureGyroButton {
    self.gyroButton.backgroundColor = [UIColor clearColor];
    self.gyroButton.showsTouchWhenHighlighted = YES;
}

#pragma mark - controls management

- (void)enablePlayerButtons {
    self.playButton.enabled = YES;
}

- (void)disablePlayerButtons {
    self.playButton.enabled = NO;
}

- (void)configureControleBackgroundView {
    self.playerControlBackgroundView.layer.cornerRadius = 8;
}

- (void)toggleControls {
    if(self.playerControlBackgroundView.hidden){
        [self showControlsFast];
    }else{
        [self hideControlsFast];
    }
    
    [self scheduleHideControls];
}

- (void)scheduleHideControls {
    if(!self.playerControlBackgroundView.hidden) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(hideControlsSlowly) withObject:nil afterDelay:HIDE_CONTROL_DELAY];
    }
}

- (void)hideControlsWithDuration:(NSTimeInterval)duration {
    self.playerControlBackgroundView.alpha = DEFAULT_VIEW_ALPHA;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^(void) {
                         self.playerControlBackgroundView.alpha = 0.0f;
                     }
                     completion:^(BOOL finished){
                         if(finished)
                             self.playerControlBackgroundView.hidden = YES;
                     }];
    
}

- (void)hideControlsFast {
    [self hideControlsWithDuration:0.2];
}

- (void)hideControlsSlowly {
    [self hideControlsWithDuration:1.0];
}

- (void)showControlsFast {
    self.playerControlBackgroundView.alpha = 0.0;
    self.playerControlBackgroundView.hidden = NO;
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^(void) {
                         self.playerControlBackgroundView.alpha = DEFAULT_VIEW_ALPHA;
                     }
                     completion:nil];
}

- (void)removeTimeObserverForPlayer {
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}

#pragma mark - slider progress management

- (void)initScrubberTimer {
    double interval = .1f;
    
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return;
    }
    
    NSLog(@"initScrubberTimer", nil);
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)) {
        CGFloat width = CGRectGetWidth([self.progressSlider bounds]);
        interval = 0.5f * duration / width;
    }
    
    __weak HTY360PlayerVC* weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)
                         /* If you pass NULL, the main queue is used. */
                                                                  queue:NULL
                                                             usingBlock:^(CMTime time) {
                                                                 [weakSelf syncScrubber];
                                                             }];
    
}

- (void)initBufferTimer {
    [self.bufferTimer invalidate];
    
    self.bufferTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                        target:self
                                                      selector:@selector(updateProgressUI)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (CMTime)availableDuration {
    NSValue *range = self.player.currentItem.loadedTimeRanges.firstObject;
    if (range != nil){
        return CMTimeRangeGetEnd(range.CMTimeRangeValue);
    }
    return kCMTimeZero;
}

- (void)updateProgressUI {
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return;
    }
    
    double availableDuration = CMTimeGetSeconds([self availableDuration]);
    double duration = CMTimeGetSeconds(playerDuration);
    
    if ( isfinite(availableDuration) && isfinite(duration) ) {
        float minValue = [self.progressSlider minimumValue];
        float maxValue = [self.progressSlider maximumValue];
        
//        NSLog(@"availableDuration %f, %f", availableDuration, duration);
        
        [self.progressSlider setBufferValue:(maxValue - minValue) * availableDuration / duration + minValue];
    }
    
    if ( availableDuration >= duration ) {
        [self.bufferTimer invalidate];
        self.bufferTimer = nil;
    }
    
    if ( self.activityIndicator.isAnimating ) {
        double time = CMTimeGetSeconds([self.player currentTime]);
        if ( availableDuration - time > 2 ) {
            [self play];
        }
    }
}

- (CMTime)playerItemDuration {
    if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
        /*
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3.
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching
         the value of the duration property of its associated AVAsset object. However,
         note that for HTTP Live Streaming Media the duration of a player item during
         any particular playback session may differ from the duration of its asset. For
         this reason a new key-value observable duration property has been defined on
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         */
        
        return ([self.playerItem duration]);
    }
    
    return (kCMTimeInvalid);
}

- (void) syncScrubber {
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        self.progressSlider.minimumValue = 0.0;
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)) {
        float minValue = [self.progressSlider minimumValue];
        float maxValue = [self.progressSlider maximumValue];
        double time = CMTimeGetSeconds([self.player currentTime]);
        
        [self.progressSlider setValue:(maxValue - minValue) * time / duration + minValue];
        
        [self updateTimeIndicatorWithTime:time andDuration:duration];
    }
    
    if ( self.showBandwith ) {
        [self updateDownloadSpeed];
    }
}

- (void) updateDownloadSpeed {
    NSArray *logEvents = self.playerItem.accessLog.events;
    AVPlayerItemAccessLogEvent *event = (AVPlayerItemAccessLogEvent *)[logEvents lastObject];
    double bitRate = event.observedBitrate;
    
    if ( bitRate > 0 ) {
        self.bandwithLabel.text = [self formattedSpeed:bitRate];
    }
    
    [self.bandwithLabel sizeToFit];
    
    CGRect trackRect = [self.progressSlider trackRectForBounds:self.progressSlider.bounds];
    CGRect thumbRect = [self.progressSlider thumbRectForBounds:self.progressSlider.bounds
                                                     trackRect:trackRect
                                                         value:self.progressSlider.value];
    
    CGFloat labelOrigin = CGRectGetMinX(self.progressSlider.frame) + CGRectGetMidX(thumbRect) - CGRectGetWidth(self.bandwithLabel.frame)/2;
    CGFloat leftX = MAX(CGRectGetMinX(self.progressSlider.frame), labelOrigin);
    leftX = MIN(CGRectGetMaxX(self.progressSlider.frame) - CGRectGetWidth(self.bandwithLabel.frame), leftX);
    self.bandwithLeading.constant = leftX;
}

- (void) updateTimeIndicatorWithTime:(double)time andDuration:(double)duration {
    NSDateComponentsFormatter * formatter = [NSDateComponentsFormatter new];
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorNone;
    formatter.allowedUnits = NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
    
    self.timeLabel.text = [NSString stringWithFormat:@"%@/%@", [formatter stringFromTimeInterval:time], 
                           [formatter stringFromTimeInterval:duration]];
}

- (NSString*)formattedSpeed:(double)rate {    
    double gbs = (double)rate/1024/1024/1024;
    double mbs = (double)rate/1024/1024;
    double kbs = (double)rate/1024;
    
    NSString *retVal = @"";
    
    if (gbs > 1) {
        retVal = [NSString stringWithFormat:@"%.2f Gbs", gbs];
    }
    else if (mbs > 1) {
        retVal = [NSString stringWithFormat:@"%.2f Mbs", mbs];
    }
    else if (kbs > 1) {
        retVal = [NSString stringWithFormat:@"%.2f Kbs", kbs];
    }
    else {
        retVal = [NSString stringWithFormat:@"%.2f bs", rate];
    }
    return retVal;
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender {
    self.mRestoreAfterScrubbingRate = [self.player rate];
    [self.player setRate:0.f];
    
    /* Remove previous timer. */
    [self removeTimeObserverForPlayer];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender {
    if ([sender isKindOfClass:[UISlider class]]) {
        UISlider* slider = sender;
        
        CMTime playerDuration = [self playerItemDuration];
        if (CMTIME_IS_INVALID(playerDuration)) {
            return;
        }
        
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration)) {
            float minValue = [slider minimumValue];
            float maxValue = [slider maximumValue];
            float value = [slider value];
            
            double time = duration * (value - minValue) / (maxValue - minValue);
            
            [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
        }
    }
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender {
    if (!self.timeObserver) {
        CMTime playerDuration = [self playerItemDuration];
        if (CMTIME_IS_INVALID(playerDuration)) {
            return;
        }
        
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration)) {
            CGFloat width = CGRectGetWidth([self.progressSlider bounds]);
            double tolerance = 0.5f * duration / width;
            
            __weak HTY360PlayerVC* weakSelf = self;
            self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC)
                                                                          queue:NULL
                                                                     usingBlock:^(CMTime time) {
                                                                         [weakSelf syncScrubber];
                                                                     }];
        }
    }
    
    if (self.mRestoreAfterScrubbingRate) {
        [self.player setRate:self.mRestoreAfterScrubbingRate];
        self.mRestoreAfterScrubbingRate = 0.f;
    }
}

- (BOOL)isScrubbing {
    return self.mRestoreAfterScrubbingRate != 0.f;
}

- (void)enableScrubber {
    self.progressSlider.enabled = YES;
}

- (void)disableScrubber {
    self.progressSlider.enabled = NO;
}

- (void)observeValueForKeyPath:(NSString*)path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
    /* AVPlayerItem "status" property value observer. */
    if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext) {
        [self updatePlayButton];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
                /* Indicates that the status of the player is not yet known because
                 it has not tried to load new media resources for playback */
            case AVPlayerStatusUnknown: {
                NSLog(@"AVPlayerStatusUnknown", nil);
                [self removePlayerTimeObserver];
                [self syncScrubber];
                [self disableScrubber];
                [self disablePlayerButtons];
                break;
            }
            case AVPlayerStatusReadyToPlay: {
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                NSLog(@"AVPlayerStatusReadyToPlay", nil);               
                
                [self.playerItem addOutput:self.videoOutput];
                [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
                
                [self initScrubberTimer];
                [self initBufferTimer];
                [self enableScrubber];
                [self enablePlayerButtons];
                
                if (self.autoPlay) {
//                    [self play];
                }                
                break;
            }
            case AVPlayerStatusFailed: {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
                NSLog(@"Error fail : %@", playerItem.error);
                break;
            }
        }
    } 
    else if (context == AVPlayerDemoPlaybackViewControllerRateObservationContext) {
        self.rateEventAppear = YES;
        [self updatePlayButton];
        
        if ( ![self isPlaying] && !self.playButton.selected ) {
            [self.activityIndicator startAnimating];
        }
        
        NSLog(@"AVPlayerDemoPlaybackViewControllerRateObservationContext");
    } else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext) {
        NSLog(@"AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext");
    } else {
        NSLog(@"observeValueForKeyPath");
        
        [super observeValueForKeyPath:path ofObject:object change:change context:context];
    }
}

- (void)assetFailedToPrepareForPlayback:(NSError *)error {
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    [self disablePlayerButtons];
    
    /* Display the error. */
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:[error localizedDescription]
                                          message:[error localizedFailureReason]
                                          preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                   NSLog(@"OK action");
                               }];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (BOOL)isPlaying {
    return self.mRestoreAfterScrubbingRate != 0.f || [self.player rate] != 0.f;
}

/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification {
    /* After the movie has played to its end time, seek back to time zero
     to play it again. */
    self.seekToZeroBeforePlay = YES;
    
    if ( self.loopVideo ) {
        [self play];
    }
}

#pragma mark - gyro button

- (IBAction)gyroButtonTouched:(id)sender {
    if(self.glkViewController.isUsingMotion) {
        [self.glkViewController stopDeviceMotion];
    } else {
        [self.glkViewController startDeviceMotion];
    }
    
    self.gyroButton.selected = self.glkViewController.isUsingMotion;
}

#pragma mark - back button

- (IBAction)backButtonTouched:(id)sender {
    [self removePlayerTimeObserver];
    
    [self.player pause];
    
    [self.glkViewController removeFromParentViewController];
    self.glkViewController = nil;
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

/* Cancels the previously registered time observer. */
- (void)removePlayerTimeObserver {
    NSLog(@"removePlayerTimeObserver");
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}

@end
