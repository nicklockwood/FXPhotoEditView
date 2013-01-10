//
//  FXPhotoEditView.m
//
//  Version 1.0 beta
//
//  Created by Nick Lockwood on 09/11/2011.
//  Copyright 2011 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXPhotoEditView
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "FXPhotoEditView.h"
#import <QuartzCore/QuartzCore.h>


#define GRID_BORDER (1.0f/6.0f)
#define HANDLE_RADIUS 40.0f
#define MIN_DIVIDER_SPACING 10.0f
#define MIN_GRID_SIZE 20.0f


@interface FXPhotoEditGridView : UIView

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) NSArray *gridLines;

@end


@implementation FXPhotoEditGridView

@synthesize imageView;
@synthesize gridLines;

- (void)setUp
{    
    UIImage *image = [UIImage imageNamed:@"FXPhotoEditGrid.png"];
    image = [image stretchableImageWithLeftCapWidth:image.size.width/2 topCapHeight:image.size.height/2];
    imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleToFill;
    [self addSubview:imageView];
    
    gridLines = [[NSArray alloc] initWithObjects:
                 [[[UIView alloc] init] autorelease],
                 [[[UIView alloc] init] autorelease],
                 [[[UIView alloc] init] autorelease],
                 [[[UIView alloc] init] autorelease],
                 nil];
    for (UIView *view in gridLines)
    {
        view.backgroundColor = [UIColor whiteColor];
        view.userInteractionEnabled = NO;
        [imageView addSubview:view];
    }
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)updateViews
{
	CGFloat inset = imageView.image.size.width * GRID_BORDER;
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    imageView.frame = CGRectMake(-inset, -inset, width + inset * 2, height + inset * 2);
    
    CGFloat xspace = width/3.0f;
    CGFloat yspace = height/3.0f;
    
    [[gridLines objectAtIndex:0] setFrame:CGRectMake(xspace + inset, inset, 1.0f, height)];
    [[gridLines objectAtIndex:1] setFrame:CGRectMake(xspace * 2.0f + inset, inset, 1.0f, height)];
    [[gridLines objectAtIndex:2] setFrame:CGRectMake(inset, yspace + inset, width, 1.0f)];
    [[gridLines objectAtIndex:3] setFrame:CGRectMake(inset, yspace * 2.0f + inset, width, 1.0f)];
    
    BOOL visible = (xspace >= MIN_DIVIDER_SPACING && yspace >= MIN_DIVIDER_SPACING);
    for (UIView *view in gridLines)
    {
        view.alpha = visible? 1.0f: 0.0f;
    }
}

- (void)setFrame:(CGRect)frame
{
    super.frame = frame;
    [self updateViews];
}

- (void)setBounds:(CGRect)bounds
{
    super.bounds = bounds;
    [self updateViews];
}

- (CGSize)minSize
{
    return imageView.image.size;
}

- (void)dealloc
{
    [imageView release];
    [super dealloc];
}

@end


typedef enum
{
    FXPhotoEditGridCornerNone = 0,
	FXPhotoEditGridCornerTopLeft,
    FXPhotoEditGridCornerTopRight,
    FXPhotoEditGridCornerBottomRight,
    FXPhotoEditGridCornerBottomLeft,
}
FXPhotoEditGridCorner;


@interface FXPhotoEditView () <UIGestureRecognizerDelegate>

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, retain) FXPhotoEditGridView *gridView;
@property (nonatomic, assign) CGPoint imageOffset;
@property (nonatomic, assign) CGFloat imageRotation;
@property (nonatomic, assign) CGFloat imageScale;
@property (nonatomic, assign) FXPhotoEditGridCorner selectedCorner;

@property (nonatomic, assign) CGPoint savedOffset;
@property (nonatomic, assign) CGFloat savedRotation;
@property (nonatomic, assign) CGFloat savedScale;
@property (nonatomic, assign) CGAffineTransform savedTransform;
@property (nonatomic, assign) CGRect savedGridFrame;

@end


@implementation FXPhotoEditView

