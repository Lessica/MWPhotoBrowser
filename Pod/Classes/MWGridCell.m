//
//  MWGridCell.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//

#import "MWGridCell.h"
#import "MWCommon.h"
#import "MWPhotoBrowserPrivate.h"
#import "UIImage+MWPhotoBrowser.h"

#define VIDEO_INDICATOR_PADDING 10

@interface MWGridCell () {
    
    UIImageView *_imageView;
    UIImageView *_videoIndicator;
    UIButton *_selectedButton;
    
}

@end

@implementation MWGridCell

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {

        // Grey background
        self.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
        
        // Image
        _imageView = [UIImageView new];
        _imageView.frame = self.bounds;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self addSubview:_imageView];
        
        // Video Image
        _videoIndicator = [UIImageView new];
        _videoIndicator.hidden = NO;
        UIImage *videoIndicatorImage = [UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/VideoOverlay" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]];
        _videoIndicator.frame = CGRectMake(self.bounds.size.width - videoIndicatorImage.size.width - VIDEO_INDICATOR_PADDING, self.bounds.size.height - videoIndicatorImage.size.height - VIDEO_INDICATOR_PADDING, videoIndicatorImage.size.width, videoIndicatorImage.size.height);
        _videoIndicator.image = videoIndicatorImage;
        _videoIndicator.autoresizesSubviews = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:_videoIndicator];
        
        // Selection button
        _selectedButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _selectedButton.contentMode = UIViewContentModeTopRight;
        _selectedButton.adjustsImageWhenHighlighted = NO;
        [_selectedButton setImage:[UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/ImageSelectedSmallOff" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]] forState:UIControlStateNormal];
        [_selectedButton setImage:[UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/ImageSelectedSmallOn" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]] forState:UIControlStateSelected];
        [_selectedButton addTarget:self action:@selector(selectionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _selectedButton.hidden = YES;
        _selectedButton.frame = CGRectMake(0, 0, 44, 44);
        [self addSubview:_selectedButton];
        
        // Listen for photo loading notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMWPhotoLoadingDidEndNotification:)
                                                     name:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                                   object:nil];
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setGridController:(MWGridViewController *)gridController {
    _gridController = gridController;
    // Set custom selection image if required
    if (_gridController.browser.customImageSelectedSmallIconName) {
        [_selectedButton setImage:[UIImage imageNamed:_gridController.browser.customImageSelectedSmallIconName] forState:UIControlStateSelected];
    }
}

#pragma mark - View

- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.frame = self.bounds;
    _selectedButton.frame = CGRectMake(self.bounds.size.width - _selectedButton.frame.size.width - 0,
                                       0, _selectedButton.frame.size.width, _selectedButton.frame.size.height);
}

#pragma mark - Cell

- (void)prepareForReuse {
    _photo = nil;
    _gridController = nil;
    _imageView.image = nil;
    _selectedButton.hidden = YES;
    [super prepareForReuse];
}

#pragma mark - Image Handling

- (void)setPhoto:(id <MWPhoto>)photo {
    _photo = photo;
    if ([photo respondsToSelector:@selector(isVideo)]) {
        _videoIndicator.hidden = !photo.isVideo;
    } else {
        _videoIndicator.hidden = YES;
    }
}

- (void)displayImage {
    _imageView.image = [_photo underlyingImage];
    _selectedButton.hidden = !_selectionMode;
}

#pragma mark - Selection

- (void)setSelectionMode:(BOOL)selectionMode {
    _selectionMode = selectionMode;
}

- (void)setIsSelected:(BOOL)isSelected {
    _isSelected = isSelected;
    _selectedButton.selected = isSelected;
}

- (void)selectionButtonPressed {
    _selectedButton.selected = !_selectedButton.selected;
    [_gridController.browser setPhotoSelected:_selectedButton.selected atIndex:_index];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    _imageView.alpha = 0.6;
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    _imageView.alpha = 1;
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    _imageView.alpha = 1;
    [super touchesCancelled:touches withEvent:event];
}

#pragma mark - Notifications

- (void)handleMWPhotoLoadingDidEndNotification:(NSNotification *)notification {
    id <MWPhoto> photo = [notification object];
    if (photo == _photo) {
        if ([photo underlyingImage]) {
            // Successful load
            [self displayImage];
        }
    }
}

@end
