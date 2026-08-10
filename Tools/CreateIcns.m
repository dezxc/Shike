#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static const CGFloat SKIconArtworkScale = 0.92;

static CGImageRef SKCreateOpticallyInsetImage(CGImageRef source) {
    size_t width = CGImageGetWidth(source);
    size_t height = CGImageGetHeight(source);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast |
                                                 kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) return NULL;
    CGContextClearRect(context, CGRectMake(0, 0, width, height));
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGFloat insetWidth = width * SKIconArtworkScale;
    CGFloat insetHeight = height * SKIconArtworkScale;
    CGRect destination = CGRectMake((width - insetWidth) / 2.0,
                                    (height - insetHeight) / 2.0,
                                    insetWidth, insetHeight);
    CGContextDrawImage(context, destination, source);
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "usage: CreateIcns input.iconset output.icns\n");
            return 2;
        }
        NSString *sourceDirectory = [NSString stringWithUTF8String:argv[1]];
        NSURL *outputURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
        NSArray<NSString *> *filenames = @[
            @"icon_16x16.png", @"icon_16x16@2x.png",
            @"icon_32x32.png", @"icon_32x32@2x.png",
            @"icon_128x128.png", @"icon_128x128@2x.png",
            @"icon_256x256.png", @"icon_256x256@2x.png",
            @"icon_512x512.png", @"icon_512x512@2x.png"
        ];
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)outputURL,
            (__bridge CFStringRef)UTTypeICNS.identifier,
            filenames.count,
            NULL);
        if (!destination) return 5;
        for (NSString *filename in filenames) {
            NSURL *sourceURL = [NSURL fileURLWithPath:[sourceDirectory stringByAppendingPathComponent:filename]];
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)sourceURL, NULL);
            if (!source) {
                CFRelease(destination);
                return 3;
            }
            CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
            CFRelease(source);
            if (!image) {
                CFRelease(destination);
                return 4;
            }
            CGImageRef insetImage = SKCreateOpticallyInsetImage(image);
            CGImageRelease(image);
            if (!insetImage) {
                CFRelease(destination);
                return 7;
            }
            CGImageDestinationAddImage(destination, insetImage, NULL);
            CGImageRelease(insetImage);
        }
        BOOL success = CGImageDestinationFinalize(destination);
        CFRelease(destination);
        return success ? 0 : 6;
    }
}