@synthesize image;
@synthesize editing;
@synthesize imageView;
@synthesize gridView;
@synthesize imageOffset;
@synthesize imageRotation;
@synthesize imageScale;
@synthesize selectedCorner;
@synthesize zoomInset;
@synthesize savedOffset;
@synthesize savedRotation;
@synthesize savedScale;
@synthesize savedTransform;
@synthesize savedGridFrame;

- (CGSize)scaleSize:(CGSize)a toFillSize:(CGSize)b
{
    if (a.width == 0.0f || a.height == 0.0f || b.width == 0.0f || b.height == 0.0f)
    {
        return b;
    }
    CGFloat aspectA = a.width / a.height;
    CGFloat aspectB = b.width / b.height;
    if (aspectA > aspectB)
    {
        return CGSizeMake(b.height * aspectA, b.height);
    }
    else
    {
        return CGSizeMake(b.width, b.width * aspectA);
    }
}

- (CGFloat)scaleForSize:(CGSize)a toFillSize:(CGSize)b
{
    if (a.width == 0.0f || a.height == 0.0f || b.width == 0.0f || b.height == 0.0f)
    {
        return 1.0f;
    }
    return [self scaleSize:a toFillSize:b].width / a.width;
}

- (CGSize)scaleSize:(CGSize)a toFitSize:(CGSize)b
{
    if (a.width == 0.0f || a.height == 0.0f || b.width == 0.0f || b.height == 0.0f)
    {
        return b;
    }
    CGFloat aspectA = a.width / a.height;
    CGFloat aspectB = b.width / b.height;
    if (aspectA > aspectB)
    {
        return CGSizeMake(b.width, b.width / aspectA);
    }
    else
    {
        return CGSizeMake(b.height * aspectA, b.height);
    }
}

- (CGFloat)scaleForSize:(CGSize)a toFitSize:(CGSize)b
{
    return [self scaleSize:a toFitSize:b].width / a.width;
}

- (CGFloat)angleForOrientation:(UIImageOrientation)orientation
{
    switch (orientation)
    {
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
        {
        	return 0.0f;
        }
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        {
        	return -M_PI_2;
        }
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
        {
        	return -M_PI;
        }
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
        {
        	return -(M_PI + M_PI_2);
        }
    }
}

- (BOOL)orientationIsVertical:(UIImageOrientation)orientation
{
    switch (orientation)
    {
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
        {
        	return YES;
        }
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
        {
        	return NO;
        }
    }
}

- (CGPoint)offset:(CGPoint)offset rotatedByAngle:(CGFloat)angle aboutPoint:(CGPoint)point
{
    return CGPointMake(point.x + (offset.x - point.x) * cosf(angle) - (offset.y - point.y) * sinf(angle), point.y + (offset.x - point.x) * sinf(angle) + (offset.y - point.y) * cosf(angle));
}

- (CGPoint)offset:(CGPoint)offset scaledByFactor:(CGFloat)scale aboutPoint:(CGPoint)point
{
    return CGPointMake(point.x + (offset.x - point.x) * scale, point.y + (offset.y - point.y) * scale);
}

- (CGPoint)offset:(CGPoint)offset unscaledByFactor:(CGFloat)scale aboutPoint:(CGPoint)point
{
    return CGPointMake(point.x / scale + (offset.x - point.x), point.y / scale + (offset.y - point.y));
}

- (CGRect)rect:(CGRect)rect withInset:(CGSize)inset
{
    rect.origin.x += inset.width;
    rect.origin.y += inset.height;
    rect.size.width -= inset.width * 2;
    rect.size.height -= inset.height * 2;
    return rect;
}

- (CGRect)contentRect
{
    CGRect rect = self.bounds;
    if (editing)
    {
        return [self rect:rect withInset:zoomInset];
    }
    return rect;
}

- (CGFloat)imageScaleForOrientation:(UIImageOrientation)orientation
{
    CGSize size = imageView.bounds.size;
    if (![self orientationIsVertical:orientation])
    {
        size = CGSizeMake(size.height, size.width);
    }
    return [self scaleForSize:size toFitSize:[self contentRect].size] * imageScale;
}

