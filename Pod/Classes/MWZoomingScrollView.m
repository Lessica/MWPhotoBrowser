//
//  ZoomingScrollView.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "MWCommon.h"
#import "MWZoomingScrollView.h"
#import "MWPhotoBrowser.h"
#import "MWPhoto.h"
#import "MWPhotoBrowserPrivate.h"
#import "UIImage+MWPhotoBrowser.h"

// Private methods and properties
@interface MWZoomingScrollView () {
    
    MWPhotoBrowser __weak *_photoBrowser;
	MWTapDetectingView *_tapView; // for background taps
	MWTapDetectingImageView *_photoImageView;
    
}

@end

@implementation MWZoomingScrollView

- (id)initWithPhotoBrowser:(MWPhotoBrowser *)browser {
    if ((self = [super init])) {
        
        // Setup
        _index = NSUIntegerMax;
        _photoBrowser = browser;
        
		// Tap view for background
		_tapView = [[MWTapDetectingView alloc] initWithFrame:self.bounds];
		_tapView.tapDelegate = self;
		_tapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tapView.backgroundColor = [UIColor blackColor];
		[self addSubview:_tapView];
		
		// Image view
		_photoImageView = [[MWTapDetectingImageView alloc] initWithFrame:CGRectZero];
		_photoImageView.tapDelegate = self;
		_photoImageView.contentMode = UIViewContentModeCenter;
        _photoImageView.layer.magnificationFilter = kCAFilterNearest;
        _photoImageView.layer.minificationFilter = kCAFilterNearest;
		_photoImageView.backgroundColor = [UIColor blackColor];
		[self addSubview:_photoImageView];
        
		// Setup
		self.backgroundColor = [UIColor blackColor];
		self.delegate = self;
		self.showsHorizontalScrollIndicator = NO;
		self.showsVerticalScrollIndicator = NO;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.bounces = NO;
        self.bouncesZoom = NO;
        self.minimumZoomScale = 1.0;
        self.maximumZoomScale = 1000.f;
        self.clipsToBounds = YES;
        self.scrollsToTop = NO;
        
    }
    return self;
}

- (void)dealloc {
    if ([_photo respondsToSelector:@selector(cancelAnyLoading)]) {
        [_photo cancelAnyLoading];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)prepareForReuse {
    self.photo = nil;
    self.captionView = nil;
    self.selectedButton = nil;
    self.playButton = nil;
    _photoImageView.hidden = NO;
    _photoImageView.image = nil;
    _index = NSUIntegerMax;
}

- (BOOL)displayingVideo {
    return [_photo respondsToSelector:@selector(isVideo)] && _photo.isVideo;
}

- (void)setImageHidden:(BOOL)hidden {
    _photoImageView.hidden = hidden;
}

#pragma mark - Image

- (void)setPhoto:(id<MWPhoto>)photo {
    // Cancel any loading on old photo
    if (_photo && photo == nil) {
        if ([_photo respondsToSelector:@selector(cancelAnyLoading)]) {
            [_photo cancelAnyLoading];
        }
    }
    _photo = photo;
    UIImage *img = [_photoBrowser imageForPhoto:_photo];
    if (img) {
        [self displayImage];
    }
}

// Get and display image
- (void)displayImage {
	if (_photo && _photoImageView.image == nil) {
		
		// Reset
        self.scrollEnabled = NO;
		self.maximumZoomScale = 1;
		self.minimumZoomScale = 1;
		self.zoomScale = 1;
		self.contentSize = CGSizeMake(0, 0);
		
		// Get image from browser as it handles ordering of fetching
		UIImage *img = [_photoBrowser imageForPhoto:_photo];
		if (img) {
			
			// Set image
			_photoImageView.image = img;
			_photoImageView.hidden = NO;
			
			// Setup photo frame
			CGRect photoImageViewFrame;
			photoImageViewFrame.origin = CGPointZero;
			photoImageViewFrame.size = img.size;
			_photoImageView.frame = photoImageViewFrame;
			self.contentSize = photoImageViewFrame.size;

			// Set zoom to minimum zoom
			[self setMaxMinZoomScalesForCurrentBounds];
			
		} else {
			
		}
		[self setNeedsLayout];
	}
}

#pragma mark - Setup

- (CGFloat)initialZoomScaleWithMinScale {
    CGFloat zoomScale = self.minimumZoomScale;
    if (_photoImageView && _photoBrowser.zoomPhotosToFill) {
        // Zoom image to fill if the aspect ratios are fairly similar
        CGSize boundsSize = self.bounds.size;
        CGSize imageSize = _photoImageView.image.size;
        CGFloat boundsAR = boundsSize.width / boundsSize.height;
        CGFloat imageAR = imageSize.width / imageSize.height;
        CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
        CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
        // Zooms standard portrait images on a 3.5in screen but not on a 4in screen.
        if (ABS(boundsAR - imageAR) < 0.17) {
            // for images which are vertically long
            if (imageAR < 1.0) {
                zoomScale = MIN(xScale, yScale);
            } else {
                zoomScale = MAX(xScale, yScale);
            }
            // Ensure we don't zoom in or out too far, just in case
            zoomScale = MIN(MAX(self.minimumZoomScale, zoomScale), self.maximumZoomScale);
        }
    }
    return zoomScale;
}

- (void)setMaxMinZoomScalesForCurrentBounds {
    
    // Reset
    self.maximumZoomScale = 1;
    self.minimumZoomScale = 1;
    self.zoomScale = 1;
    
    // Bail if no image
    if (_photoImageView.image == nil) return;
    
    // Reset position
    _photoImageView.frame = CGRectMake(0, 0, _photoImageView.frame.size.width, _photoImageView.frame.size.height);
	
    // Sizes
    CGSize boundsSize = self.bounds.size;
    CGSize imageSize = _photoImageView.image.size;
    
    // Calculate Min
    CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = MIN(xScale, yScale);                 // use minimum of these to allow the image to become fully visible
    
    // Calculate Max
    CGFloat maxScale = 1000.f;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // Let them go a bit bigger on a bigger screen!
        maxScale = 1500.f;
    }
    
    if (_photoBrowser.zoomSmallPhotos)
    {
        if (xScale >= 3.0 && yScale >= 3.0) {
            minScale = 3.0;
        }
        if (maxScale <= minScale)
            maxScale = minScale + 2.0;
    } else {
        // Image is smaller than screen so no zooming!
        if (xScale >= 1.0 && yScale >= 1.0)
        {
            minScale = 1.0;
        }
    }
    
    // Set min/max zoom
    self.maximumZoomScale = maxScale;
    self.minimumZoomScale = minScale;
    
    // Initial zoom
    self.zoomScale = [self initialZoomScaleWithMinScale];
    
    // If we're zooming to fill then centralise
    if (self.zoomScale != minScale) {
        
        // Centralise
        self.contentOffset = CGPointMake((imageSize.width * self.zoomScale - boundsSize.width) / 2.0,
                                         (imageSize.height * self.zoomScale - boundsSize.height) / 2.0);

    }
    
    // Disable scrolling initially until the first pinch to fix issues with swiping on an initally zoomed in photo
    self.scrollEnabled = NO;
    
    // If it's a video then disable zooming
    if ([self displayingVideo]) {
        self.maximumZoomScale = self.zoomScale;
        self.minimumZoomScale = self.zoomScale;
    }

    // Layout
	[self setNeedsLayout];

}

