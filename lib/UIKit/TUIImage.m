/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIImage.h"
#import "TUICGAdditions.h"
#import "TUIView+Private.h"

static CGImageRef TUICreateImageRefWithData(NSData *data)
{
	if(!data)
		return nil;
    
	CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
	if(!imageSource) {
		return nil;
	}
    
	CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
	if(!image) {
		NSLog(@"could not create image at index 0");
	}
    
	CFRelease(imageSource);
	return image;
}

static CGImageRef TUICreateImageRefForURL(NSURL *url, BOOL shouldCache)
{
	static NSMutableDictionary *cache = nil;
	if(!cache)
		cache = [NSMutableDictionary new];
    
	if(url) {
		CGImageRef image;
        
		// look up in cache
		image = (__bridge CGImageRef)[cache objectForKey:url];
		if(image)
			return CGImageRetain(image);
        
		image = TUICreateImageRefWithData([NSData dataWithContentsOfURL:url]);
		if(image && shouldCache)
			[cache setObject:(__bridge id)image forKey:url];
        
		return image;
	}
	return NULL;
}

static NSURL *TUIURLForNameAndScaleFactor(NSString *name, CGFloat scaleFactor)
{
	// simplest thing that works for now
	// todo - understand the details of what UIKit does, mimic.
    @try {
        NSString *ext = [name pathExtension];
        NSString *baseName = [name stringByDeletingPathExtension];
        if(scaleFactor == 2.0) {
            name = [[baseName stringByAppendingString:@"@2x"] stringByAppendingPathExtension:ext];
        } else {
            name = [baseName stringByAppendingPathExtension:ext];
        }
        return [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:name];
    }
    @catch (NSException *exception) {
        NSLog(@"e:%@",exception);
    }
}

CGImageRef TUICreateImageRefForNameAndScaleFactor(NSString *name, CGFloat scaleFactor, BOOL shouldCache, CGFloat *imageScaleFactor)
{
	if(name) {
		CGImageRef i = NULL;
		if(scaleFactor == 2.0) {
			i = TUICreateImageRefForURL(TUIURLForNameAndScaleFactor(name, scaleFactor), shouldCache);
			if(i) {
				if(imageScaleFactor != NULL) *imageScaleFactor = scaleFactor;
				return i;
			}
		}
		// fallback
		i = TUICreateImageRefForURL(TUIURLForNameAndScaleFactor(name, 1.0), shouldCache);
		if(imageScaleFactor != NULL) *imageScaleFactor = 1.0f;
		return i;
	}
	
	return NULL;
}

@interface TUIStretchableImage : TUIImage
{
	@public
	NSInteger leftCapWidth;
	NSInteger topCapHeight;
    NSInteger rightCapWidth;
    NSInteger bottomCapHeight;
	@private
	__strong TUIImage *slices[9];
	struct {
		unsigned int haveSlices:1;
	} _flags;
}
@end


@implementation TUIImage
{
	CGFloat _lastContextScaleFactor;
	CGFloat _imageScaleFactor;
	NSString * _imageName;
	CGImageRef _imageRef;
	BOOL _shouldCache;
}

- (id)init
{
	if(self = [super init]) {
		_lastContextScaleFactor = 1.0;
		_imageScaleFactor = 1.0f;
	}
	return self;
}

- (id)initWithCGImage:(CGImageRef)imageRef
{
	return [self initWithCGImage:imageRef scale:1];
}
- (id)initWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale
{
    if(self = [self init]) {
		if(imageRef)
        {
			_imageRef = CGImageRetain(imageRef);
            _lastContextScaleFactor = scale;
            _imageScaleFactor = scale;
        }
	}
	return self;
}

- (id)initWithName:(NSString *)name cache:(BOOL)shouldCache
{
	if(self = [self init]) {
		_imageName = name;
		_shouldCache = shouldCache;
	}
	return self;
}

- (id)initWithData:(NSData *)data
{
	CGImageRef i = TUICreateImageRefWithData(data);
	if(i) {
		self = [self initWithCGImage:i];
		CGImageRelease(i);
		return self;
	}
	return nil;
}

+ (TUIImage *)_imageWithABImage:(id)abimage
{
	return [self imageWithCGImage:[abimage CGImage]];
}

+ (TUIImage *)imageNamed:(NSString *)name cache:(BOOL)shouldCache
{
	return [[self alloc] initWithName:name cache:shouldCache];
}

+ (TUIImage *)imageNamed:(NSString *)name
{
	return [self imageNamed:name cache:NO]; // differs from default UIKit, use explicit cache: for caching
}

+ (TUIImage *)imageWithData:(NSData *)data
{
	return [[self alloc] initWithData:data];
}

- (void)dealloc
{
	if(_imageRef)
		CGImageRelease(_imageRef);
}

+ (TUIImage *)imageWithCGImage:(CGImageRef)imageRef
{
	return [[self alloc] initWithCGImage:imageRef];
}
+ (TUIImage *)imageWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale
{
    return [[self alloc] initWithCGImage:imageRef scale:scale];
}