- (CGAffineTransform)imageTransformForOrientation:(UIImageOrientation)orientation
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    CGFloat scale = [self imageScaleForOrientation:orientation];
    transform = CGAffineTransformScale(transform, scale, scale);
    
    CGFloat angle = [self angleForOrientation:orientation];
    CGPoint offset = [self offset:imageOffset rotatedByAngle:angle aboutPoint:CGPointZero];
    transform = CGAffineTransformTranslate(transform, offset.x, offset.y);
    
    angle += imageRotation;
    transform = CGAffineTransformRotate(transform, angle);
    
    return transform;
}

- (CGRect)gridRectForImageOrientation:(UIImageOrientation)orientation
{
    CGSize size = gridView.bounds.size;
    if (![self orientationIsVertical:orientation])
    {
    	size = CGSizeMake(size.height, size.width);
    }
    CGRect rect = [self contentRect];
    rect.size = [self scaleSize:size toFitSize:rect.size];
    rect.origin = CGPointMake((self.bounds.size.width - rect.size.width)/2.0f, (self.bounds.size.height- rect.size.height)/2.0f);
    
    return rect;
}

- (void)updateViews
{
    //position grid view
    gridView.frame = [self gridRectForImageOrientation:UIImageOrientationUp];
    
    //position image view
	imageView.center = CGPointMake(self.bounds.size.width/2.0f, self.bounds.size.height/2.0f);
	imageView.transform = [self imageTransformForOrientation:UIImageOrientationUp];
}

- (void)setUp
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
    	zoomInset = CGSizeMake(40.0f, 40.0f);
    }
    else
    {
        zoomInset = CGSizeMake(20.0f, 20.0f);
    }

    editing = NO;
    imageScale = 1.0f;
    imageRotation = 0.0f;
    imageOffset = CGPointZero;

    imageView = [[UIImageView alloc] init];
    imageView.contentMode = UIViewContentModeScaleToFill;
    [self addSubview:imageView];
    
    gridView = [[FXPhotoEditGridView alloc] initWithFrame:self.bounds];
    gridView.alpha = 0.0f;
    [self addSubview:gridView];
    
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
    pinch.delegate = self;
    [self addGestureRecognizer:pinch];
    [pinch release];
    
    UIRotationGestureRecognizer *rotate = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotate:)];
    rotate.delegate = self;
    [self addGestureRecognizer:rotate];
    [rotate release];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    pan.delegate = self;
    pan.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:pan];
    [pan release];
    
    [self updateViews];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)setZoomInsets:(CGSize)_zoomInset
{
    zoomInset = _zoomInset;
    [self updateViews];
}
     
- (void)setFrame:(CGRect)frame
{
    super.frame = frame;
    [self updateViews];
}

- (void)setBounds:(CGRect)bounds
{
    super.bounds = bounds;
    [self updateViews];
}

- (void)setImage:(UIImage *)_image
{
    if (image != _image)
    {
        [image release];
        image = [_image retain];
        imageView.image = image;
        
        CGRect rect = gridView.bounds;
        rect.size = image.size;
        gridView.bounds = rect;
        
        [imageView sizeToFit];
        [self updateViews];
    }
}

- (void)setEditing:(BOOL)_editing
{
    if (editing != _editing)
    {
        editing = _editing;
        [self updateViews];
        gridView.alpha = editing? 1.0f: 0.0f;
    }
}

- (void)setEditing:(BOOL)_editing animated:(BOOL)animated;
{
    if (editing != _editing)
    {
        [UIView animateWithDuration:animated? 0.2f: 0.0f animations:^{
            
            self.editing = _editing;
        }];
    }
}

- (UIImageOrientation)rotatedOrientation:(UIImageOrientation)orientation
{
    switch (orientation)
    {
        case UIImageOrientationUp:
        {
        	return UIImageOrientationLeft;
        }
        case UIImageOrientationLeft:
        {
        	return UIImageOrientationDown;
        }
        case UIImageOrientationDown:
        {
        	return UIImageOrientationRight;
        }
        case UIImageOrientationRight:
        {
        	return UIImageOrientationUp;
        }
        case UIImageOrientationUpMirrored:
        {
        	return UIImageOrientationLeftMirrored;
        }
        case UIImageOrientationLeftMirrored:
        {
        	return UIImageOrientationDownMirrored;
        }
        case UIImageOrientationDownMirrored:
        {
        	return UIImageOrientationRightMirrored;
        }
        case UIImageOrientationRightMirrored:
        {
        	return UIImageOrientationUpMirrored;
        }
    }
}

