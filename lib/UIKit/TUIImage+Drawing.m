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

#import "TUIImage+Drawing.h"
#import "TUICGAdditions.h"
#import "TUIColor.h"

@implementation TUIImage (Drawing)

+ (TUIImage *)imageWithSize:(CGSize)size scale:(CGFloat)scale drawing:(void(^)(CGContextRef))draw
{
    if(size.width < 1 || size.height < 1)
		return nil;
	
	size = CGSizeMake(size.width * scale, size.height * scale);
    
	CGContextRef ctx = TUICreateGraphicsContextWithOptions(size, NO);
    CGContextScaleCTM(ctx, scale, scale);
    
	draw(ctx);
	TUIImage *i = TUIGraphicsContextGetImage(ctx);
        
	CGContextRelease(ctx);
	return i;
}

+ (TUIImage *)imageWithSize:(CGSize)size drawing:(void(^)(CGContextRef))draw
{
	CGFloat scale = [[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)] ? [[NSScreen mainScreen] backingScaleFactor] : 1.0f;
    
    return [self imageWithSize:size scale:scale drawing:draw];
}

- (TUIImage *)scale:(CGSize)size
{
	return [TUIImage imageWithSize:size scale:self.scale drawing:^(CGContextRef ctx) {
		CGRect r;
		r.origin = CGPointZero;
		r.size = size;
		CGContextDrawImage(ctx, r, self.CGImage);
	}];
}

- (TUIImage *)crop:(CGRect)cropRect
{
	if((cropRect.size.width < 1) || (cropRect.size.height < 1))
		return nil;
	
	CGSize s = self.size;
	CGFloat mx = cropRect.origin.x + cropRect.size.width;
	CGFloat my = cropRect.origin.y + cropRect.size.height;
	if((cropRect.origin.x >= 0.0) && (cropRect.origin.y >= 0.0) && (mx <= s.width) && (my <= s.height)) {
		// fast crop
        if (self.scale != 1)
        {
            cropRect.size.width *= self.scale;
            cropRect.size.height *= self.scale;
            cropRect.origin.x *= self.scale;
            cropRect.origin.y *= self.scale;
        }
		CGImageRef cgimage = CGImageCreateWithImageInRect(self.CGImage, cropRect);
		if(!cgimage) {
			NSLog(@"CGImageCreateWithImageInRect failed %@ %@", NSStringFromRect(cropRect), NSStringFromSize(s));
			return nil;
		}
		TUIImage *i = [TUIImage imageWithCGImage:cgimage scale:self.scale];
		CGImageRelease(cgimage);
		return i;
	} else {
		// slow crop - probably doing pad
		return [TUIImage imageWithSize:cropRect.size scale:self.scale drawing:^(CGContextRef ctx) {
			CGRect imageRect;
			imageRect.origin.x = -cropRect.origin.x;
			imageRect.origin.y = -cropRect.origin.y;
			imageRect.size = s;
			CGContextDrawImage(ctx, imageRect, self.CGImage);
		}];
	}
}

- (TUIImage *)upsideDownCrop:(CGRect)cropRect
{
	CGSize s = self.size;
	cropRect.origin.y = s.height - (cropRect.origin.y + cropRect.size.height);
	return [self crop:cropRect];
}

- (TUIImage *)thumbnail:(CGSize)newSize 
{
	CGSize s = self.size;
  float oldProp = s.width / s.height;
  float newProp = newSize.width / newSize.height;  
  CGRect cropRect;
  if (oldProp > newProp) {
    cropRect.size.height = s.height;
    cropRect.size.width = s.height * newProp;
  } else {
    cropRect.size.width = s.width;
    cropRect.size.height = s.width / newProp;
  }
  cropRect.origin = CGPointMake((s.width - cropRect.size.width) / 2.0, (s.height - cropRect.size.height) / 2.0);
  return [[self crop:cropRect] scale:newSize];
}