/**
 * @brief Create a new TUIImage from an NSImage
 * 
 * @note Don't use this method in -drawRect: if you use a NSGraphicsContext.  This method may
 * change the current context in order to convert the image and will not restore any previous
 * context.
 *
 * @param image an NSImage
 * @return TUIImage
 */
+ (TUIImage *)imageWithNSImage:(NSImage *)image {
  
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
	return [self imageWithCGImage:[image CGImageForProposedRect:NULL context:NULL hints:nil]];
#elif MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5  // first, attempt to find an NSBitmapImageRep representation, (the easy way)
  for(NSImageRep *rep in [image representations]){
    CGImageRef cgImage;
    if([rep isKindOfClass:[NSBitmapImageRep class]] && (cgImage = [(NSBitmapImageRep *)rep CGImage]) != nil){
      return [[TUIImage alloc] initWithCGImage:cgImage];
    }
  }
#endif
  
  // if that didn't work, we have to render the image to a context and create the CGImage
  // from that (the hard way)
  TUIImage *result = nil;
  
  CGColorSpaceRef colorspace = NULL;
  CGContextRef context = NULL;
  CGBitmapInfo info = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
  
  size_t width  = (size_t)ceil(image.size.width);
  size_t height = (size_t)ceil(image.size.height);
  size_t bytesPerPixel = 4;
  size_t bitsPerComponent = 8;
  
  // create a colorspace for our image
  if((colorspace = CGColorSpaceCreateDeviceRGB()) != NULL){
    // create a context for our image using premultiplied RGBA
    if((context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, width * bytesPerPixel, colorspace, info)) != NULL){
      
      // setup an NSGraphicsContext for our bitmap context and render our NSImage into it
      [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:FALSE]];
      [image drawAtPoint:CGPointMake(0, 0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
      
      // create an image from the context and use that to create our TUIImage
      CGImageRef cgImage;
      if((cgImage = CGBitmapContextCreateImage(context)) != NULL){
        result = [[TUIImage alloc] initWithCGImage:cgImage];
        CFRelease(cgImage);
      }
      
      CFRelease(context);
    }
    CFRelease(colorspace);
  }
  
  // return the (hopefully sucessfully initialized) TUIImage
  return result;
}

- (CGSize)size
{
	CGImageRef cgImage = [self CGImage];
	CGFloat inv = 1.0f / _imageScaleFactor; // must call -CGImage first (will update _lastScaleFactor)
	if(cgImage)
		return CGSizeMake(CGImageGetWidth(cgImage) * inv, CGImageGetHeight(cgImage) * inv);
	return CGSizeZero;
}

- (CGFloat)scale
{
	[self CGImage]; // update _lastScaleFactor if needed
	return _lastContextScaleFactor;
}

- (CGImageRef)CGImage
{
	if(_imageName) { // lazy image
		CGFloat currentScaleFactor = TUICurrentContextScaleFactor();
		if(!_imageRef || (_lastContextScaleFactor != currentScaleFactor)) {
			// if we haven't loaded an image yet, or the scale factor changed, load a new one
			if(_imageRef)
				CGImageRelease(_imageRef);
			_imageRef = CGImageRetain(TUICreateImageRefForNameAndScaleFactor(_imageName, currentScaleFactor, _shouldCache, &_imageScaleFactor));
			_lastContextScaleFactor = currentScaleFactor;
		}
	}
	return _imageRef;
}

- (void)drawAtPoint:(CGPoint)point // mode = kCGBlendModeNormal, alpha = 1.0
{
	[self drawAtPoint:point blendMode:kCGBlendModeNormal alpha:1.0];
}

- (void)drawAtPoint:(CGPoint)point blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGRect rect;
	rect.origin = point;
	rect.size = [self size];
	[self drawInRect:rect blendMode:blendMode alpha:alpha];
}

- (void)drawInRect:(CGRect)rect // mode = kCGBlendModeNormal, alpha = 1.0
{
	[self drawInRect:rect blendMode:kCGBlendModeNormal alpha:1.0];
}

- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGImageRef cgImage = [self CGImage]; // -CGImage will automatically update itself with the correct image
	if(cgImage) {
		CGContextRef ctx = TUIGraphicsGetCurrentContext();
		CGContextSaveGState(ctx);
		CGContextSetAlpha(ctx, alpha);
		CGContextSetBlendMode(ctx, blendMode);
		CGContextDrawImage(ctx, rect, cgImage);
		CGContextRestoreGState(ctx);
	}
}

- (NSInteger)leftCapWidth
{
	return 0;
}

- (NSInteger)topCapHeight
{
	return 0;
}

- (TUIEdgeInsets)capEdgeInsets
{
    return TUIEdgeInsetsZero;
}