- (void)saveTransform
{
    savedOffset = imageOffset;
    savedRotation = imageRotation;
    savedScale = imageScale;
    savedTransform = imageView.transform;
    savedGridFrame = gridView.frame;
}

- (void)restoreTransform
{
    imageOffset = savedOffset;
    imageRotation = savedRotation;
    imageScale = savedScale;
    imageView.transform = savedTransform;
    gridView.frame = savedGridFrame;
}

- (BOOL)isGridInsidePhoto
{
    CGPoint topLeft = gridView.bounds.origin;
    topLeft = [imageView convertPoint:topLeft fromView:gridView];
    if (!CGRectContainsPoint(imageView.bounds, topLeft))
    {
        return NO;
    }
    
    CGPoint topRight = gridView.bounds.origin;
    topRight.x += gridView.bounds.size.width;
    topRight = [imageView convertPoint:topRight fromView:gridView];
    if (!CGRectContainsPoint(imageView.bounds, topRight))
    {
        return NO;
    }
    
    CGPoint bottomLeft = gridView.bounds.origin;
    bottomLeft.y += gridView.bounds.size.height;
    bottomLeft = [imageView convertPoint:bottomLeft fromView:gridView];
    if (!CGRectContainsPoint(imageView.bounds, bottomLeft))
    {
        return NO;
    }
    
    CGPoint bottomRight = gridView.bounds.origin;
    bottomRight.x += gridView.bounds.size.width;
    bottomRight.y += gridView.bounds.size.height;
    bottomRight = [imageView convertPoint:bottomRight fromView:gridView];
    if (!CGRectContainsPoint(imageView.bounds, bottomRight))
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
    {
		return NO;
    }
    
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]])
    {
        selectedCorner = FXPhotoEditGridCornerNone;
        
        CGPoint position = [gestureRecognizer locationInView:self];
        CGRect rect = gridView.frame;
        
        CGFloat distance = powf(position.x - rect.origin.x, 2.0f) + powf(position.y - rect.origin.y, 2.0f);
        if (distance <= HANDLE_RADIUS * HANDLE_RADIUS)
        {
            selectedCorner = FXPhotoEditGridCornerTopLeft;
        }
        
        distance = powf(position.x - (rect.origin.x + rect.size.width), 2.0f) + powf(position.y - rect.origin.y, 2.0f);
        if (distance <= HANDLE_RADIUS * HANDLE_RADIUS)
        {
            selectedCorner = FXPhotoEditGridCornerTopRight;
        }
        
        distance = powf(position.x - (rect.origin.x + rect.size.width), 2.0f) + powf(position.y - (rect.origin.y + rect.size.height), 2.0f);
        if (distance <= HANDLE_RADIUS * HANDLE_RADIUS)
        {
            selectedCorner = FXPhotoEditGridCornerBottomRight;
        }
        
        distance = powf(position.x - rect.origin.x, 2.0f) + powf(position.y - (rect.origin.y + rect.size.height), 2.0f);
        if (distance <= HANDLE_RADIUS * HANDLE_RADIUS)
        {
            selectedCorner = FXPhotoEditGridCornerBottomLeft;
        }
    }
    return YES;
}