- (TUIImage *)pad:(CGFloat)padding
{
	CGSize s = self.size;
	return [self crop:CGRectMake(-padding, -padding, s.width + padding*2, s.height + padding*2)];
}

- (TUIImage *)roundImage:(CGFloat)radius
{
	CGRect r;
	r.origin = CGPointZero;
	r.size = self.size;
	return [TUIImage imageWithSize:r.size scale:self.scale drawing:^(CGContextRef ctx) {
		CGContextClipToRoundRect(ctx, r, radius);
		CGContextDrawImage(ctx, r, self.CGImage);
	}];
}

- (TUIImage *)invertedMask
{
	CGSize s = self.size;
	return [TUIImage imageWithSize:s scale:self.scale drawing:^(CGContextRef ctx) {
		CGRect rect = CGRectMake(0, 0, s.width, s.height);
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
		CGContextFillRect(ctx, rect);
		CGContextSaveGState(ctx);
		CGContextClipToMask(ctx, rect, self.CGImage);
		CGContextClearRect(ctx, rect);
		CGContextRestoreGState(ctx);
	}];
}

- (TUIImage *)innerShadowWithOffset:(CGSize)offset radius:(CGFloat)radius color:(TUIColor *)color backgroundColor:(TUIColor *)backgroundColor
{
    CGFloat originalScale = self.scale;
	CGFloat padding = ceil(radius);
	TUIImage *paddedImage = [self pad:padding];
    
    CGFloat scaleMultiplier =  originalScale / paddedImage.scale;
    
	TUIImage *shadowImage = [TUIImage imageWithSize:paddedImage.size scale:paddedImage.scale drawing:^(CGContextRef ctx) {
		CGContextSaveGState(ctx);
		CGRect r = CGRectMake(0, 0, paddedImage.size.width, paddedImage.size.height);
		CGContextClipToMask(ctx, r, paddedImage.CGImage); // clip to image
		CGContextSetShadowWithColor(ctx, offset, radius * scaleMultiplier, color.CGColor);
		CGContextBeginTransparencyLayer(ctx, NULL);
		{
			CGContextClipToMask(ctx, r, [[paddedImage invertedMask] CGImage]); // clip to inverted
			CGContextSetFillColorWithColor(ctx, backgroundColor.CGColor);
			CGContextFillRect(ctx, r); // draw with shadow
		}
		CGContextEndTransparencyLayer(ctx);
		CGContextRestoreGState(ctx);
	}];
	
	return [shadowImage pad:-padding * scaleMultiplier];
}

- (TUIImage *)embossMaskWithOffset:(CGSize)offset
{
	CGFloat padding = MAX(offset.width, offset.height) + 1;
	TUIImage *paddedImage = [self pad:padding];
	CGSize s = paddedImage.size;
	TUIImage *embossedImage = [TUIImage imageWithSize:s scale:self.scale drawing:^(CGContextRef ctx) {
		CGContextSaveGState(ctx);
		CGRect r = CGRectMake(0, 0, s.width, s.height);
		CGContextClipToMask(ctx, r, [paddedImage CGImage]);
		CGContextClipToMask(ctx, CGRectOffset(r, offset.width, offset.height), [[paddedImage invertedMask] CGImage]);
		CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
		CGContextFillRect(ctx, r);
		CGContextRestoreGState(ctx);
	}];
	
	return [embossedImage pad:-padding];
}

- (TUIImage *)horizontalFlip
{
    CGSize s = self.size;
    
    return [TUIImage imageWithSize:s scale:self.scale drawing:^(CGContextRef ctx) {
        CGContextSaveGState(ctx);
        
        CGContextTranslateCTM(ctx, s.width, 0);
        CGContextScaleCTM(ctx, -1.0, 1.0);
        
        CGContextDrawImage(ctx, CGRectMake(0, 0, s.width, s.height), self.CGImage);
        CGContextRestoreGState(ctx);
    }];
}

@end