- (TUIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight
{
	return [self stretchableImageWithEdgeInsets:TUIEdgeInsetsMake(topCapHeight, leftCapWidth, -1, -1)];
}
- (TUIImage *)stretchableImageWithEdgeInsets:(TUIEdgeInsets)insets
{
    TUIStretchableImage *i = (TUIStretchableImage *)[TUIStretchableImage imageWithCGImage:[self CGImage] scale:self.scale];
    
	i->leftCapWidth = insets.left;
	i->topCapHeight = insets.top;
    i->rightCapWidth = insets.right;
    i->bottomCapHeight = insets.bottom;
	return i;
}

- (NSData *)dataRepresentationForType:(NSString *)type compression:(CGFloat)compressionQuality
{
	CGImageRef cgImage = [self CGImage];
	if(cgImage) {
		NSMutableData *mutableData = [NSMutableData data];
		CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)mutableData, (__bridge CFStringRef)type, 1, NULL);
		
		NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:compressionQuality], kCGImageDestinationLossyCompressionQuality, nil];
		CGImageDestinationAddImage(destination, cgImage, (__bridge CFDictionaryRef)properties);
		
		CGImageDestinationFinalize(destination);
		CFRelease(destination);
		return mutableData;
	}
	return nil;
}

- (id)debugQuickLookObject
{
    return (id)self.CGImage;
}

@end




@implementation TUIStretchableImage

- (NSInteger)leftCapWidth
{
	return leftCapWidth;
}

- (NSInteger)topCapHeight
{
	return topCapHeight;
}

- (TUIEdgeInsets)capEdgeInsets
{
    return TUIEdgeInsetsMake(topCapHeight, leftCapWidth, bottomCapHeight, rightCapWidth);
}

/*
 
 x0     x1      x2      x3
 +-------+-------+-------+ y3
 |       |       |       |
 |   6   |   7   |   8   |
 |       |       |       |
 +-------+-------+-------+ y2
 |       |       |       |
 |   3   |   4   |   5   |
 |       |       |       |
 +-------+-------+-------+ y1
 |       |       |       |
 |   0   |   1   |   2   |
 |       |       |       |
 +-------+-------+-------+ y0
 
 */

#define STRETCH_COORDS(X0, Y0, W, H, TOP, LEFT, BOTTOM, RIGHT) \
	CGFloat x0 = X0; \
	CGFloat x1 = X0 + LEFT; \
	CGFloat x2 = X0 + W - RIGHT; \
	CGFloat x3 = X0 + W; \
	CGFloat y0 = Y0; \
	CGFloat y1 = Y0 + BOTTOM; \
	CGFloat y2 = Y0 + H - TOP; \
	CGFloat y3 = Y0 + H; \
	CGRect r[9]; \
	r[0] = CGRectMake(x0, y0, x1-x0, y1-y0); \
	r[1] = CGRectMake(x1, y0, x2-x1, y1-y0); \
	r[2] = CGRectMake(x2, y0, x3-x2, y1-y0); \
	r[3] = CGRectMake(x0, y1, x1-x0, y2-y1); \
	r[4] = CGRectMake(x1, y1, x2-x1, y2-y1); \
	r[5] = CGRectMake(x2, y1, x3-x2, y2-y1); \
	r[6] = CGRectMake(x0, y2, x1-x0, y3-y2); \
	r[7] = CGRectMake(x1, y2, x2-x1, y3-y2); \
	r[8] = CGRectMake(x2, y2, x3-x2, y3-y2);

- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
	CGSize s = self.size;
	CGFloat t = topCapHeight;
	CGFloat l = leftCapWidth;
    CGFloat r = rightCapWidth;
    CGFloat b = bottomCapHeight;
    
    if (r < 0) r = l;
    if (b < 0) b = t;
	
	if(t*2 > s.height-1) t -= 1;
	if(l*2 > s.width-1) l -= 1;
	
	CGImageRef cgImage = [self CGImage];
	if(cgImage) {
		if(!_flags.haveSlices) {
			STRETCH_COORDS(0.0, 0.0, s.width, s.height, t, l, b, r)
			#define X(I) slices[I] = [self upsideDownCrop:r[I]];
			X(0) X(1) X(2)
			X(3) X(4) X(5)
			X(6) X(7) X(8)
			#undef X
			_flags.haveSlices = 1;
		}
		
		CGContextRef ctx = TUIGraphicsGetCurrentContext();
		CGContextSaveGState(ctx);
		CGContextSetAlpha(ctx, alpha);
		CGContextSetBlendMode(ctx, blendMode);

		STRETCH_COORDS(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, t, l, b, r)
		#define X(I) CGContextDrawImage(ctx, r[I], slices[I].CGImage);
		X(0) X(1) X(2)
		X(3) X(4) X(5)
		X(6) X(7) X(8)
		#undef X
		CGContextRestoreGState(ctx);
	}
}

#undef STRETCH_COORDS

@end

NSData *TUIImagePNGRepresentation(TUIImage *image)
{
	return [image dataRepresentationForType:(NSString *)kUTTypePNG compression:1.0];
}

NSData *TUIImageJPEGRepresentation(TUIImage *image, CGFloat compressionQuality)
{
	return [image dataRepresentationForType:(NSString *)kUTTypeJPEG compression:compressionQuality];
}

#import <Cocoa/Cocoa.h>

@implementation TUIImage (AppKit)

- (id)nsImage
{
	return [[NSImage alloc] initWithCGImage:self.CGImage size:self.size];
}

@end