- (void)pan:(UIPanGestureRecognizer *)gesture
{
    if (editing)
    {
        switch (gesture.state)
        {
            case UIGestureRecognizerStateEnded:
            case UIGestureRecognizerStateCancelled:
            {
                //reposition
                CGRect rect = [self gridRectForImageOrientation:UIImageOrientationUp];
                CGFloat scale = [self imageScaleForOrientation:UIImageOrientationUp];
                CGPoint offset = CGPointMake(gridView.center.x - (rect.origin.x + rect.size.width/2.0f), gridView.center.y - (rect.origin.y + rect.size.height/2.0f));
                offset.x /= scale;
                offset.y /= scale;
                offset.x = imageOffset.x - offset.x;
                offset.y = imageOffset.y - offset.y;
                imageOffset = offset;
                
                //zoom
                scale = rect.size.width / gridView.frame.size.width;
                imageScale *= scale;
                
            	[UIView animateWithDuration:0.2f animations:^{
                    
                    imageView.transform = [self imageTransformForOrientation:UIImageOrientationUp];
                    gridView.frame = rect;
                    
                }];
                break;
            }
            case UIGestureRecognizerStateChanged:
            {
                CGRect rect = gridView.frame;
                CGPoint distance = [gesture translationInView:self];
                
                //save transform
                [self saveTransform];
                
                switch (selectedCorner)
                {
                    case FXPhotoEditGridCornerNone:
                    {
                        CGFloat scale = [self imageScaleForOrientation:UIImageOrientationUp];
                        imageOffset.x += distance.x / scale;
                        imageOffset.y += distance.y / scale;
                        imageView.transform = [self imageTransformForOrientation:UIImageOrientationUp];
                        break;
                    }
                    case FXPhotoEditGridCornerTopLeft:
                    {
                        if (rect.size.width - distance.x < MIN_GRID_SIZE)
                        {
                            distance.x = rect.size.width - MIN_GRID_SIZE;
                        }
                        if (rect.size.height - distance.y < MIN_GRID_SIZE)
                        {
                            distance.y = rect.size.height - MIN_GRID_SIZE;
                        }
                        rect.origin.x += distance.x;
                        rect.origin.y += distance.y;
                        rect.size.width -= distance.x;
                        rect.size.height -= distance.y;
                        gridView.frame = rect;
                        break;
                    }
                    case FXPhotoEditGridCornerTopRight:
                    {
                        if (rect.size.width + distance.x < MIN_GRID_SIZE)
                        {
                            distance.x = MIN_GRID_SIZE - rect.size.width;
                        }
                        if (rect.size.height - distance.y < MIN_GRID_SIZE)
                        {
                            distance.y = rect.size.height - MIN_GRID_SIZE;
                        }
                        rect.origin.y += distance.y;
                        rect.size.width += distance.x;
                        rect.size.height -= distance.y;
                        gridView.frame = rect;
                        break;
                    }
                    case FXPhotoEditGridCornerBottomRight:
                    {
                        if (rect.size.width + distance.x < MIN_GRID_SIZE)
                        {
                            distance.x = MIN_GRID_SIZE - rect.size.width;
                        }
						if (rect.size.height + distance.y < MIN_GRID_SIZE)
                        {
                            distance.y = MIN_GRID_SIZE - rect.size.height;
                        }
                        rect.size.width += distance.x;
                        rect.size.height += distance.y;
                        gridView.frame = rect;
                        break;
                    }
                    case FXPhotoEditGridCornerBottomLeft:
                    {
                        if (rect.size.width - distance.x < MIN_GRID_SIZE)
                        {
                            distance.x = rect.size.width - MIN_GRID_SIZE;
                        }
                        if (rect.size.height + distance.y < MIN_GRID_SIZE)
                        {
                            distance.y = MIN_GRID_SIZE - rect.size.height;
                        }
                        rect.origin.x += distance.x;
                        rect.size.width -= distance.x;
                        rect.size.height += distance.y;
                        gridView.frame = rect;
                        break;
                    }
                    default:
                    {
                        //do nothing
                        break;
                    }
                }
                
                //restore transform if action was invalid
                if (![self isGridInsidePhoto])
                {
                    [self restoreTransform];
                }
                
                [gesture setTranslation:CGPointZero inView:self];
                break;
            }
            default:
            {
                //do nothing
                break;
            }
        }
    }
}

- (void)pinch:(UIPinchGestureRecognizer *)gesture
{
    if (editing)
    {
        //save transform
        [self saveTransform];
        
        //adjust for offset
        CGFloat scale = [self imageScaleForOrientation:UIImageOrientationUp];
        CGPoint center = [gesture locationInView:self];
        center.x -= self.bounds.size.width/2.0f;
        center.y -= self.bounds.size.height/2.0f;
        center.x /= scale;
        center.y /= scale;

        imageScale *= gesture.scale;
        imageOffset = [self offset:imageOffset unscaledByFactor:gesture.scale aboutPoint:center];
        imageView.transform = [self imageTransformForOrientation:UIImageOrientationUp];
        gesture.scale = 1.0f;
        
        //restore transform if action was invalid
        if (![self isGridInsidePhoto])
        {
            [self restoreTransform];
        }
    }
}

