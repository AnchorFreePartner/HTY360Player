//
//  HTYSlider.m
//  K360Player
//
//  Created by Sergey Kim on 05.09.16.
//  Copyright © 2016 Sergey Kim. All rights reserved.
//

#import "HTYSlider.h"

@implementation HTYSlider

- (void) awakeFromNib {
    self.bufferView = [[UIProgressView alloc] initWithFrame:CGRectZero];
    self.bufferView.trackTintColor = [UIColor clearColor];
    self.bufferView.progressTintColor = [UIColor whiteColor];
    
    [self addSubview:self.bufferView];
    [self sendSubviewToBack:self.bufferView];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    
    CGRect rect = self.bounds;
    self.bufferView.frame = CGRectMake(CGRectGetMinX(rect)+2, CGRectGetHeight(rect)/2.0 - 0.5, CGRectGetWidth(rect)-4, 2);
}

- (void) setup {
    self.continuous = NO;
    self.value = 0;
    self.bufferView.progress = 0;
    
    [self setMinimumTrackImage:[UIImage alloc] forState:UIControlStateNormal];
    [self setMaximumTrackImage:[UIImage alloc] forState:UIControlStateNormal];
    
    [self setThumbImage:[UIImage imageNamed:@"thumb.png"] forState:UIControlStateNormal];
    [self setThumbImage:[UIImage imageNamed:@"thumb.png"] forState:UIControlStateHighlighted];
    
    [self setMinimumTrackTintColor:[UIColor blueColor]];
    
}

- (void) setValue:(float)value {
    [super setValue:value];
}

- (void) setBufferValue:(float)value {
    self.bufferView.progress = value;
}

@end