#pragma mark - Layout

- (void)layoutSubviews {
	
	// Update tap view frame
	_tapView.frame = self.bounds;

	// Super
	[super layoutSubviews];
	
    // Center the image as it becomes smaller than the size of the screen
    CGSize boundsSize = self.bounds.size;
    CGRect frameToCenter = _photoImageView.frame;
    
    // Horizontally
    if (frameToCenter.size.width < boundsSize.width) {
        frameToCenter.origin.x = floorf((boundsSize.width - frameToCenter.size.width) / 2.0);
	} else {
        frameToCenter.origin.x = 0;
	}
    
    // Vertically
    if (frameToCenter.size.height < boundsSize.height) {
        frameToCenter.origin.y = floorf((boundsSize.height - frameToCenter.size.height) / 2.0);
	} else {
        frameToCenter.origin.y = 0;
	}
    
	// Center
	if (!CGRectEqualToRect(_photoImageView.frame, frameToCenter))
		_photoImageView.frame = frameToCenter;
	
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _photoImageView;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    self.scrollEnabled = YES; // reset
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	[_photoBrowser hideControlsAfterDelay];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Tap Detection

- (void)handleSingleTap:(CGPoint)touchPoint {
	[_photoBrowser performSelector:@selector(toggleControls) withObject:nil afterDelay:0.2];
}

- (void)handleDoubleTap:(CGPoint)touchPoint {
    
    // Dont double tap to zoom if showing a video
    if ([self displayingVideo]) {
        return;
    }
	
	// Cancel any single tap handling
	[NSObject cancelPreviousPerformRequestsWithTarget:_photoBrowser];
	
	// Zoom
	if (self.zoomScale != self.minimumZoomScale && self.zoomScale != [self initialZoomScaleWithMinScale]) {
		
		// Zoom out
		[self setZoomScale:self.minimumZoomScale animated:YES];
		
	} else {
		
		// Zoom in to twice the size
//        CGFloat newZoomScale = ((self.maximumZoomScale + self.minimumZoomScale) / 2);
        CGFloat newZoomScale = ((3.0 + self.minimumZoomScale) / 2);
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            newZoomScale = ((4.0 + self.minimumZoomScale) / 2);
        }
        CGFloat xsize = self.bounds.size.width / newZoomScale;
        CGFloat ysize = self.bounds.size.height / newZoomScale;
        [self zoomToRect:CGRectMake(touchPoint.x - xsize/2, touchPoint.y - ysize/2, xsize, ysize) animated:YES];

	}
	
	// Delay controls
	[_photoBrowser hideControlsAfterDelay];
	
}

// Image View
- (void)imageView:(UIImageView *)imageView singleTapDetected:(UITouch *)touch { 
    [self handleSingleTap:[touch locationInView:imageView]];
}
- (void)imageView:(UIImageView *)imageView doubleTapDetected:(UITouch *)touch {
    [self handleDoubleTap:[touch locationInView:imageView]];
}

// Background View
- (void)view:(UIView *)view singleTapDetected:(UITouch *)touch {
    // Translate touch location to image view location
    CGFloat touchX = [touch locationInView:view].x;
    CGFloat touchY = [touch locationInView:view].y;
    touchX *= 1/self.zoomScale;
    touchY *= 1/self.zoomScale;
    touchX += self.contentOffset.x;
    touchY += self.contentOffset.y;
    [self handleSingleTap:CGPointMake(touchX, touchY)];
}
- (void)view:(UIView *)view doubleTapDetected:(UITouch *)touch {
    // Translate touch location to image view location
    CGFloat touchX = [touch locationInView:view].x;
    CGFloat touchY = [touch locationInView:view].y;
    touchX *= 1/self.zoomScale;
    touchY *= 1/self.zoomScale;
    touchX += self.contentOffset.x;
    touchY += self.contentOffset.y;
    [self handleDoubleTap:CGPointMake(touchX, touchY)];
}

@end