- (void)rotate:(UIRotationGestureRecognizer *)gesture
{
    if (editing)
    {
        //save transform
        [self saveTransform];
        
        //adjust for offset
        CGFloat scale = [self imageScaleForOrientation:UIImageOrientationUp];
        CGPoint center = [gesture locationInView:self];
        center.x -= self.bounds.size.width/2.0f;
        center.y -= self.bounds.size.height/2.0f;
        center.x /= scale;
        center.y /= scale;
        
        imageRotation += gesture.rotation;
        imageOffset = [self offset:imageOffset rotatedByAngle:gesture.rotation aboutPoint:center];
        imageView.transform = [self imageTransformForOrientation:UIImageOrientationUp];
        gesture.rotation = 0.0f;
        
        //restore transform if action was invalid
        if (![self isGridInsidePhoto])
        {
            [self restoreTransform];
        }
    }
}

- (void)rotateLeft:(BOOL)animated
{
    [UIView animateWithDuration:animated? 0.2f: 0.0f animations:^{

    	imageView.transform = [self imageTransformForOrientation:UIImageOrientationLeft];
    	gridView.frame = [self gridRectForImageOrientation:UIImageOrientationLeft];
    
    } completion:^(BOOL finished) {
        
        CGFloat angle = [self angleForOrientation:UIImageOrientationLeft];
        imageOffset = [self offset:imageOffset rotatedByAngle:angle aboutPoint:CGPointZero];
        UIImageOrientation orientation = [self rotatedOrientation:image.imageOrientation];
        self.image = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:orientation];
	}];
}

- (void)constrain:(CGFloat)aspectRatio animated:(BOOL)animated
{
    //reposition
    imageOffset = CGPointZero;
    
    //zoom
    imageScale = 1.0f;
    CGFloat scale = [self imageScaleForOrientation:UIImageOrientationUp];
    CGSize imageSize = CGSizeMake(image.size.width*scale, image.size.height*scale); 
    
    //set grid frame
    CGRect rect = CGRectZero;
    rect.size = CGSizeMake(aspectRatio, 1.0f);
    rect.size = [self scaleSize:rect.size toFitSize:imageSize];
    
    //adjust
    imageScale = [self scaleForSize:rect.size toFitSize:[self contentRect].size];
    rect.size.width *= imageScale;
    rect.size.height *= imageScale;
    rect.origin.x = (self.bounds.size.width - rect.size.width)/2.0f;
    rect.origin.y = (self.bounds.size.height - rect.size.height)/2.0f;
    
    [UIView animateWithDuration:animated? 0.2f: 0.0f animations:^{
        
        imageView.transform = [self imageTransformForOrientation:UIImageOrientationUp];
        gridView.frame = rect;
    }];
}

- (void)crop
{
    //get image size
    CGRect rect = [self gridRectForImageOrientation:UIImageOrientationUp];
    CGFloat scale = [self imageScaleForOrientation:UIImageOrientationUp];
	rect.size.width /= scale;
	rect.size.height /= scale;
    
    //create image
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setFill];
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, rect.size.width, rect.size.height));

    CGContextTranslateCTM(context, rect.size.width/2.0f, rect.size.height/2.0f);
    CGContextTranslateCTM(context, imageOffset.x, imageOffset.y);
    CGContextRotateCTM(context, imageRotation);
    CGContextTranslateCTM(context, -image.size.width/2.0f, -image.size.height/2.0f);
    
    [image drawAtPoint:CGPointZero];
    
    //update image
    imageScale = 1.0f;
    imageRotation = 0.0f;
    imageOffset = CGPointZero;
    self.image = UIGraphicsGetImageFromCurrentImageContext();
    
    //end context
    UIGraphicsEndImageContext();
}

- (void)dealloc
{
    [image release];
    [imageView release];
    [gridView release];
    [super dealloc];
}

@end
